import 'package:flutter/material.dart';

import '../models/battery_status.dart';
import '../theme/element3_theme.dart';

/// Grid of per-cell voltages, highlighting the highest and lowest cells.
class CellVoltageGrid extends StatelessWidget {
  const CellVoltageGrid({super.key, required this.status});

  final BatteryStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final min = status.minCellVoltage;
    final max = status.maxCellVoltage;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cell Voltages',
                    style: theme.textTheme.titleMedium),
                Text(
                  'Δ ${status.cellDeltaMillivolts.toStringAsFixed(0)} mV',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: status.cellDeltaMillivolts > 50
                        ? Element3Theme.warning
                        : Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: status.cellVoltages.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.6,
              ),
              itemBuilder: (context, i) {
                final v = status.cellVoltages[i];
                Color border = Colors.white12;
                if (v == max) border = Element3Theme.brandAccent;
                if (v == min) border = Element3Theme.warning;
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                    color: Colors.black26,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('C${i + 1}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: Colors.white54)),
                      Text(
                        v.toStringAsFixed(3),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text('V',
                          style: TextStyle(
                              fontSize: 10, color: Colors.white54)),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
