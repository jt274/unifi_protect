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

  group('LightService', () {
    test('listLights and controls work, handling errors and 204 updates', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.host == 'err' || request.url.path.contains('/err')) {
          return http.Response('Error', 500);
        }
        if (request.method == 'GET') {
          if (request.url.path.endsWith('/lights')) {
            return http.Response(
              jsonEncode(<Map<String, Object>>[
                <String, Object>{
                  'id': 'light_1',
                  'name': 'Backyard Flood',
                  'type': 'UP-FloodLight',
                  'isLedOn': true,
                  'lightDeviceSettings': <String, int>{'ledLevel': 85},
                }
              ]),
              200,
            );
          }
          if (request.url.path.endsWith('/light_1')) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'id': 'light_1',
                'name': 'Backyard Flood',
                'type': 'UP-FloodLight',
                'isLedOn': true,
                'lightDeviceSettings': <String, int>{'ledLevel': 85},
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/light_204')) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'id': 'light_204',
                'name': 'Backyard Flood 204',
                'type': 'UP-FloodLight',
                'isLedOn': true,
              }),
              200,
            );
          }
        } else if (request.method == 'PATCH') {
          if (request.url.path.endsWith('/light_204')) {
            return http.Response('', 204);
          }
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'light_1',
              'name': 'Backyard Flood',
              'type': 'UP-FloodLight',
              'isLedOn': body['isLedOn'] ?? true,
              'lightDeviceSettings':
                  body['lightDeviceSettings'] ?? <String, int>{'ledLevel': 85},
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final LightService service =
          LightService(options: options, client: mockClient);
      final List<ProtectLight> lights = await service.listLights();
      expect(lights, hasLength(1));
      expect(lights[0].brightness, equals(85));
      expect(lights[0].isLedOn, isTrue);

      final ProtectLight single = await service.getLight('light_1');
      expect(single.id, equals('light_1'));

      final ProtectLight toggled = await service.setLed('light_1', false);
      expect(toggled.isLedOn, isFalse);

      final ProtectLight dimmed = await service.setBrightness('light_1', 40);
      expect(dimmed.brightness, equals(40));

      final ProtectLight updated204 = await service.updateLight('light_204', <String, dynamic>{});
      expect(updated204.id, equals('light_204'));

      // Error branches
      final LightService errService = LightService(
        options: const UnifiProtectOptions(apiKey: 'k', host: 'err'),
        client: mockClient,
      );
      expect(() => errService.listLights(), throwsA(isA<HttpException>()));
      expect(() => errService.getLight('err'), throwsA(isA<HttpException>()));
      expect(() => errService.updateLight('err', <String, dynamic>{}), throwsA(isA<HttpException>()));
    });

    test('listLights handles data envelope and empty map', () async {
      final MockClient dataClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'data': <dynamic>[]}), 200);
      });
      final LightService dataService = LightService(options: options, client: dataClient);
      expect(await dataService.listLights(), isEmpty);

      final MockClient emptyClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'none': true}), 200);
      });
      final LightService emptyService = LightService(options: options, client: emptyClient);
      expect(await emptyService.listLights(), isEmpty);
    });
  });

  group('SensorService', () {
    test('listSensors, getSensor, and updateSensor work and handle errors', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.host == 'err' || request.url.path.contains('/err')) {
          return http.Response('Error', 500);
        }
        if (request.method == 'GET') {
          if (request.url.path.endsWith('/sensors')) {
            return http.Response(
              jsonEncode(<Map<String, Object>>[
                <String, Object>{
                  'id': 'sensor_entry',
                  'name': 'Front Door Sensor',
                  'type': 'UP-Sense',
                  'state': 'CONNECTED',
                  'batteryStatus': <String, int>{'percentage': 92},
                  'isOpen': true,
                  'isMotionDetected': false,
                  'stats': <String, Map<String, double>>{
                    'temperature': <String, double>{'value': 21.5},
                    'humidity': <String, double>{'value': 48.0},
                    'light': <String, double>{'value': 350.0},
                  },
                }
              ]),
              200,
            );
          }
          if (request.url.path.endsWith('/sensor_204')) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'id': 'sensor_204',
                'name': 'Sensor 204',
                'type': 'UP-Sense',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, Object>{
              'id': 'sensor_entry',
              'name': 'Front Door Sensor',
              'type': 'UP-Sense',
              'state': 'CONNECTED',
              'batteryStatus': <String, int>{'percentage': 92},
              'isOpen': true,
              'isMotionDetected': false,
              'stats': <String, Map<String, double>>{
                'temperature': <String, double>{'value': 21.5},
                'humidity': <String, double>{'value': 48.0},
                'light': <String, double>{'value': 350.0},
              },
            }),
            200,
          );
        } else if (request.method == 'PATCH') {
          if (request.url.path.endsWith('/sensor_204')) {
            return http.Response('', 204);
          }
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'sensor_entry',
              'name': 'Updated Sensor',
              'type': 'UP-Sense',
              'state': 'CONNECTED',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final SensorService service =
          SensorService(options: options, client: mockClient);
      final List<ProtectSensor> sensors = await service.listSensors();
      expect(sensors, hasLength(1));

      final ProtectSensor sensor = await service.getSensor('sensor_entry');
      expect(sensor.id, equals('sensor_entry'));
      expect(sensor.isOpen, isTrue);
      expect(sensor.batteryPercentage, equals(92));
      expect(sensor.temperature, equals(21.5));
      expect(sensor.humidity, equals(48.0));
      expect(sensor.lightLevel, equals(350.0));

      final ProtectSensor updated = await service.updateSensor(
        'sensor_entry',
        <String, dynamic>{'name': 'Updated Sensor'},
      );
      expect(updated.name, equals('Updated Sensor'));

      final ProtectSensor updated204 =
          await service.updateSensor('sensor_204', <String, dynamic>{});
      expect(updated204.id, equals('sensor_204'));

      // Error branches
      final SensorService errService = SensorService(
        options: const UnifiProtectOptions(apiKey: 'k', host: 'err'),
        client: mockClient,
      );
      expect(() => errService.listSensors(), throwsA(isA<HttpException>()));
      expect(() => errService.getSensor('err'), throwsA(isA<HttpException>()));
      expect(() => errService.updateSensor('err', <String, dynamic>{}), throwsA(isA<HttpException>()));
    });

    test('listSensors handles data envelope and empty map', () async {
      final MockClient dataClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'data': <dynamic>[]}), 200);
      });
      final SensorService dataService = SensorService(options: options, client: dataClient);
      expect(await dataService.listSensors(), isEmpty);

      final MockClient emptyClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'none': true}), 200);
      });
      final SensorService emptyService = SensorService(options: options, client: emptyClient);
      expect(await emptyService.listSensors(), isEmpty);
    });
  });

  group('ChimeService', () {
    test('listChimes, setVolume, playBuzzer work and handle errors', () async {
      bool buzzerPlayed = false;
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.host == 'err' || request.url.path.contains('/err')) {
          return http.Response('Error', 500);
        }
        if (request.url.path.endsWith('/play-buzzer')) {
          buzzerPlayed = true;
          return http.Response('', 200);
        }
        if (request.method == 'GET') {
          if (request.url.path.endsWith('/chimes')) {
            return http.Response(
              jsonEncode(<Map<String, Object>>[
                <String, Object>{
                  'id': 'chime_hallway',
                  'name': 'Hallway Chime',
                  'type': 'UP-Chime',
                  'volume': 80,
                  'cameraIds': <String>['doorbell_1'],
                }
              ]),
              200,
            );
          }
          if (request.url.path.endsWith('/chime_204')) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'id': 'chime_204',
                'name': 'Chime 204',
                'type': 'UP-Chime',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'chime_hallway',
              'name': 'Hallway Chime',
              'type': 'UP-Chime',
              'volume': 80,
            }),
            200,
          );
        }
        if (request.method == 'PATCH') {
          if (request.url.path.endsWith('/chime_204')) {
            return http.Response('', 204);
          }
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'chime_hallway',
              'name': 'Hallway Chime',
              'type': 'UP-Chime',
              'volume': body['volume'] ?? 80,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final ChimeService service =
          ChimeService(options: options, client: mockClient);
      final List<ProtectChime> chimes = await service.listChimes();
      expect(chimes, hasLength(1));
      expect(chimes[0].volume, equals(80));

      final ProtectChime single = await service.getChime('chime_hallway');
      expect(single.id, equals('chime_hallway'));

      final ProtectChime updated = await service.setVolume('chime_hallway', 95);
      expect(updated.volume, equals(95));

      await service.playBuzzer('chime_hallway');
      expect(buzzerPlayed, isTrue);

      final ProtectChime updated204 =
          await service.updateChime('chime_204', <String, dynamic>{});
      expect(updated204.id, equals('chime_204'));

      // Error branches
      final ChimeService errService = ChimeService(
        options: const UnifiProtectOptions(apiKey: 'k', host: 'err'),
        client: mockClient,
      );
      expect(() => errService.listChimes(), throwsA(isA<HttpException>()));
      expect(() => errService.getChime('err'), throwsA(isA<HttpException>()));
      expect(() => errService.updateChime('err', <String, dynamic>{}), throwsA(isA<HttpException>()));
      expect(() => errService.playBuzzer('err'), throwsA(isA<HttpException>()));
    });

    test('listChimes handles data envelope and empty map', () async {
      final MockClient dataClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'data': <dynamic>[]}), 200);
      });
      final ChimeService dataService = ChimeService(options: options, client: dataClient);
      expect(await dataService.listChimes(), isEmpty);

      final MockClient emptyClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'none': true}), 200);
      });
      final ChimeService emptyService = ChimeService(options: options, client: emptyClient);
      expect(await emptyService.listChimes(), isEmpty);
    });
  });

  group('ViewerService', () {
    test('listViewers, getViewer, updateViewer, and assignLiveview work', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.host == 'err' || request.url.path.contains('/err')) {
          return http.Response('Error', 500);
        }
        if (request.method == 'GET') {
          if (request.url.path.endsWith('/viewers')) {
            return http.Response(
              jsonEncode(<Map<String, Object>>[
                <String, Object>{
                  'id': 'viewer_1',
                  'name': 'Office Display',
                  'type': 'UFP-VIEWPORT',
                  'liveview': 'view_matrix_4',
                }
              ]),
              200,
            );
          }
          if (request.url.path.endsWith('/viewer_204')) {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'id': 'viewer_204',
                'name': 'Viewer 204',
                'type': 'UFP-VIEWPORT',
                'liveview': 'view_matrix_4',
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'viewer_1',
              'name': 'Office Display',
              'type': 'UFP-VIEWPORT',
              'liveview': 'view_matrix_4',
            }),
            200,
          );
        }
        if (request.method == 'PATCH') {
          if (request.url.path.endsWith('/viewer_204')) {
            return http.Response('', 204);
          }
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'viewer_1',
              'name': 'Office Display',
              'type': 'UFP-VIEWPORT',
              'liveview': body['liveview'] ?? 'view_matrix_4',
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final ViewerService service =
          ViewerService(options: options, client: mockClient);
      final List<ProtectViewer> viewers = await service.listViewers();
      expect(viewers, hasLength(1));
      expect(viewers[0].liveviewId, equals('view_matrix_4'));

      final ProtectViewer single = await service.getViewer('viewer_1');
      expect(single.id, equals('viewer_1'));

      final ProtectViewer updated =
          await service.assignLiveview('viewer_1', 'view_single_cam');
      expect(updated.liveviewId, equals('view_single_cam'));

      final ProtectViewer updated204 =
          await service.updateViewer('viewer_204', <String, dynamic>{});
      expect(updated204.id, equals('viewer_204'));

      // Error branches
      final ViewerService errService = ViewerService(
        options: const UnifiProtectOptions(apiKey: 'k', host: 'err'),
        client: mockClient,
      );
      expect(() => errService.listViewers(), throwsA(isA<HttpException>()));
      expect(() => errService.getViewer('err'), throwsA(isA<HttpException>()));
      expect(() => errService.updateViewer('err', <String, dynamic>{}), throwsA(isA<HttpException>()));
    });

    test('listViewers handles data envelope and empty map', () async {
      final MockClient dataClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'data': <dynamic>[]}), 200);
      });
      final ViewerService dataService = ViewerService(options: options, client: dataClient);
      expect(await dataService.listViewers(), isEmpty);

      final MockClient emptyClient = MockClient((http.Request request) async {
        return http.Response(jsonEncode(<String, dynamic>{'none': true}), 200);
      });
      final ViewerService emptyService = ViewerService(options: options, client: emptyClient);
      expect(await emptyService.listViewers(), isEmpty);
    });
  });
}
