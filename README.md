<h1 style="text-align: center;">UniFi Protect Dart Client</h1>
<p style="text-align: center;">
    <a href="https://github.com/jt274/unifi_protect/actions">
        <img src="https://github.com/jt274/unifi_protect/actions/workflows/ci.yml/badge.svg?branch=main" alt="Build Status" />
    </a>
    <a href='https://coveralls.io/github/jt274/unifi_protect?branch=main'>
        <img src='https://coveralls.io/repos/github/jt274/unifi_protect/badge.svg?branch=main' alt='Coverage Status' />
    </a>
    <a href="https://www.paypal.com/ncp/payment/HFAXZ7CTFQC6L">
        <img src="https://img.shields.io/badge/Donate-PayPal-00457C?logo=paypal" alt="Donate" />
    </a>
</p>

A comprehensive, pure Dart client for the official Ubiquiti **UniFi Protect Integration API (v1)** (`developer.ui.com/protect`).

Supports cameras, smart floodlights, multi-sensors, doorbells & chimes, ViewPort viewers, live views, NVR system status, Alarm Manager webhooks, and real-time WebSocket event streaming.

---

## Platform Support
| Android | iOS | Web | Windows | Linux | MacOS |
| :-----: | :-: |:---:|:-------:| :---: |:-----:|
|   ✅    | ✅  |  ✅  |    ✅     |  ✅   |   ✅    |

## Features

- **Pure Dart**: Runs seamlessly on Flutter (Desktop/Mobile/Web), CLI scripts, server-side backends, and daemons.
- **Dual-Mode Connectivity**: Connects directly to local UniFi OS Consoles (Cloud Gateway, Dream Machine, UNVR) with self-signed SSL certificate handling, or remotely via the UniFi Cloud Connector proxy (`api.ui.com`).
- **Full Camera Capabilities**:
  - Discover adopted cameras, doorbells, and secondary package cameras (e.g. G4 Doorbell Pro).
  - Snapshot download (`image/jpeg`, main/package channels, high resolution).
  - RTSPS stream creation, quality negotiation (Low, Medium, High, Package), and token resolution.
  - PTZ preset navigation (`moveToPtzPreset`) and patrol automation (`startPtzPatrol`, `stopPtzPatrol`).
  - Two-way talkback sessions and microphone muting.
- **Smart Accessories**:
  - **Floodlights**: Query states, toggle LEDs, and adjust brightness levels.
  - **Sensors**: Read motion, open/close, temperature, humidity, ambient light, and alarm trips.
  - **Chimes**: Adjust volume, manage doorbell mappings, and test piezo buzzer rings.
  - **Viewers**: Inspect ViewPort hardware and assign live view layouts.
  - **Live Views**: Manage multi-camera grid matrices and cycling intervals.
  - **NVR**: Read Protect application metadata and NVR storage metrics.
- **Real-Time Subscriptions & Webhooks**:
  - WebSocket subscription (`/v1/subscribe/events`) with typed event streaming and auto-reconnect.
  - Embedded local HTTP webhook listener (`ProtectWebhookListener`) to catch outbound alerts from Protect Alarm Manager.
- **RTSP Sanitization Utilities**:
  - Robust URL parsing, port mapping (`7441` <-> `7447`), `?enableSrtp` stripping for FFmpeg/libmpv, and MongoDB ObjectId vs RTSP token heuristic.

---

## Getting Started

Add `unifi_protect` to your `pubspec.yaml`:

```bash
dart pub add unifi_protect
```

or

```bash
flutter pub add unifi_protect
```

### Authentication
Generate an API Key in the **UniFi Site Manager** (`unifi.ui.com`) under **Settings → API Keys** or **Integrations** on the bottom left sidebar.

---

## Usage Example

```dart
import 'package:unifi_protect/unifi_protect.dart';

void main() async {
  final client = UnifiProtectClient(
    options: const UnifiProtectOptions(
      host: '192.168.1.1',
      apiKey: 'YOUR_PROTECT_API_KEY',
      allowSelfSignedCertificates: true,
    ),
  );

  // 1. List Cameras
  final cameras = await client.cameras.listCameras();
  for (final cam in cameras) {
    print('Camera: ${cam.name} (${cam.type})');
    if (cam.hasPackageCamera) {
      print('  -> Has Package Camera');
    }
  }

  // 2. Fetch RTSP Stream URL
  final streamUrl = await client.cameras.fetchOrCreateStreamUrl(
    cameras.first.id,
    quality: StreamQuality.low,
  );
  print('Stream URL: $streamUrl');

  // 3. Listen for Real-Time Events
  client.events.eventStream.listen((event) {
    if (event is ProtectAlertEvent) {
      print('Alert: ${event.cameraId} - ${event.detectionType.displayName}');
    }
  });
  await client.events.connect();

  // 4. Clean up
  // await client.close();
}
```

---

## Web Support & Considerations

`unifi_protect` is fully compatible with Flutter Web and web-compiled Dart applications, with no dependency on `dart:io`. When deploying to a browser environment, keep the following platform considerations in mind:

- **CORS (Cross-Origin Resource Sharing)**: Direct HTTP requests from a browser to a local UniFi OS Console (e.g., `https://192.168.1.1`) are subject to browser CORS policies. If your UniFi OS Console does not serve CORS headers allowing your web origin, route requests through a lightweight backend reverse proxy (such as Nginx, Caddy, or a serverless function).
- **Self-Signed SSL Certificates**: Web browsers strictly enforce TLS certificate validity at the browser/OS level. The `allowSelfSignedCertificates` option is effective on native platforms (iOS, Android, macOS, Linux, Windows), but browsers do not allow client-side JavaScript to ignore TLS validation. For browser environments, configure your console with a valid public certificate (e.g., Let's Encrypt) or use a reverse proxy with a trusted certificate.
- **Cloud Mode (`api.ui.com`)**: Connecting remotely using `cloudConsoleId` routes through Ubiquiti's official Cloud Connector proxy (`https://api.ui.com`), which uses valid public CA-signed SSL certificates.
- **WebSocket Event Subscriptions**: Browsers restrict WebSocket connections from sending custom HTTP request headers (like `X-API-KEY`) during the initial handshake. For custom web setups, you can supply a custom `channelFactory` to `ProtectEventSubscription` to connect through a backend proxy or relay.
- **Embedded Webhook Server**: In browser sandboxes, binding a raw local TCP listening port is unsupported by Web standards. Consequently, `ProtectWebhookListener.start()` returns `false`. However, `ProtectWebhookListener.parseWebhookRequest()` is pure Dart and can be used on Web to parse webhook payloads received via serverless webhooks, web workers, or WebSocket push notifications.

---

### Disclaimer

`unifi_protect` is not associated with Ubiquiti, Inc.
