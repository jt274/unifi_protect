import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:unifi_protect/unifi_protect.dart';

void main() {
  const UnifiProtectOptions options = UnifiProtectOptions(
    apiKey: 'test-key',
  );

  group('LiveviewService', () {
    test('CRUD operations and error handling on live views work', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.host == 'err' || request.url.path.contains('/err')) {
          return http.Response('Error', 500);
        }
        if (request.method == 'GET') {
          if (request.url.path.endsWith('/liveviews')) {
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
          }
          if (request.url.path.endsWith('/lv_204')) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'id': 'lv_204',
                'name': 'Liveview 204',
                'isDefault': false,
                'slots': <dynamic>[],
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'lv_1',
              'name': 'Default Grid',
              'isDefault': true,
              'slots': <dynamic>[],
            }),
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
        } else if (request.method == 'PATCH') {
          if (request.url.path.endsWith('/lv_204')) {
            return http.Response('', 204);
          }
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'lv_1',
              'name': body['name'] ?? 'Updated Grid',
              'isDefault': true,
              'slots': <dynamic>[],
            }),
            200,
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

      final ProtectLiveview single = await service.getLiveview('lv_1');
      expect(single.id, equals('lv_1'));

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

      final ProtectLiveview updated = await service.updateLiveview(
        'lv_1',
        <String, dynamic>{'name': 'Patched Grid'},
      );
      expect(updated.name, equals('Patched Grid'));

      final ProtectLiveview updated204 = await service.updateLiveview(
        'lv_204',
        <String, dynamic>{},
      );
      expect(updated204.id, equals('lv_204'));

      await service.deleteLiveview('lv_new');

      // Error branches
      final LiveviewService errService = LiveviewService(
        options: const UnifiProtectOptions(apiKey: 'k', host: 'err'),
        client: mockClient,
      );
      expect(() => errService.listLiveviews(), throwsA(isA<HttpException>()));
      expect(() => errService.getLiveview('err'), throwsA(isA<HttpException>()));
      expect(() => errService.createLiveview(<String, dynamic>{}), throwsA(isA<HttpException>()));
      expect(() => errService.updateLiveview('err', <String, dynamic>{}), throwsA(isA<HttpException>()));
      expect(() => errService.deleteLiveview('err'), throwsA(isA<HttpException>()));
    });

    test('listLiveviews handles data envelope and empty map', () async {
      final MockClient dataClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'data': <dynamic>[]}), 200);
      });
      final LiveviewService dataService = LiveviewService(options: options, client: dataClient);
      expect(await dataService.listLiveviews(), isEmpty);

      final MockClient emptyClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'none': true}), 200);
      });
      final LiveviewService emptyService = LiveviewService(options: options, client: emptyClient);
      expect(await emptyService.listLiveviews(), isEmpty);
    });
  });

  group('NvrService', () {
    test('getMetaInfo, getNvr, updateNvr work and handle errors and fallbacks', () async {
      bool useNvrs404 = false;
      bool returnDataEnvelope = false;
      bool returnInvalidFormat = false;
      bool return204OnPatch = false;

      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.host == 'err' || request.url.path.contains('/err')) {
          return http.Response('Error', 500);
        }
        if (request.url.path.endsWith('/meta/info')) {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'version': '5.0.3',
              'build': 'build1',
              'releaseChannel': 'stable',
              'controllerVersion': '3.2.12',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/nvrs')) {
          if (request.method == 'GET') {
            if (useNvrs404) {
              return http.Response('Not Found', 404);
            }
            if (returnInvalidFormat) {
              return http.Response('12345', 200);
            }
            if (returnDataEnvelope) {
              return http.Response(
                jsonEncode(<String, dynamic>{
                  'data': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'id': 'nvr_primary',
                      'name': 'UNVR Pro',
                      'version': '5.0.3',
                    }
                  ],
                }),
                200,
              );
            }
            return http.Response(
              jsonEncode(<Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 'nvr_primary',
                  'name': 'UNVR Pro',
                  'version': '5.0.3',
                  'storageInfo': <String, dynamic>{
                    'totalSize': 16000000000000,
                    'usedSize': 8000000000000,
                  },
                }
              ]),
              200,
            );
          }
          if (request.method == 'PATCH') {
            if (return204OnPatch) {
              return http.Response('', 204);
            }
            final Map<String, dynamic> body =
                jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode(<String, dynamic>{
                'id': 'nvr_primary',
                'name': body['name'] ?? 'UNVR Pro',
                'version': '5.0.3',
              }),
              200,
            );
          }
        }
        if (request.url.path.endsWith('/nvr')) {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'id': 'nvr_primary',
                'name': 'UNVR Pro Fallback',
                'version': '5.0.3',
              }),
              200,
            );
          }
        }
        return http.Response('Not Found', 404);
      });

      final NvrService service =
          NvrService(options: options, client: mockClient);

      final ProtectMetaInfo meta = await service.getMetaInfo();
      expect(meta.version, equals('5.0.3'));
      expect(meta.build, equals('build1'));
      expect(meta.releaseChannel, equals('stable'));
      expect(meta.controllerVersion, equals('3.2.12'));

      // 1. Normal List response from /nvrs
      final ProtectNvr nvr = await service.getNvr();
      expect(nvr.id, equals('nvr_primary'));
      expect(nvr.name, equals('UNVR Pro'));
      expect(nvr.storageTotalBytes, equals(16000000000000));
      expect(nvr.storageUsedBytes, equals(8000000000000));

      // 2. Data envelope Map response from /nvrs
      returnDataEnvelope = true;
      final ProtectNvr envelopeNvr = await service.getNvr();
      expect(envelopeNvr.name, equals('UNVR Pro'));
      returnDataEnvelope = false;

      // 3. Fallback to /nvr on 404
      useNvrs404 = true;
      final ProtectNvr fallbackNvr = await service.getNvr();
      expect(fallbackNvr.name, equals('UNVR Pro Fallback'));
      useNvrs404 = false;

      // 4. FormatException on invalid format
      returnInvalidFormat = true;
      await expectLater(service.getNvr(), throwsA(isA<FormatException>()));
      returnInvalidFormat = false;

      // 5. Update NVR normal (200)
      final ProtectNvr updatedNvr =
          await service.updateNvr(<String, dynamic>{'name': 'My UNVR'});
      expect(updatedNvr.name, equals('My UNVR'));

      // 6. Update NVR 204 calls getNvr
      return204OnPatch = true;
      final ProtectNvr nvr204 =
          await service.updateNvr(<String, dynamic>{'name': '204 UNVR'});
      expect(nvr204.id, equals('nvr_primary'));
      return204OnPatch = false;

      // Error branches
      final NvrService errService = NvrService(
        options: const UnifiProtectOptions(apiKey: 'k', host: 'err'),
        client: mockClient,
      );
      expect(errService.getMetaInfo(), throwsA(isA<HttpException>()));
      expect(errService.getNvr(), throwsA(isA<HttpException>()));
      expect(errService.updateNvr(<String, dynamic>{}), throwsA(isA<HttpException>()));
    });
  });

  group('AlarmManagerService', () {
    test('triggerAlarmWebhook sends POST request or throws on failure', () async {
      int simulatedStatus = 200;
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.host == 'err' || request.url.path.contains('/err')) {
          return http.Response('Webhook failed', 500);
        }
        expect(request.method, equals('POST'));
        expect(request.url.path, equals('/proxy/protect/integration/v1/alarm-manager/webhook/test_webhook_id'));
        return http.Response('', simulatedStatus);
      });

      final AlarmManagerService service =
          AlarmManagerService(options: options, client: mockClient);
      
      // 200 with payload
      await service.triggerAlarmWebhook(
        'test_webhook_id',
        <String, dynamic>{'camera': 'cam_1'},
      );

      // 201 without payload
      simulatedStatus = 201;
      await service.triggerAlarmWebhook('test_webhook_id');

      // 204 without payload
      simulatedStatus = 204;
      await service.triggerAlarmWebhook('test_webhook_id');

      // 400 failure
      simulatedStatus = 400;
      expect(
        () => service.triggerAlarmWebhook('test_webhook_id'),
        throwsA(isA<HttpException>()),
      );

      final AlarmManagerService errService = AlarmManagerService(
        options: const UnifiProtectOptions(apiKey: 'k', host: 'err'),
        client: mockClient,
      );
      expect(
        () => errService.triggerAlarmWebhook('err'),
        throwsA(isA<HttpException>()),
      );
    });
  });
}
