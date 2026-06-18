import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ble/ble_permissions.dart';
import '../state/providers.dart';
import 'dashboard_screen.dart';

/// Scan/connect screen: finds nearby Element 3 batteries and connects.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  bool _scanning = false;
  List<ScanResult> _results = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  Future<void> _startScan() async {
    final ok = await BlePermissions.ensureGranted();
    if (!ok) {
      _showSnack('Bluetooth permission is required to find your battery.');
      return;
    }
    final service = ref.read(bleServiceProvider);
    if (!await service.ensureBluetoothOn()) {
      _showSnack('Please turn on Bluetooth to find your battery.');
      return;
    }
    setState(() {
      _scanning = true;
      _results = const [];
    });
    service.scanForBatteries().listen((results) {
      if (mounted) setState(() => _results = results);
    });
    FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) setState(() => _scanning = scanning);
    });
  }

  Future<void> _connect(ScanResult r) async {
    final service = ref.read(bleServiceProvider);
    await service.stopScan();
    await service.connect(r.device);
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Element 3')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.battery_charging_full,
                    size: 56, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text('Find your battery',
                    style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Make sure your battery is powered on and within range.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
          if (_scanning) const LinearProgressIndicator(),
          Expanded(
            child: _results.isEmpty
                ? Center(
                    child: Text(
                      _scanning ? 'Scanning…' : 'No batteries found.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white60),
                    ),
                  )
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final r = _results[i];
                      final name = r.device.platformName.isNotEmpty
                          ? r.device.platformName
                          : r.advertisementData.advName.isNotEmpty
                              ? r.advertisementData.advName
                              : 'Unknown device';
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(name),
                        subtitle: Text(r.device.remoteId.str),
                        trailing: Text('${r.rssi} dBm'),
                        onTap: () => _connect(r),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _scanning ? null : _startScan,
        icon: const Icon(Icons.refresh),
        label: const Text('Rescan'),
      ),
    );
  }
}
