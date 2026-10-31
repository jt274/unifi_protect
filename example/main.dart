import 'package:unifi_protect/unifi_protect.dart';

void main() async {
  // Configure client options
  final options = const UnifiProtectOptions(
    host: '192.168.1.1',
    port: 443,
    apiKey: 'YOUR_PROTECT_API_KEY',
    allowSelfSignedCertificates: true,
  );

  final client = UnifiProtectClient(options: options);

  try {
    // 1. Fetch NVR System Info
    final meta = await client.nvr.getMetaInfo();
    print('Protect Version: ${meta.version}');

    // 2. Discover Cameras
    final cameras = await client.cameras.listCameras();
    print('Discovered ${cameras.length} cameras:');
    for (final cam in cameras) {
      print(' - ${cam.name} (${cam.type})');
      print('   Supported Detections: ${cam.supportedDetectionTypes}');
    }

    // 3. Connect to Real-time Events
    client.events.eventStream.listen((event) {
      if (event is ProtectAlertEvent) {
        print(
            '[ALERT] Camera: ${event.cameraId}, Type: ${event.detectionType.displayName}');
      }
    });
    await client.events.connect();
  } catch (e) {
    print('Error: $e');
  } finally {
    await client.close();
  }
}
