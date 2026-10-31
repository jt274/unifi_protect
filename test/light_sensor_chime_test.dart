import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:unifi_protect/unifi_protect.dart';

void main() {
  const UnifiProtectOptions options = UnifiProtectOptions(
    apiKey: 'test-key',
  );

  group('LightService', () {
    test('listLights and controls work', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.method == 'GET') {
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
        } else if (request.method == 'PATCH') {
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

      final ProtectLight toggled = await service.setLed('light_1', false);
      expect(toggled.isLedOn, isFalse);

      final ProtectLight dimmed = await service.setBrightness('light_1', 40);
      expect(dimmed.brightness, equals(40));
    });
  });

  group('SensorService', () {
    test('listSensors and getSensor read telemetry data', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
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
      });

      final SensorService service =
          SensorService(options: options, client: mockClient);
      final ProtectSensor sensor = await service.getSensor('sensor_entry');

      expect(sensor.id, equals('sensor_entry'));
      expect(sensor.isOpen, isTrue);
      expect(sensor.batteryPercentage, equals(92));
      expect(sensor.temperature, equals(21.5));
      expect(sensor.humidity, equals(48.0));
      expect(sensor.lightLevel, equals(350.0));
    });
  });

  group('ChimeService', () {
    test('listChimes, setVolume, and playBuzzer work', () async {
      bool buzzerPlayed = false;
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.url.path.endsWith('/play-buzzer')) {
          buzzerPlayed = true;
          return http.Response('', 200);
        }
        if (request.method == 'GET') {
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
        if (request.method == 'PATCH') {
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

      final ProtectChime updated = await service.setVolume('chime_hallway', 95);
      expect(updated.volume, equals(95));

      await service.playBuzzer('chime_hallway');
      expect(buzzerPlayed, isTrue);
    });
  });

  group('ViewerService', () {
    test('listViewers and assignLiveview work', () async {
      final MockClient mockClient = MockClient((http.Request request) async {
        if (request.method == 'PATCH') {
          final Map<String, dynamic> body =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'viewport_1',
              'name': 'Office TV',
              'type': 'UVP-ViewPort',
              'liveview': body['liveview'],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode(<Map<String, String>>[
            <String, String>{
              'id': 'viewport_1',
              'name': 'Office TV',
              'type': 'UVP-ViewPort',
              'liveview': 'grid_layout_1',
            }
          ]),
          200,
        );
      });

      final ViewerService service =
          ViewerService(options: options, client: mockClient);
      final List<ProtectViewer> viewers = await service.listViewers();
      expect(viewers, hasLength(1));
      expect(viewers[0].liveviewId, equals('grid_layout_1'));

      final ProtectViewer reassigned =
          await service.assignLiveview('viewport_1', 'grid_layout_2');
      expect(reassigned.liveviewId, equals('grid_layout_2'));
    });
  });
}
