import 'dart:typed_data';

import '../models/battery_status.dart';

/// Parser for the JK BMS (model JK-B2A8S30P) BLE protocol.
///
/// The BMS exposes a Nordic UART-style service: the app subscribes to the
/// notify characteristic and the BMS streams binary frames. To request a fresh
/// data dump the app writes a small command frame to the write characteristic.
///
/// IMPORTANT: the exact byte offsets below are placeholders. They MUST be
/// reconciled against Element 3's working Python proof-of-concept before
/// shipping — that document is the source of truth for the wire format. The
/// structure here mirrors the well-documented JK BMS frame so wiring it up is a
/// matter of confirming offsets, not rewriting the layer.
class JkBmsProtocol {
  // Nordic UART Service (NUS) UUIDs used by JK BMS modules.
  static const String serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
  static const String notifyCharacteristicUuid =
      '0000ffe1-0000-1000-8000-00805f9b34fb';
  static const String writeCharacteristicUuid =
      '0000ffe1-0000-1000-8000-00805f9b34fb';

  /// Frames begin with this 2-byte start sequence.
  static const List<int> frameHeader = [0x55, 0xAA];

  /// Command that asks the BMS to reply with a full cell-info frame.
  ///
  /// Replace with the exact bytes from the Python PoC.
  static Uint8List readAllCommand() {
    // Placeholder request frame: header + read-all opcode + checksum.
    return Uint8List.fromList([0xAA, 0x55, 0x90, 0xEB, 0x96, 0x00]);
  }

  /// Returns true if [data] starts a new BMS frame.
  bool isFrameStart(List<int> data) =>
      data.length >= 2 && data[0] == frameHeader[0] && data[1] == frameHeader[1];

  /// Parses a complete reassembled frame into a [BatteryStatus].
  ///
  /// Throws [FormatException] if the frame is malformed. Returns null if the
  /// frame is a type we don't care about (e.g. a settings frame).
  BatteryStatus? parseFrame(Uint8List frame) {
    if (frame.length < 4) {
      throw const FormatException('Frame too short');
    }
    final data = ByteData.sublistView(frame);

    // --- Placeholder offsets: confirm against the PoC ---------------------
    // Big-endian 16/32-bit reads are typical for JK BMS frames.
    double readU16(int offset, {double scale = 1.0}) =>
        offset + 2 <= frame.length ? data.getUint16(offset) * scale : 0.0;
    double readS16(int offset, {double scale = 1.0}) =>
        offset + 2 <= frame.length ? data.getInt16(offset) * scale : 0.0;
    double readU32(int offset, {double scale = 1.0}) =>
        offset + 4 <= frame.length ? data.getUint32(offset) * scale : 0.0;

    // Cell voltages: the JK frame carries a block of per-cell millivolts.
    // The PoC defines how many cells are present (4 or 8); we infer from the
    // declared count byte and clamp to the supported range.
    final declaredCells = frame.length > 1 ? frame[1].clamp(0, 8) : 0;
    final cellVoltages = <double>[];
    for (var i = 0; i < declaredCells; i++) {
      cellVoltages.add(readU16(6 + i * 2, scale: 0.001));
    }

    return BatteryStatus(
      packVoltage: readU16(118, scale: 0.001),
      current: readS16(126, scale: 0.001),
      stateOfCharge: frame.length > 141 ? frame[141] : 0,
      remainingCapacityAh: readU32(142, scale: 0.001),
      cycleCount: readU32(150).round(),
      cycleCapacityAh: readU32(154, scale: 0.001),
      mosfetTemperature: readS16(112, scale: 0.1),
      cellTemperatures: [
        readS16(130, scale: 0.1),
        readS16(132, scale: 0.1),
      ],
      balancingCurrent: readS16(138, scale: 0.001),
      cellVoltages: cellVoltages,
      timestamp: DateTime.now(),
    );
  }

  /// Produces a deterministic fake status for UI development without hardware.
  static BatteryStatus demoStatus({int cellCount = 8, double t = 0}) {
    final cells = List<double>.generate(
      cellCount,
      (i) => 3.30 + 0.01 * i + 0.005 * (t.remainder(2)),
    );
    final voltage = cells.fold<double>(0, (a, b) => a + b);
    final current = 12.5 * (t.remainder(10) < 5 ? 1 : -1).toDouble();
    return BatteryStatus(
      packVoltage: voltage,
      current: current,
      stateOfCharge: 76,
      remainingCapacityAh: 152.4,
      cycleCount: 87,
      cycleCapacityAh: 13280.5,
      mosfetTemperature: 28.4,
      cellTemperatures: const [24.1, 24.6],
      balancingCurrent: 0.18,
      cellVoltages: cells,
      timestamp: DateTime.now(),
    );
  }
}
