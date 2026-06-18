import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/battery_status.dart';
import 'jk_bms_protocol.dart';

enum BleConnectionState {
  idle,
  scanning,
  connecting,
  connected,
  reconnecting,
  disconnected,
  bluetoothOff,
  unauthorized,
}

/// Owns the BLE lifecycle for a single Element 3 battery: scanning,
/// connecting, subscribing to the BMS notify characteristic, parsing frames,
/// and automatically reconnecting when the link drops.
class BleService {
  BleService({JkBmsProtocol? protocol})
      : _protocol = protocol ?? JkBmsProtocol();

  final JkBmsProtocol _protocol;

  final _statusController = StreamController<BatteryStatus>.broadcast();
  final _connectionController =
      StreamController<BleConnectionState>.broadcast();

  /// Live battery telemetry parsed from BMS frames.
  Stream<BatteryStatus> get statusStream => _statusController.stream;

  /// High-level connection state for the UI.
  Stream<BleConnectionState> get connectionStream =>
      _connectionController.stream;

  BluetoothDevice? _device;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  Timer? _reconnectTimer;

  final List<int> _frameBuffer = [];
  bool _intentionalDisconnect = false;
  int _reconnectAttempt = 0;
  static const _maxBackoff = Duration(seconds: 30);

  void _emit(BleConnectionState state) {
    if (!_connectionController.isClosed) _connectionController.add(state);
  }

  /// Live Bluetooth adapter state (on/off/unauthorized/...).
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  /// Ensures the Bluetooth adapter is powered on before any scan/connect.
  ///
  /// On Android we can ask the OS to turn it on; on iOS that's not permitted,
  /// so we wait briefly for the user to enable it. Returns true once the
  /// adapter reports [BluetoothAdapterState.on].
  Future<bool> ensureBluetoothOn({
    Duration wait = const Duration(seconds: 10),
  }) async {
    if (!await FlutterBluePlus.isSupported) return false;

    if (FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on) {
      return true;
    }

    _emit(BleConnectionState.bluetoothOff);

    // Android: prompt the system "turn on Bluetooth" dialog. No-op on iOS.
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      // turnOn isn't available/allowed (e.g. iOS) — fall through and wait.
    }

    try {
      await FlutterBluePlus.adapterState
          .firstWhere((s) => s == BluetoothAdapterState.on)
          .timeout(wait);
      return true;
    } catch (_) {
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    }
  }

  /// Scans for nearby JK BMS devices advertising the NUS service.
  ///
  /// Guards on the adapter being on first so we never throw
  /// `Bluetooth must be turned on`.
  Stream<List<ScanResult>> scanForBatteries({
    Duration timeout = const Duration(seconds: 15),
  }) async* {
    if (!await ensureBluetoothOn()) {
      _emit(BleConnectionState.bluetoothOff);
      return;
    }
    _emit(BleConnectionState.scanning);
    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [Guid(JkBmsProtocol.serviceUuid)],
    );
    yield* FlutterBluePlus.scanResults;
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Connects to [device] and begins streaming telemetry. Sets up automatic
  /// reconnection on unexpected disconnects.
  Future<void> connect(BluetoothDevice device) async {
    _intentionalDisconnect = false;
    _device = device;
    _reconnectAttempt = 0;
    await _connectInternal();
  }

  Future<void> _connectInternal() async {
    final device = _device;
    if (device == null) return;
    _emit(_reconnectAttempt == 0
        ? BleConnectionState.connecting
        : BleConnectionState.reconnecting);

    await _deviceStateSub?.cancel();
    _deviceStateSub = device.connectionState.listen(_onDeviceStateChanged);

    try {
      await FlutterBluePlus.stopScan();
      // NOTE: flutter_blue_plus requires a License. Element 3 is a commercial
      // product, so License.commercial is required (a paid license — see the
      // flutter_blue_plus LICENSE). Swap to License.nonprofit only if eligible.
      await device.connect(
        license: License.commercial,
        timeout: const Duration(seconds: 20),
      );
      await _discoverAndSubscribe(device);
      _reconnectAttempt = 0;
      _emit(BleConnectionState.connected);
    } catch (_) {
      _scheduleReconnect();
    }
  }

  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid == Guid(JkBmsProtocol.serviceUuid),
      orElse: () => throw StateError('JK BMS service not found'),
    );
    final notifyChar = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(JkBmsProtocol.notifyCharacteristicUuid),
      orElse: () => throw StateError('Notify characteristic not found'),
    );

    await notifyChar.setNotifyValue(true);
    await _notifySub?.cancel();
    _notifySub = notifyChar.lastValueStream.listen(_onData);

    // Kick the BMS to start streaming.
    final writeChar = service.characteristics.firstWhere(
      (c) => c.uuid == Guid(JkBmsProtocol.writeCharacteristicUuid),
      orElse: () => notifyChar,
    );
    await writeChar.write(JkBmsProtocol.readAllCommand(), withoutResponse: true);
  }

  void _onData(List<int> chunk) {
    if (chunk.isEmpty) return;
    if (_protocol.isFrameStart(chunk)) {
      _flushBuffer();
      _frameBuffer
        ..clear()
        ..addAll(chunk);
    } else {
      _frameBuffer.addAll(chunk);
    }
    _flushBuffer();
  }

  void _flushBuffer() {
    if (_frameBuffer.isEmpty) return;
    try {
      final status =
          _protocol.parseFrame(Uint8List.fromList(_frameBuffer));
      if (status != null && !_statusController.isClosed) {
        _statusController.add(status);
      }
    } on FormatException {
      // Partial frame — keep buffering until the next chunk arrives.
    }
  }

  void _onDeviceStateChanged(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected) {
      if (_intentionalDisconnect) {
        _emit(BleConnectionState.disconnected);
      } else {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    _emit(BleConnectionState.reconnecting);
    _reconnectTimer?.cancel();
    final backoff = Duration(
      seconds: (1 << _reconnectAttempt).clamp(1, _maxBackoff.inSeconds),
    );
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(0, 5);
    _reconnectTimer = Timer(backoff, _connectInternal);
  }

  /// Cleanly disconnects and stops auto-reconnection.
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    await _notifySub?.cancel();
    await _device?.disconnect();
    _emit(BleConnectionState.disconnected);
  }

  Future<void> dispose() async {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    await _scanSub?.cancel();
    await _notifySub?.cancel();
    await _deviceStateSub?.cancel();
    await _statusController.close();
    await _connectionController.close();
  }
}
