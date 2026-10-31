import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:unifi_protect/unifi_protect.dart';

void main() {
  const UnifiProtectOptions options = UnifiProtectOptions(
    apiKey: 'test-key',
  );

  group('LiveviewService', () {
    test('CRUD operations on live views work', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode(<Map<String, Object>>[
              <String, Object>{
                'id': 'lv_1',
                'name': 'Default Grid',
                'isDefault': true,
                'slots': <Map<String, Object>>[
                  <String, Object>{
                    'cameras': <String>['cam1', 'cam2'],
                    'cycleMode': 'motion',
                    'cycleInterval': 15,
                  }
                ],
              }
            ]),
            200,
          );
        } else if (request.method == 'POST') {
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'lv_new',
              'name': body['name'],
              'isDefault': false,
              'slots': body['slots'] ?? <Map<String, dynamic>>[],
            }),
            201,
          );
        } else if (request.method == 'DELETE') {
          return http.Response('', 204);
        }
        return http.Response('Not Found', 404);
      });

      final LiveviewService service =
          LiveviewService(options: options, client: mockClient);
      final List<ProtectLiveview> list = await service.listLiveviews();
      expect(list, hasLength(1));
      expect(list[0].name, equals('Default Grid'));
      expect(list[0].slots.first.cycleMode, equals('motion'));

      final ProtectLiveview created =
          await service.createLiveview(<String, dynamic>{
        'name': 'Custom Quad',
        'slots': <Map<String, List<String>>>[
          <String, List<String>>{
            'cameras': <String>['cam1']
          }
        ],
      });
      expect(created.id, equals('lv_new'));
      expect(created.name, equals('Custom Quad'));

      await service.deleteLiveview('lv_new');
    });
  });

  group('NvrService', () {
    test('getMetaInfo and getNvr retrieve system and storage data', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/meta/info')) {
          return http.Response(
            jsonEncode(<String, String>{
              'version': '5.0.3',
              'build': '12345',
              'releaseChannel': 'stable',
            }),
            200,
          );
        } else if (request.url.path.endsWith('/nvrs')) {
          return http.Response(
            jsonEncode(<Map<String, Object>>[
              <String, Object>{
                'id': 'nvr_primary',
                'name': 'UNVR Pro',
                'version': '5.0.3',
                'upSince': 1730000000000,
                'cameraCount': 8,
                'isRecording': true,
                'storageInfo': <String, int>{
                  'totalSize': 16000000000000,
                  'usedSize': 8000000000000,
                  'availableSize': 8000000000000,
                },
              }
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final NvrService service =
          NvrService(options: options, client: mockClient);

      final ProtectMetaInfo meta = await service.getMetaInfo();
      expect(meta.version, equals('5.0.3'));
      expect(meta.build, equals('12345'));

      final ProtectNvr nvr = await service.getNvr();
      expect(nvr.id, equals('nvr_primary'));
      expect(nvr.name, equals('UNVR Pro'));
      expect(nvr.cameraCount, equals(8));
      expect(nvr.storageTotalBytes, equals(16000000000000));
    });
  });

  group('AlarmManagerService', () {
    test('triggerAlarmWebhook sends POST request', () async {
      bool triggered = false;
      final MockClient mockClient = MockClient((http.Request request) async {
        expect(
          request.url.path,
          equals(
              '/proxy/protect/integration/v1/alarm-manager/webhook/alarm_custom_1'),
        );
        expect(request.method, equals('POST'));
        triggered = true;
        return http.Response('', 200);
      });

      final AlarmManagerService service =
          AlarmManagerService(options: options, client: mockClient);
      await service.triggerAlarmWebhook(
          'alarm_custom_1', <String, dynamic>{'state': 'armed'});
      expect(triggered, isTrue);
    });
  });
}
