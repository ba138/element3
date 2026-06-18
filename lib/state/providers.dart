import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../models/battery_status.dart';

/// Singleton BLE service for the app.
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(service.dispose);
  return service;
});

/// Live connection state.
final connectionStateProvider = StreamProvider<BleConnectionState>((ref) {
  return ref.watch(bleServiceProvider).connectionStream;
});

/// Live battery telemetry.
final batteryStatusProvider = StreamProvider<BatteryStatus>((ref) {
  return ref.watch(bleServiceProvider).statusStream;
});
