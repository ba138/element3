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

## How it works

### High-level flow

```
┌──────────────┐   scan/connect    ┌──────────────┐   BLE notify     ┌──────────┐
│  ScanScreen  │ ────────────────▶ │  BleService  │ ◀─────────────── │  JK BMS  │
└──────────────┘                   └──────┬───────┘   (raw frames)    └──────────┘
       │ tap device                       │ parse
       ▼                                  ▼
┌──────────────┐   watch streams   ┌──────────────────┐
│DashboardScreen│ ◀──────────────── │ JkBmsProtocol    │
└──────────────┘   (Riverpod)      │ → BatteryStatus  │
                                   └──────────────────┘
```

1. **Permissions & adapter check.** On launch `ScanScreen` requests the platform
   Bluetooth permissions (`BlePermissions`) and calls
   `BleService.ensureBluetoothOn()`, which waits for / prompts to enable the
   adapter so we never call `startScan` while Bluetooth is off.
2. **Scan.** `BleService.scanForBatteries()` starts a filtered scan for the JK
   BMS Nordic-UART service UUID and streams `ScanResult`s to the list.
3. **Connect & subscribe.** Tapping a device calls `BleService.connect()`, which
   connects, discovers services, enables notifications on the BMS notify
   characteristic, and writes the "read-all" command to start the data stream.
4. **Parse.** Incoming BLE chunks are reassembled into frames and decoded by
   `JkBmsProtocol.parseFrame()` into an immutable `BatteryStatus`.
5. **Display.** `BatteryStatus` snapshots flow through Riverpod
   (`batteryStatusProvider`) to `DashboardScreen`, which renders the metrics live.

### State management

[Riverpod](https://riverpod.dev) wires everything together (`lib/state/providers.dart`):

| Provider | Type | Purpose |
| --- | --- | --- |
| `bleServiceProvider` | `Provider<BleService>` | Single BLE service instance (disposed with the app) |
| `connectionStateProvider` | `StreamProvider<BleConnectionState>` | Drives the connection banner |
| `batteryStatusProvider` | `StreamProvider<BatteryStatus>` | Drives the live dashboard |

The UI is fully reactive: widgets `watch` these providers and rebuild whenever a
new frame arrives or the connection state changes.

### Connection reliability

`BleService` is built around the failure modes that matter for BLE:

- **Adapter off:** `ensureBluetoothOn()` gates every scan/connect; on Android it
  requests the system enable-Bluetooth dialog, on iOS it waits for the user.
- **Permissions:** runtime requests for Android 12+ `BLUETOOTH_SCAN`/`CONNECT`
  (and legacy location/Bluetooth for older Android); iOS uses the Info.plist
  usage strings.
- **Dropouts & auto-reconnect:** a `connectionState` listener detects unexpected
  disconnects and schedules reconnection with **exponential backoff** (capped at
  30s). Calling `disconnect()` marks the disconnect intentional so it does *not*
  auto-reconnect.
- **Backgrounding (iOS):** the `bluetooth-central` background mode keeps the link
  alive when the app is backgrounded.

### Data model

`BatteryStatus` (`lib/models/battery_status.dart`) is an immutable snapshot of one
frame. It stores the raw values (voltage, current, SoC, capacities, temperatures,
balancing current, per-cell voltages) and derives convenience values such as
`power` (V×A), `isCharging`/`isDischarging`, and `cellDeltaMillivolts` (pack
balance indicator).

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
