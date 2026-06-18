import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_service.dart';
import '../models/battery_status.dart';
import '../state/providers.dart';
import '../theme/element3_theme.dart';
import '../widgets/cell_voltage_grid.dart';
import '../widgets/metric_card.dart';

/// Live battery dashboard.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(batteryStatusProvider);
    final connectionAsync = ref.watch(connectionStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Battery Status'),
        actions: [
          IconButton(
            tooltip: 'Disconnect',
            icon: const Icon(Icons.bluetooth_disabled),
            onPressed: () async {
              await ref.read(bleServiceProvider).disconnect();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _ConnectionBanner(
            state: connectionAsync.value ?? BleConnectionState.idle,
          ),
          Expanded(
            child: statusAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (status) => _DashboardBody(status: status),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.state});

  final BleConnectionState state;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    switch (state) {
      case BleConnectionState.connected:
        label = 'Connected';
        color = Element3Theme.brandGreen;
      case BleConnectionState.reconnecting:
        label = 'Reconnecting…';
        color = Element3Theme.warning;
      case BleConnectionState.connecting:
        label = 'Connecting…';
        color = Element3Theme.warning;
      case BleConnectionState.disconnected:
        label = 'Disconnected';
        color = Element3Theme.danger;
      default:
        label = 'Idle';
        color = Colors.grey;
    }
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.status});

  final BatteryStatus status;

  @override
  Widget build(BuildContext context) {
    final powerColor = status.isCharging
        ? Element3Theme.brandAccent
        : status.isDischarging
            ? Element3Theme.warning
            : Colors.white;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SocHeader(status: status),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            MetricCard(
              label: 'Voltage',
              value: status.packVoltage.toStringAsFixed(2),
              unit: 'V',
              icon: Icons.bolt,
            ),
            MetricCard(
              label: 'Current',
              value: status.current.toStringAsFixed(2),
              unit: 'A',
              icon: Icons.swap_vert,
              valueColor: powerColor,
            ),
            MetricCard(
              label: 'Power',
              value: status.power.toStringAsFixed(0),
              unit: 'W',
              icon: Icons.flash_on,
              valueColor: powerColor,
            ),
            MetricCard(
              label: 'Balancing',
              value: status.balancingCurrent.toStringAsFixed(3),
              unit: 'A',
              icon: Icons.balance,
            ),
            MetricCard(
              label: 'Remaining',
              value: status.remainingCapacityAh.toStringAsFixed(1),
              unit: 'Ah',
              icon: Icons.battery_5_bar,
            ),
            MetricCard(
              label: 'Cycles',
              value: '${status.cycleCount}',
              unit: '',
              icon: Icons.loop,
            ),
            MetricCard(
              label: 'Accumulated',
              value: status.cycleCapacityAh.toStringAsFixed(0),
              unit: 'Ah',
              icon: Icons.history,
            ),
            MetricCard(
              label: 'MOSFET Temp',
              value: status.mosfetTemperature.toStringAsFixed(1),
              unit: '°C',
              icon: Icons.thermostat,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TemperatureRow(temps: status.cellTemperatures),
        const SizedBox(height: 12),
        CellVoltageGrid(status: status),
      ],
    );
  }
}

class _SocHeader extends StatelessWidget {
  const _SocHeader({required this.status});

  final BatteryStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: status.stateOfCharge / 100,
                    strokeWidth: 7,
                    backgroundColor: Colors.white12,
                    color: theme.colorScheme.primary,
                  ),
                  Text('${status.stateOfCharge}%',
                      style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('State of Charge',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    status.isCharging
                        ? 'Charging'
                        : status.isDischarging
                            ? 'Discharging'
                            : 'Idle',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemperatureRow extends StatelessWidget {
  const _TemperatureRow({required this.temps});

  final List<double> temps;

  @override
  Widget build(BuildContext context) {
    if (temps.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (var i = 0; i < temps.length; i++) ...[
          Expanded(
            child: MetricCard(
              label: 'Cell Temp ${i + 1}',
              value: temps[i].toStringAsFixed(1),
              unit: '°C',
              icon: Icons.device_thermostat,
            ),
          ),
          if (i != temps.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}
