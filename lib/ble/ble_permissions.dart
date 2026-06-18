import 'package:permission_handler/permission_handler.dart';

/// Requests the platform Bluetooth permissions needed to scan and connect.
///
/// - Android 12+ requires `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` at runtime.
/// - Older Android requires location for BLE scanning.
/// - iOS surfaces the system prompt automatically once the central is used; the
///   usage strings in Info.plist drive that dialog.
class BlePermissions {
  static Future<bool> ensureGranted() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    // bluetoothScan/Connect are the modern Android perms; on platforms where
    // they aren't applicable they resolve as granted.
    final scan = statuses[Permission.bluetoothScan];
    final connect = statuses[Permission.bluetoothConnect];
    return (scan == null || scan.isGranted || scan.isLimited) &&
        (connect == null || connect.isGranted || connect.isLimited);
  }
}
