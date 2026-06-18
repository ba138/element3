# Element 3 — Battery Monitor

A clean, branded Flutter app that connects to an Element 3 LiFePO₄ battery over
Bluetooth Low Energy (BLE) and displays its live status. The battery uses a
**JK BMS (JK-B2A8S30P)** that broadcasts data over BLE.

All data stays on the device — no accounts, no cloud, no server.

> **Status: v1 scaffold.** Architecture, UI, BLE lifecycle, permissions, and
> auto-reconnection are implemented. The exact BMS frame byte-offsets in
> `lib/ble/jk_bms_protocol.dart` are placeholders and must be reconciled with
> Element 3's working Python proof-of-concept before shipping (see below).

## Features (v1 scope)

- Scan/connect screen to find and connect to a battery.
- Live dashboard:
  - Pack voltage, current (charge/discharge), power (W)
  - State of charge (%), remaining & accumulated amp-hours, cycle count
  - MOSFET temperature, cell temperatures, balancing current
  - Individual cell voltages (4 or 8 cells) with min/max + delta highlight
- Robust BLE: connection-state banner, automatic reconnection with exponential
  backoff, runtime permission handling.

## Project structure

```
lib/
  main.dart                     App entry, theme, ProviderScope
  theme/element3_theme.dart     Brand colours/theme (replace with brand guide)
  models/battery_status.dart    Immutable telemetry snapshot
  ble/
    jk_bms_protocol.dart        JK BMS frame parser (offsets = PoC TODO)
    ble_service.dart            Scan/connect/subscribe/reconnect lifecycle
    ble_permissions.dart        Runtime permission requests
  state/providers.dart          Riverpod providers (service + streams)
  screens/
    scan_screen.dart            Find & connect
    dashboard_screen.dart       Live status
  widgets/
    metric_card.dart
    cell_voltage_grid.dart
```

## Getting started

```bash
flutter pub get
flutter run
```

Requires a recent Flutter (3.44+) and, for iOS, current Xcode/iOS SDK to meet
App Store requirements.

## Wiring up the real BMS protocol

`lib/ble/jk_bms_protocol.dart` is the single place that maps raw BLE bytes to a
`BatteryStatus`. To finish v1:

1. Open Element 3's Python proof-of-concept.
2. Confirm the **service / notify / write UUIDs** at the top of the file.
3. Confirm the **read-all command frame** (`readAllCommand`).
4. Confirm the **byte offsets and scale factors** in `parseFrame` against the
   PoC's struct/unpack layout.

Until then, `JkBmsProtocol.demoStatus()` provides realistic fake data for UI
development without hardware.

## Platform notes

- **iOS**: `Info.plist` declares `NSBluetoothAlwaysUsageDescription` and the
  `bluetooth-central` background mode.
- **Android**: `BLUETOOTH_SCAN` (neverForLocation) + `BLUETOOTH_CONNECT` for
  API 31+, legacy Bluetooth/location perms for API ≤30.
- **Licensing**: `flutter_blue_plus` requires a license. This app passes
  `License.commercial` (a paid license) since Element 3 is a commercial product.

## Branding

Drop the Element 3 logo into `assets/branding/` and replace the placeholder
palette in `lib/theme/element3_theme.dart` with the brand guideline values.
