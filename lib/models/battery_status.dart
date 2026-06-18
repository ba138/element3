import 'package:flutter/foundation.dart';

/// Immutable snapshot of every value the Element 3 app displays.
///
/// Populated from a JK-B2A8S30P BLE notification frame by
/// [Jk Bms Protocol] (see `lib/ble/jk_bms_protocol.dart`).
@immutable
class BatteryStatus {
  const BatteryStatus({
    required this.packVoltage,
    required this.current,
    required this.stateOfCharge,
    required this.remainingCapacityAh,
    required this.cycleCount,
    required this.cycleCapacityAh,
    required this.mosfetTemperature,
    required this.cellTemperatures,
    required this.balancingCurrent,
    required this.cellVoltages,
    required this.timestamp,
  });

  /// Pack voltage in volts.
  final double packVoltage;

  /// Pack current in amps. Positive = charging, negative = discharging.
  final double current;

  /// State of charge as a percentage (0-100).
  final int stateOfCharge;

  /// Remaining capacity in amp-hours.
  final double remainingCapacityAh;

  /// Total charge/discharge cycle count.
  final int cycleCount;

  /// Accumulated amp-hours over the battery's life.
  final double cycleCapacityAh;

  /// MOSFET temperature in degrees Celsius.
  final double mosfetTemperature;

  /// Cell/probe temperatures in degrees Celsius.
  final List<double> cellTemperatures;

  /// Active balancing current in amps.
  final double balancingCurrent;

  /// Individual cell voltages in volts (4 or 8 entries).
  final List<double> cellVoltages;

  /// When this snapshot was produced.
  final DateTime timestamp;

  /// Power in watts (derived: voltage * current). Positive = charging.
  double get power => packVoltage * current;

  bool get isCharging => current > 0.05;
  bool get isDischarging => current < -0.05;

  int get cellCount => cellVoltages.length;

  double get minCellVoltage =>
      cellVoltages.isEmpty ? 0 : cellVoltages.reduce((a, b) => a < b ? a : b);

  double get maxCellVoltage =>
      cellVoltages.isEmpty ? 0 : cellVoltages.reduce((a, b) => a > b ? a : b);

  /// Spread between the highest and lowest cell in millivolts — a key
  /// indicator of pack balance/health.
  double get cellDeltaMillivolts =>
      (maxCellVoltage - minCellVoltage) * 1000.0;
}
