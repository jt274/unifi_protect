import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:unifi_protect/unifi_protect.dart';

void main() {
  const UnifiProtectOptions options = UnifiProtectOptions(
    apiKey: 'test-api-key-12345',
  );

  group('CameraService', () {
    test('listCameras parses cameras, featureFlags, and channels accurately',
        () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        expect(
            request.url.path, equals('/proxy/protect/integration/v1/cameras'));
        expect(request.headers['X-API-KEY'], equals('test-api-key-12345'));

        final List<Map<String, Object>> responsePayload = <Map<String, Object>>[
          <String, Object>{
            'id': 'cam_doorbell_pro',
            'name': 'Front Doorbell',
            'type': 'UVC G4 Doorbell Pro',
            'isDoorbell': true,
            'hasPackageCamera': true,
            'channels': <Map<String, Object>>[
              <String, Object>{
                'id': 0,
                'name': 'High',
                'isRtspEnabled': true,
                'rtspAlias': 'TokenMainHigh',
                'width': 1600,
                'height': 1200,
              },
              <String, Object>{
                'id': 2,
                'name': 'Low',
                'isRtspEnabled': true,
                'rtspAlias': 'TokenMainLow',
                'width': 640,
                'height': 480,
              },
              <String, Object>{
                'id': 3,
                'name': 'Package Camera',
                'isRtspEnabled': true,
                'rtspAlias': 'TokenPackage123',
                'width': 1200,
                'height': 1600,
              },
            ],
            'featureFlags': <String, Object>{
              'hasSmartDetect': true,
              'smartDetectTypes': <String>['person', 'package'],
            },
          },
          <String, Object>{
            'id': 'cam_ai_pro',
            'name': 'Driveway AI',
            'type': 'UVC AI Pro',
            'channels': <Map<String, Object>>[
              <String, Object>{
                'id': 0,
                'name': 'High',
                'isRtspEnabled': true,
                'rtspAlias': 'Token4K',
                'width': 3840,
                'height': 2160,
              },
            ],
            'featureFlags': <String, Object>{
              'hasSmartDetect': true,
              'smartDetectTypes': <String>['person', 'vehicle', 'animal'],
              'hasPtz': true,
            },
          },
        ];

        return http.Response(jsonEncode(responsePayload), 200);
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);
      final List<ProtectCamera> cameras = await service.listCameras();

      expect(cameras, hasLength(2));

      // Doorbell Pro
      final ProtectCamera doorbell = cameras[0];
      expect(doorbell.id, equals('cam_doorbell_pro'));
      expect(doorbell.isDoorbell, isTrue);
      expect(doorbell.hasPackageCamera, isTrue);
      expect(doorbell.channels, hasLength(3));
      expect(doorbell.packageChannel?.rtspAlias, equals('TokenPackage123'));
      expect(doorbell.supportedDetectionTypes,
          contains(ProtectDetectionType.ring));
      expect(doorbell.supportedDetectionTypes,
          contains(ProtectDetectionType.package));

      // AI Pro
      final ProtectCamera aiPro = cameras[1];
      expect(aiPro.id, equals('cam_ai_pro'));
      expect(aiPro.hasPtz, isTrue);
      expect(
          aiPro.supportedDetectionTypes,
          containsAll(<dynamic>[
            ProtectDetectionType.motion,
            ProtectDetectionType.person,
            ProtectDetectionType.vehicle,
            ProtectDetectionType.animal,
          ]));
    });

    test('getCamera returns single camera details', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        expect(request.url.path,
            equals('/proxy/protect/integration/v1/cameras/cam123'));
        return http.Response(
          jsonEncode(<String, String>{
            'id': 'cam123',
            'name': 'Backyard G5',
            'type': 'UVC G5 Bullet',
            'state': 'CONNECTED',
          }),
          200,
        );
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);
      final ProtectCamera cam = await service.getCamera('cam123');

      expect(cam.id, equals('cam123'));
      expect(cam.name, equals('Backyard G5'));
      expect(cam.isOnline, isTrue);
    });

    test('updateCamera sends PATCH request and parses result', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        expect(request.method, equals('PATCH'));
        expect(request.url.path,
            equals('/proxy/protect/integration/v1/cameras/cam123'));
        final Map<String, dynamic> body =
            jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['name'], equals('New Camera Name'));

        return http.Response(
          jsonEncode(<String, String>{
            'id': 'cam123',
            'name': 'New Camera Name',
            'type': 'UVC G5 Bullet',
          }),
          200,
        );
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);
      final ProtectCamera updated = await service
          .updateCamera('cam123', <String, dynamic>{'name': 'New Camera Name'});

      expect(updated.name, equals('New Camera Name'));
    });

    test('getSnapshot returns raw image bytes', () async {
      final Uint8List mockBytes =
          Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final MockClient mockClient = MockClient((http.Request request) async {
        expect(request.url.path,
            equals('/proxy/protect/integration/v1/cameras/cam123/snapshot'));
        expect(request.url.queryParameters['channel'], equals('package'));
        expect(request.url.queryParameters['highQuality'], equals('true'));
        return http.Response.bytes(mockBytes, 200,
            headers: <String, String>{'Content-Type': 'image/jpeg'});
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);
      final Uint8List bytes = await service.getSnapshot('cam123',
          channel: 'package', highQuality: true);

      expect(bytes, equals(mockBytes));
    });

    test('getRtspsStreams and createRtspsStream handle stream URLs', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode(<String, String>{
              'high': 'rtsps://192.168.1.1:7441/TokenHigh?enableSrtp',
              'low': 'rtsps://192.168.1.1:7441/TokenLow?enableSrtp',
            }),
            200,
          );
        } else if (request.method == 'POST') {
          return http.Response(
            jsonEncode(<String, String>{
              'package': 'rtsps://192.168.1.1:7441/TokenPkg?enableSrtp',
            }),
            201,
          );
        }
        return http.Response('Not Found', 404);
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);

      final Map<String, String> streams =
          await service.getRtspsStreams('cam123');
      expect(streams['high'], equals('rtsp://192.168.1.1:7447/TokenHigh'));
      expect(streams['low'], equals('rtsp://192.168.1.1:7447/TokenLow'));

      final Map<String, String> created = await service
          .createRtspsStream('cam123', qualities: <String>['package']);
      expect(created['package'], equals('rtsp://192.168.1.1:7447/TokenPkg'));
    });

    test('PTZ controls execute POST requests correctly', () async {
      final List<String> actions = <String>[];
      final MockClient mockClient = MockClient((http.Request request) async {
        actions.add('${request.method} ${request.url.path}');
        return http.Response('', 200);
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);

      await service.moveToPtzPreset('ptz1', 2);
      await service.startPtzPatrol('ptz1', 0);
      await service.stopPtzPatrol('ptz1');
      await service.disableMicrophone('ptz1');

      expect(
          actions,
          containsAll(<dynamic>[
            'POST /proxy/protect/integration/v1/cameras/ptz1/ptz/goto/2',
            'POST /proxy/protect/integration/v1/cameras/ptz1/ptz/patrol/start/0',
            'POST /proxy/protect/integration/v1/cameras/ptz1/ptz/patrol/stop',
            'POST /proxy/protect/integration/v1/cameras/ptz1/microphone/disable',
          ]));
    });
  });
}
