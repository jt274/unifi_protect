import 'package:test/test.dart';
import 'package:unifi_protect/unifi_protect.dart';

void main() {
  group('ProtectDetectionType', () {
    test('displayName returns proper labels', () {
      expect(ProtectDetectionType.motion.displayName, equals('Motion'));
      expect(ProtectDetectionType.person.displayName, equals('Person'));
      expect(ProtectDetectionType.vehicle.displayName, equals('Vehicle'));
      expect(ProtectDetectionType.package.displayName, equals('Package'));
      expect(ProtectDetectionType.animal.displayName, equals('Animal'));
      expect(ProtectDetectionType.ring.displayName, equals('Doorbell Ring'));
      expect(ProtectDetectionType.smoke.displayName, equals('Smoke Alarm'));
      expect(ProtectDetectionType.cmonoxide.displayName, equals('Carbon Monoxide'));
      expect(ProtectDetectionType.siren.displayName, equals('Siren Alarm'));
    });

    test('fromString parses all known string variants and falls back to motion', () {
      expect(ProtectDetectionType.fromString('person'), equals(ProtectDetectionType.person));
      expect(ProtectDetectionType.fromString('smartdetectzone.person'), equals(ProtectDetectionType.person));
      expect(ProtectDetectionType.fromString('vehicle'), equals(ProtectDetectionType.vehicle));
      expect(ProtectDetectionType.fromString('car'), equals(ProtectDetectionType.vehicle));
      expect(ProtectDetectionType.fromString('smartdetectzone.vehicle'), equals(ProtectDetectionType.vehicle));
      expect(ProtectDetectionType.fromString('package'), equals(ProtectDetectionType.package));
      expect(ProtectDetectionType.fromString('smartdetectzone.package'), equals(ProtectDetectionType.package));
      expect(ProtectDetectionType.fromString('animal'), equals(ProtectDetectionType.animal));
      expect(ProtectDetectionType.fromString('pet'), equals(ProtectDetectionType.animal));
      expect(ProtectDetectionType.fromString('smartdetectzone.animal'), equals(ProtectDetectionType.animal));
      expect(ProtectDetectionType.fromString('ring'), equals(ProtectDetectionType.ring));
      expect(ProtectDetectionType.fromString('doorbell'), equals(ProtectDetectionType.ring));
      expect(ProtectDetectionType.fromString('smoke'), equals(ProtectDetectionType.smoke));
      expect(ProtectDetectionType.fromString('smokealarm'), equals(ProtectDetectionType.smoke));
      expect(ProtectDetectionType.fromString('co'), equals(ProtectDetectionType.cmonoxide));
      expect(ProtectDetectionType.fromString('cmonoxide'), equals(ProtectDetectionType.cmonoxide));
      expect(ProtectDetectionType.fromString('carbonmonoxide'), equals(ProtectDetectionType.cmonoxide));
      expect(ProtectDetectionType.fromString('siren'), equals(ProtectDetectionType.siren));
      expect(ProtectDetectionType.fromString('motion'), equals(ProtectDetectionType.motion));
      expect(ProtectDetectionType.fromString('unknown_type'), equals(ProtectDetectionType.motion));
    });
  });

  group('StreamQuality', () {
    test('displayName returns labels', () {
      expect(StreamQuality.low.displayName, contains('Low'));
      expect(StreamQuality.medium.displayName, contains('Medium'));
      expect(StreamQuality.high.displayName, contains('High'));
      expect(StreamQuality.package.displayName, contains('Package'));
    });

    test('fromString parses variants', () {
      expect(StreamQuality.fromString('high'), equals(StreamQuality.high));
      expect(StreamQuality.fromString('medium'), equals(StreamQuality.medium));
      expect(StreamQuality.fromString('med'), equals(StreamQuality.medium));
      expect(StreamQuality.fromString('package'), equals(StreamQuality.package));
      expect(StreamQuality.fromString('low'), equals(StreamQuality.low));
      expect(StreamQuality.fromString('unknown'), equals(StreamQuality.low));
    });
  });

  group('ProtectEvents', () {
    test('ProtectAlertEvent properties and isSmartAlert', () {
      final DateTime now = DateTime.now();
      final ProtectAlertEvent alertPerson = ProtectAlertEvent(
        cameraId: 'cam1',
        cameraName: 'Front',
        score: 95,
        detectionType: ProtectDetectionType.person,
        timestamp: now,
      );
      expect(alertPerson.isSmartAlert, isTrue);
      expect(alertPerson.score, equals(95));
      expect(alertPerson.cameraName, equals('Front'));
      expect(alertPerson.toString(), contains('cam1'));

      final ProtectAlertEvent alertVehicle = ProtectAlertEvent(
        cameraId: 'cam1',
        detectionType: ProtectDetectionType.vehicle,
        timestamp: now,
      );
      expect(alertVehicle.isSmartAlert, isTrue);

      final ProtectAlertEvent alertPackage = ProtectAlertEvent(
        cameraId: 'cam1',
        detectionType: ProtectDetectionType.package,
        timestamp: now,
      );
      expect(alertPackage.isSmartAlert, isTrue);

      final ProtectAlertEvent alertRing = ProtectAlertEvent(
        cameraId: 'cam1',
        detectionType: ProtectDetectionType.ring,
        timestamp: now,
      );
      expect(alertRing.isSmartAlert, isTrue);

      final ProtectAlertEvent alertMotion = ProtectAlertEvent(
        cameraId: 'cam1',
        detectionType: ProtectDetectionType.motion,
        timestamp: now,
      );
      expect(alertMotion.isSmartAlert, isFalse);
    });

    test('ProtectDeviceUpdateEvent toString', () {
      final ProtectDeviceUpdateEvent update = ProtectDeviceUpdateEvent(
        modelKey: 'camera',
        deviceId: 'cam123',
        action: 'online',
        timestamp: DateTime.now(),
      );
      expect(update.modelKey, equals('camera'));
      expect(update.deviceId, equals('cam123'));
      expect(update.action, equals('online'));
      expect(update.toString(), contains('cam123'));
    });
  });

  group('CameraChannel', () {
    test('fromJson, properties, aspectRatio, matchesQuality and toJson', () {
      final CameraChannel ch = CameraChannel.fromJson(<String, dynamic>{
        'id': '2',
        'name': 'Low Res',
        'isRtspEnabled': true,
        'rtspAlias': 'LowAlias123',
        'width': 640,
        'height': 360,
        'fps': 30,
        'bitrate': 500,
      });

      expect(ch.id, equals(2));
      expect(ch.name, equals('Low Res'));
      expect(ch.isRtspEnabled, isTrue);
      expect(ch.rtspAlias, equals('LowAlias123'));
      expect(ch.width, equals(640));
      expect(ch.height, equals(360));
      expect(ch.fps, equals(30));
      expect(ch.bitrate, equals(500));
      expect(ch.aspectRatio, closeTo(640 / 360, 0.001));

      // matchesQuality
      expect(ch.matchesQuality(StreamQuality.low), isTrue);
      expect(ch.matchesQuality(StreamQuality.medium), isFalse);
      expect(ch.matchesQuality(StreamQuality.high), isFalse);
      expect(ch.matchesQuality(StreamQuality.package), isFalse);

      final Map<String, dynamic> json = ch.toJson();
      expect(json['id'], equals(2));
      expect(json['rtspAlias'], equals('LowAlias123'));
      expect(json['width'], equals(640));
    });

    test('matchesQuality branches', () {
      // package channel
      const CameraChannel pkgCh = CameraChannel(id: 3, name: 'Package', isRtspEnabled: true);
      expect(pkgCh.matchesQuality(StreamQuality.package), isTrue);
      expect(pkgCh.matchesQuality(StreamQuality.low), isFalse);
      expect(pkgCh.matchesQuality(StreamQuality.medium), isFalse);
      expect(pkgCh.matchesQuality(StreamQuality.high), isFalse);

      // medium channel
      const CameraChannel medCh1 = CameraChannel(id: 1, name: 'Medium', isRtspEnabled: true);
      expect(medCh1.matchesQuality(StreamQuality.medium), isTrue);
      const CameraChannel medCh2 = CameraChannel(id: 9, name: '720p', isRtspEnabled: true, width: 1280);
      expect(medCh2.matchesQuality(StreamQuality.medium), isTrue);

      // high channel
      const CameraChannel highCh1 = CameraChannel(id: 0, name: 'High', isRtspEnabled: true);
      expect(highCh1.matchesQuality(StreamQuality.high), isTrue);
      const CameraChannel highCh2 = CameraChannel(id: 9, name: '4K', isRtspEnabled: true, width: 3840);
      expect(highCh2.matchesQuality(StreamQuality.high), isTrue);

      // null dimensions
      const CameraChannel noDimCh = CameraChannel(id: 9, name: 'Custom', isRtspEnabled: true);
      expect(noDimCh.aspectRatio, isNull);
    });
  });

  group('ProtectCamera', () {
    test('fromJson, getters and toJson', () {
      final ProtectCamera cam = ProtectCamera.fromJson(<String, dynamic>{
        'id': 'cam_pro_1',
        'name': 'Driveway Camera',
        'type': 'UVC AI Pro',
        'marketName': 'AI Pro',
        'modelKey': 'camera',
        'isDoorbell': false,
        'hasPackageCamera': false,
        'featureFlags': <String, dynamic>{
          'hasSmartDetect': true,
          'smartDetectTypes': <dynamic>['person', 'vehicle'],
          'hasChime': false,
          'hasPtz': true,
          'hasSpeaker': true,
          'hasMic': true,
        },
        'channels': <dynamic>[
          <String, dynamic>{
            'id': 0,
            'name': 'High',
            'isRtspEnabled': true,
            'rtspAlias': 'HighAlias',
            'width': 3840,
            'height': 2160,
          },
          <String, dynamic>{
            'id': 2,
            'name': 'Low',
            'isRtspEnabled': true,
            'rtspAlias': 'LowAlias',
            'width': 640,
            'height': 360,
          },
        ],
        'state': 'CONNECTED',
      });

      expect(cam.id, equals('cam_pro_1'));
      expect(cam.name, equals('Driveway Camera'));
      expect(cam.marketName, equals('AI Pro'));
      expect(cam.modelKey, equals('camera'));
      expect(cam.hasPtz, isTrue);
      expect(cam.hasSpeaker, isTrue);
      expect(cam.hasMicrophone, isTrue);
      expect(cam.isOnline, isTrue);
      expect(cam.supportedDetectionTypes, contains(ProtectDetectionType.motion));
      expect(cam.supportedDetectionTypes, contains(ProtectDetectionType.person));
      expect(cam.supportedDetectionTypes, contains(ProtectDetectionType.vehicle));
      expect(cam.getChannelForQuality(StreamQuality.high)?.rtspAlias, equals('HighAlias'));
      expect(cam.getChannelForQuality(StreamQuality.low)?.rtspAlias, equals('LowAlias'));
      expect(cam.packageChannel, isNull);

      final Map<String, dynamic> json = cam.toJson();
      expect(json['id'], equals('cam_pro_1'));
      expect(json['name'], equals('Driveway Camera'));
      expect(json['marketName'], equals('AI Pro'));
      expect(json['hasPtz'], isTrue);
    });

    test('smartDetectSettings objectTypes fallback and doorbell package detections', () {
      final ProtectCamera cam = ProtectCamera.fromJson(<String, dynamic>{
        'id': 'doorbell_pro',
        'name': 'Doorbell Pro',
        'type': 'UVC G4 Doorbell Pro',
        'smartDetectSettings': <String, dynamic>{
          'objectTypes': <dynamic>['person', 'animal'],
        },
        'hasPackageCamera': true,
        'isDoorbell': true,
      });

      expect(cam.supportedDetectionTypes, contains(ProtectDetectionType.person));
      expect(cam.supportedDetectionTypes, contains(ProtectDetectionType.animal));
      expect(cam.supportedDetectionTypes, contains(ProtectDetectionType.package));
      expect(cam.supportedDetectionTypes, contains(ProtectDetectionType.ring));
    });

    test('hasSmartDetect true with no smartDetectTypes defaults to person and vehicle', () {
      final ProtectCamera cam = ProtectCamera.fromJson(<String, dynamic>{
        'id': 'cam_smart',
        'name': 'Smart Cam',
        'featureFlags': <String, dynamic>{
          'hasSmartDetect': true,
        },
      });
      expect(cam.supportedDetectionTypes, contains(ProtectDetectionType.person));
      expect(cam.supportedDetectionTypes, contains(ProtectDetectionType.vehicle));
    });
  });

  group('ProtectLight', () {
    test('fromJson and toJson', () {
      final ProtectLight light = ProtectLight.fromJson(<String, dynamic>{
        'id': 'light_1',
        'name': 'Patio Light',
        'type': 'UP-FloodLight',
        'state': 'CONNECTED',
        'isLedOn': true,
        'lightDeviceSettings': <String, dynamic>{'ledLevel': 75},
      });

      expect(light.id, equals('light_1'));
      expect(light.name, equals('Patio Light'));
      expect(light.isLedOn, isTrue);
      expect(light.brightness, equals(75));
      expect(light.isOnline, isTrue);

      final Map<String, dynamic> json = light.toJson();
      expect(json['id'], equals('light_1'));
      expect(json['isLedOn'], isTrue);
      expect(json['brightness'], equals(75));
    });
  });

  group('ProtectSensor', () {
    test('fromJson and toJson', () {
      final ProtectSensor sensor = ProtectSensor.fromJson(<String, dynamic>{
        'id': 'sensor_1',
        'name': 'Door Sensor',
        'type': 'UP-Sense',
        'state': 'CONNECTED',
        'batteryStatus': <String, dynamic>{'percentage': 88},
        'isOpen': true,
        'isMotionDetected': false,
        'stats': <String, dynamic>{
          'temperature': <String, dynamic>{'value': 22.0},
          'humidity': <String, dynamic>{'value': 50.0},
          'light': <String, dynamic>{'value': 400.0},
        },
      });

      expect(sensor.id, equals('sensor_1'));
      expect(sensor.batteryPercentage, equals(88));
      expect(sensor.isOpen, isTrue);
      expect(sensor.isMotionDetected, isFalse);
      expect(sensor.temperature, equals(22.0));
      expect(sensor.humidity, equals(50.0));
      expect(sensor.lightLevel, equals(400.0));

      final Map<String, dynamic> json = sensor.toJson();
      expect(json['id'], equals('sensor_1'));
      expect(json['isOpen'], isTrue);
      expect(json['batteryPercentage'], equals(88));
    });
  });

  group('ProtectChime', () {
    test('fromJson and toJson', () {
      final ProtectChime chime = ProtectChime.fromJson(<String, dynamic>{
        'id': 'chime_1',
        'name': 'Living Room Chime',
        'type': 'UP-Chime',
        'state': 'CONNECTED',
        'volume': 70,
        'cameraIds': <dynamic>['cam_doorbell'],
      });

      expect(chime.id, equals('chime_1'));
      expect(chime.volume, equals(70));
      expect(chime.cameraIds, contains('cam_doorbell'));

      final Map<String, dynamic> json = chime.toJson();
      expect(json['id'], equals('chime_1'));
      expect(json['volume'], equals(70));
      expect(json['cameraIds'], contains('cam_doorbell'));

      final ProtectChime chimeWithMaps = ProtectChime.fromJson(<String, dynamic>{
        'id': 'chime_2',
        'name': 'Chime With Maps',
        'cameras': <dynamic>[
          <String, dynamic>{'id': 'cam_from_map'},
        ],
        'ringSettings': <String, dynamic>{
          'volume': 65,
        },
      });
      expect(chimeWithMaps.cameraIds, contains('cam_from_map'));
      expect(chimeWithMaps.volume, equals(65));
    });
  });

  group('ProtectViewer', () {
    test('fromJson and toJson', () {
      final ProtectViewer viewer = ProtectViewer.fromJson(<String, dynamic>{
        'id': 'viewer_1',
        'name': 'TV ViewPort',
        'type': 'UFP-VIEWPORT',
        'state': 'CONNECTED',
        'liveview': 'liveview_matrix_1',
      });

      expect(viewer.id, equals('viewer_1'));
      expect(viewer.name, equals('TV ViewPort'));
      expect(viewer.liveviewId, equals('liveview_matrix_1'));

      final Map<String, dynamic> json = viewer.toJson();
      expect(json['id'], equals('viewer_1'));
      expect(json['liveviewId'], equals('liveview_matrix_1'));
    });
  });

  group('ProtectLiveview', () {
    test('LiveviewSlot and ProtectLiveview fromJson and toJson', () {
      final ProtectLiveview liveview = ProtectLiveview.fromJson(<String, dynamic>{
        'id': 'view_1',
        'name': 'Overview 4-Grid',
        'isDefault': true,
        'slots': <dynamic>[
          <String, dynamic>{
            'cameras': <dynamic>['cam_1', 'cam_2'],
            'cycleMode': 'time',
            'cycleInterval': 10,
          },
        ],
      });

      expect(liveview.id, equals('view_1'));
      expect(liveview.name, equals('Overview 4-Grid'));
      expect(liveview.isDefault, isTrue);
      expect(liveview.slots, hasLength(1));
      expect(liveview.slots[0].cameraIds, contains('cam_1'));
      expect(liveview.slots[0].cycleInterval, equals(10));

      final Map<String, dynamic> json = liveview.toJson();
      expect(json['id'], equals('view_1'));
      expect(json['slots'], hasLength(1));

      final ProtectLiveview liveviewWithMaps = ProtectLiveview.fromJson(<String, dynamic>{
        'id': 'view_2',
        'name': 'View With Maps',
        'slots': <dynamic>[
          <String, dynamic>{
            'cameras': <dynamic>[
              <String, dynamic>{'id': 'cam_from_map_slot'},
            ],
          },
        ],
      });
      expect(liveviewWithMaps.slots[0].cameraIds, contains('cam_from_map_slot'));
    });
  });

  group('ProtectMetaInfo and ProtectNvr', () {
    test('ProtectMetaInfo fromJson and toJson', () {
      final ProtectMetaInfo meta = ProtectMetaInfo.fromJson(<String, dynamic>{
        'version': '2.11.21',
        'build': 'build123',
        'releaseChannel': 'release',
        'controllerVersion': '3.2.12',
      });

      expect(meta.version, equals('2.11.21'));
      expect(meta.build, equals('build123'));
      expect(meta.releaseChannel, equals('release'));
      expect(meta.controllerVersion, equals('3.2.12'));

      final Map<String, dynamic> json = meta.toJson();
      expect(json['version'], equals('2.11.21'));
      expect(json['build'], equals('build123'));
      expect(json['releaseChannel'], equals('release'));
      expect(json['controllerVersion'], equals('3.2.12'));
    });

    test('ProtectNvr fromJson and toJson', () {
      final ProtectNvr nvr = ProtectNvr.fromJson(<String, dynamic>{
        'id': 'nvr_main',
        'name': 'CloudKey Gen2+',
        'version': '3.2.12',
        'firmwareVersion': '3.2.12.1',
        'upSince': 1234567,
        'cameraCount': 4,
        'isRecording': true,
        'storageInfo': <String, dynamic>{
          'totalSize': 1000000000,
          'usedSize': 600000000,
          'availableSize': 400000000,
        },
      });

      expect(nvr.id, equals('nvr_main'));
      expect(nvr.name, equals('CloudKey Gen2+'));
      expect(nvr.version, equals('3.2.12'));
      expect(nvr.firmwareVersion, equals('3.2.12.1'));
      expect(nvr.uptimeMs, equals(1234567));
      expect(nvr.storageTotalBytes, equals(1000000000));
      expect(nvr.storageUsedBytes, equals(600000000));
      expect(nvr.storageAvailableBytes, equals(400000000));
      expect(nvr.isRecording, isTrue);
      expect(nvr.cameraCount, equals(4));

      final Map<String, dynamic> json = nvr.toJson();
      expect(json['id'], equals('nvr_main'));
      expect(json['storageTotalBytes'], equals(1000000000));
      expect(json['storageUsedBytes'], equals(600000000));
      expect(json['storageAvailableBytes'], equals(400000000));
      expect(json['uptimeMs'], equals(1234567));
    });
  });
}
