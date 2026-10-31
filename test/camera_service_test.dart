import 'dart:convert';
import 'dart:io';
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
        ]),
      );
    });

    test(
        'listCameras with data map payload, non-list envelope, and error handling',
        () async {
      final MockClient okClient = MockClient((http.Request request) async {
        return http.Response(
            jsonEncode(<String, dynamic>{'data': <dynamic>[]}), 200);
      });
      final CameraService okService =
          CameraService(options: options, client: okClient);
      expect(await okService.listCameras(), isEmpty);

      final MockClient emptyClient = MockClient((http.Request request) async {
        return http.Response(
            jsonEncode(<String, dynamic>{'unexpected': true}), 200);
      });
      final CameraService emptyService =
          CameraService(options: options, client: emptyClient);
      expect(await emptyService.listCameras(), isEmpty);

      final MockClient errClient = MockClient((http.Request request) async {
        return http.Response('Server Error', 500);
      });
      final CameraService errService =
          CameraService(options: options, client: errClient);
      expect(() => errService.listCameras(), throwsA(isA<HttpException>()));
    });

    test('getCamera returns single camera details or throws', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/cam123')) {
          return http.Response(
            jsonEncode(<String, String>{
              'id': 'cam123',
              'name': 'Backyard G5',
              'type': 'UVC G5 Bullet',
              'state': 'CONNECTED',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/bad_format')) {
          return http.Response('["not_a_map"]', 200);
        }
        return http.Response('Not Found', 404);
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);
      final ProtectCamera cam = await service.getCamera('cam123');

      expect(cam.id, equals('cam123'));
      expect(cam.name, equals('Backyard G5'));
      expect(cam.isOnline, isTrue);

      expect(
          () => service.getCamera('not_found'), throwsA(isA<HttpException>()));
      expect(() => service.getCamera('bad_format'),
          throwsA(isA<FormatException>()));
    });

    test('updateCamera sends PATCH request and parses result or throws',
        () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/err')) {
          return http.Response('Error', 500);
        }
        if (request.method == 'PATCH') {
          if (request.url.path.endsWith('/cam204')) {
            return http.Response('', 204);
          }
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, String>{
              'id': 'cam123',
              'name': body['name']?.toString() ?? 'Default',
              'type': 'UVC G5 Bullet',
            }),
            200,
          );
        } else if (request.method == 'GET' &&
            request.url.path.endsWith('/cam204')) {
          return http.Response(
            jsonEncode(<String, String>{
              'id': 'cam204',
              'name': 'Fetched After 204',
              'type': 'UVC G5 Bullet',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);
      final ProtectCamera updated = await service
          .updateCamera('cam123', <String, dynamic>{'name': 'New Camera Name'});
      expect(updated.name, equals('New Camera Name'));

      final ProtectCamera via204 =
          await service.updateCamera('cam204', <String, dynamic>{});
      expect(via204.name, equals('Fetched After 204'));

      expect(() => service.updateCamera('err', <String, dynamic>{}),
          throwsA(isA<HttpException>()));
    });

    test('getSnapshot returns raw image bytes or throws', () async {
      final Uint8List mockBytes =
          Uint8List.fromList(<int>[0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.contains('/err/snapshot')) {
          return http.Response('Error', 500);
        }
        return http.Response.bytes(mockBytes, 200,
            headers: <String, String>{'Content-Type': 'image/jpeg'});
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);
      final Uint8List bytes = await service.getSnapshot('cam123',
          channel: 'package', highQuality: true);
      expect(bytes, equals(mockBytes));

      expect(() => service.getSnapshot('err'), throwsA(isA<HttpException>()));
    });

    test('getRtspsStreams and createRtspsStream handle stream URLs and errors',
        () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.contains('/err/rtsps-stream')) {
          return http.Response('Error', 500);
        }
        if (request.url.path.contains('/bad_json/rtsps-stream')) {
          return http.Response('[]', 200);
        }
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

      expect(await service.getRtspsStreams('err'), isEmpty);
      expect(await service.getRtspsStreams('bad_json'), isEmpty);

      final Map<String, String> created = await service
          .createRtspsStream('cam123', qualities: <String>['package']);
      expect(created['package'], equals('rtsp://192.168.1.1:7447/TokenPkg'));

      expect(
        () => service.createRtspsStream('err'),
        throwsA(isA<HttpException>()),
      );
      expect(await service.createRtspsStream('bad_json'), isEmpty);
    });

    test('deleteRtspsStream handles status codes', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.contains('/cam_ok')) {
          return http.Response('', 200);
        }
        if (request.url.path.contains('/cam_204')) {
          return http.Response('', 204);
        }
        if (request.url.path.contains('/cam_404')) {
          return http.Response('Not found', 404);
        }
        return http.Response('Internal Error', 500);
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);
      await service.deleteRtspsStream('cam_ok');
      await service.deleteRtspsStream('cam_204');
      await service.deleteRtspsStream('cam_404');
      expect(() => service.deleteRtspsStream('cam_500'),
          throwsA(isA<HttpException>()));
    });

    test('PTZ controls execute POST requests correctly and handle failures',
        () async {
      final List<String> actions = <String>[];
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.contains('/err/')) {
          return http.Response('Error', 500);
        }
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
        ]),
      );

      expect(() => service.moveToPtzPreset('err', 0),
          throwsA(isA<HttpException>()));
      expect(() => service.startPtzPatrol('err', 0),
          throwsA(isA<HttpException>()));
      expect(() => service.stopPtzPatrol('err'), throwsA(isA<HttpException>()));
      expect(() => service.disableMicrophone('err'),
          throwsA(isA<HttpException>()));
    });

    test('createTalkbackSession handles 200/201, non-map, and failures',
        () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.contains('/cam_ok/talkback-session')) {
          return http.Response(
              jsonEncode(<String, dynamic>{'sessionId': 'session_abc'}), 200);
        }
        if (request.url.path.contains('/cam_nonmap/talkback-session')) {
          return http.Response('[]', 200);
        }
        return http.Response('Error', 500);
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);

      final Map<String, dynamic> session =
          await service.createTalkbackSession('cam_ok');
      expect(session['sessionId'], equals('session_abc'));

      final Map<String, dynamic> nonMap =
          await service.createTalkbackSession('cam_nonmap');
      expect(nonMap, isEmpty);

      expect(() => service.createTalkbackSession('err'),
          throwsA(isA<HttpException>()));
    });

    test('fetchAvailableStreamQualities and fetchOrCreateStreamUrl', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/cameras/cam_avail')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'cam_avail',
              'name': 'Avail Cam',
              'type': 'UVC G4 Pro',
              'channels': <dynamic>[
                <String, dynamic>{
                  'id': 0,
                  'name': 'High',
                  'isRtspEnabled': true,
                  'rtspAlias': 'AliasHigh',
                },
                <String, dynamic>{
                  'id': 1,
                  'name': 'Medium',
                  'isRtspEnabled': true,
                  'rtspAlias': 'AliasMed',
                },
                <String, dynamic>{
                  'id': 2,
                  'name': 'Low',
                  'isRtspEnabled': true,
                  'rtspAlias': 'AliasLow',
                },
                <String, dynamic>{
                  'id': 3,
                  'name': 'Package Camera',
                  'isRtspEnabled': true,
                  'rtspAlias': 'AliasPkg',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/cameras/cam_avail/rtsps-stream')) {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'high': 'rtsps://192.168.1.1:7441/AliasHigh?enableSrtp',
                'medium': 'rtsps://192.168.1.1:7441/AliasMed?enableSrtp',
                'low': 'rtsps://192.168.1.1:7441/AliasLow?enableSrtp',
                'package': 'rtsps://192.168.1.1:7441/AliasPkg?enableSrtp',
              }),
              200,
            );
          }
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'low': 'rtsps://192.168.1.1:7441/CreatedLow?enableSrtp',
              }),
              201,
            );
          }
        }
        if (request.url.path.endsWith('/cameras/cam_none/rtsps-stream')) {
          if (request.method == 'GET') {
            return http.Response('{}', 200);
          }
          if (request.method == 'POST') {
            return http.Response('Error', 500);
          }
        }
        if (request.url.path.endsWith('/cameras/cam_only_low/rtsps-stream')) {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'low': 'rtsps://192.168.1.1:7441/OnlyLowAlias?enableSrtp',
              }),
              200,
            );
          }
        }
        if (request.url.path.endsWith('/cameras/cam_create/rtsps-stream')) {
          if (request.method == 'GET') {
            return http.Response('{}', 200);
          }
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'high': 'rtsps://192.168.1.1:7441/CreatedHigh?enableSrtp',
              }),
              201,
            );
          }
        }
        if (request.url.path.endsWith('/cameras/cam_create_low/rtsps-stream')) {
          if (request.method == 'GET') {
            return http.Response('{}', 200);
          }
          if (request.method == 'POST') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'low': 'rtsps://192.168.1.1:7441/CreatedLow?enableSrtp',
              }),
              201,
            );
          }
        }
        return http.Response('Not Found', 404);
      });

      final CameraService service =
          CameraService(options: options, client: mockClient);

      final Map<String, String> qualities =
          await service.fetchAvailableStreamQualities('cam_avail');
      expect(qualities['high'], equals('rtsp://192.168.1.1:7447/AliasHigh'));
      expect(qualities['medium'], equals('rtsp://192.168.1.1:7447/AliasMed'));
      expect(qualities['low'], equals('rtsp://192.168.1.1:7447/AliasLow'));
      expect(qualities['package'], equals('rtsp://192.168.1.1:7447/AliasPkg'));

      // Existing stream
      final String? lowUrl = await service.fetchOrCreateStreamUrl('cam_avail');
      expect(lowUrl, equals('rtsp://192.168.1.1:7447/AliasLow'));

      final String? pkgUrl =
          await service.fetchOrCreateStreamUrl('cam_avail_package');
      expect(pkgUrl, equals('rtsp://192.168.1.1:7447/AliasPkg'));

      // Inexact fallback to existing lower/higher quality in active streams
      final String? fallbackFromActive = await service.fetchOrCreateStreamUrl(
        'cam_only_low',
        quality: StreamQuality.high,
      );
      expect(
          fallbackFromActive, equals('rtsp://192.168.1.1:7447/OnlyLowAlias'));

      // Creation succeeds when stream not active
      final String? createdUrl = await service.fetchOrCreateStreamUrl(
        'cam_create',
        quality: StreamQuality.high,
        exactMatchOnly: true,
      );
      expect(createdUrl, equals('rtsp://192.168.1.1:7447/CreatedHigh'));

      final String? createdLowUrl = await service.fetchOrCreateStreamUrl(
        'cam_create_low',
      );
      expect(createdLowUrl, equals('rtsp://192.168.1.1:7447/CreatedLow'));

      // Not found & creation fails
      final String? noneUrl = await service.fetchOrCreateStreamUrl('cam_none',
          exactMatchOnly: true);
      expect(noneUrl, isNull);
    });

    test('extractStreamUrlFromResponse branches', () {
      expect(
          CameraService.extractStreamUrlFromResponse('',
              nvrHost: '192.168.1.1'),
          isNull);
      expect(
          CameraService.extractStreamUrlFromResponse('[]',
              nvrHost: '192.168.1.1'),
          isNull);

      const String jsonBody = '''
      {
        "high": "rtsps://192.168.1.1:7441/TokenHigh?enableSrtp",
        "medium": "rtsps://192.168.1.1:7441/TokenMed?enableSrtp",
        "low": "rtsps://192.168.1.1:7441/TokenLow?enableSrtp",
        "package": "rtsps://192.168.1.1:7441/TokenPkg?enableSrtp"
      }
      ''';

      expect(
        CameraService.extractStreamUrlFromResponse(
          jsonBody,
          nvrHost: '10.0.0.1',
          qualityPreference: StreamQuality.medium,
        ),
        equals('rtsp://10.0.0.1:7447/TokenMed'),
      );

      expect(
        CameraService.extractStreamUrlFromResponse(
          jsonBody,
          nvrHost: '10.0.0.1',
          qualityPreference: StreamQuality.high,
        ),
        equals('rtsp://10.0.0.1:7447/TokenHigh'),
      );

      expect(
        CameraService.extractStreamUrlFromResponse(
          jsonBody,
          nvrHost: '10.0.0.1',
          qualityPreference: StreamQuality.package,
        ),
        equals('rtsp://10.0.0.1:7447/TokenHigh'),
      );

      expect(
        CameraService.extractStreamUrlFromResponse(
          jsonBody,
          nvrHost: '10.0.0.1',
          isPackageCamera: true,
        ),
        equals('rtsp://10.0.0.1:7447/TokenPkg'),
      );

      expect(
        CameraService.extractStreamUrlFromResponse(
          jsonBody,
          nvrHost: '10.0.0.1',
          qualityPreference: StreamQuality.high,
          exactMatchOnly: true,
        ),
        equals('rtsp://10.0.0.1:7447/TokenHigh'),
      );
    });
  });
}
