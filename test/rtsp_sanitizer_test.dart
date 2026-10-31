import 'package:test/test.dart';
import 'package:unifi_protect/unifi_protect.dart';

void main() {
  group('RtspSanitizer', () {
    test(
        'sanitize converts UniFi RTSPS port 7441 URL to low-latency RTSP port 7447',
        () {
      const String raw = 'rtsps://192.168.1.1:7441/AbCdEfGhIjKlMnOp?enableSrtp';
      final String sanitized = RtspSanitizer.sanitize(raw);
      expect(sanitized, equals('rtsp://192.168.1.1:7447/AbCdEfGhIjKlMnOp'));
    });

    test('cleanStreamUrl strips ?enableSrtp parameter', () {
      const String raw = 'rtsps://10.0.0.1:7441/StreamToken?enableSrtp&other=1';
      final String cleaned = RtspSanitizer.cleanStreamUrl(raw);
      expect(cleaned, equals('rtsps://10.0.0.1:7441/StreamToken?other=1'));
    });

    test('toRtsps converts RTSP 7447 to RTSPS 7441', () {
      const String raw = 'rtsp://192.168.1.1:7447/MyToken';
      final String rtsps = RtspSanitizer.toRtsps(raw);
      expect(rtsps, equals('rtsps://192.168.1.1:7441/MyToken'));
    });

    test('toRtspsWithSrtp appends enableSrtp flag', () {
      const String raw = 'rtsp://192.168.1.1:7447/MyToken';
      final String rtspsSrtp = RtspSanitizer.toRtspsWithSrtp(raw);
      expect(rtspsSrtp, equals('rtsps://192.168.1.1:7441/MyToken?enableSrtp'));
    });

    test('isCameraIdPlaceholderUrl detects 24-hex camera IDs vs 16-char tokens',
        () {
      // 24-hex character MongoDB ObjectId placeholder
      expect(
        RtspSanitizer.isCameraIdPlaceholderUrl(
            'rtsp://192.168.1.1:7447/68d5cf8800b0a003e401a7ec'),
        isTrue,
      );

      // Explicit matching camera ID
      expect(
        RtspSanitizer.isCameraIdPlaceholderUrl(
          'rtsp://192.168.1.1:7447/front_door',
          cameraId: 'front_door',
        ),
        isTrue,
      );

      // Real 16-character alphanumeric RTSP stream token
      expect(
        RtspSanitizer.isCameraIdPlaceholderUrl(
            'rtsp://192.168.1.1:7447/AbCdEfGhIjKlMnOp'),
        isFalse,
      );
    });

    test('getCandidateUrls returns ordered fallback stream URLs', () {
      const String raw = 'rtsp://192.168.1.1:7447/StreamToken';
      final List<String> candidates = RtspSanitizer.getCandidateUrls(raw);

      expect(candidates, hasLength(3));
      expect(candidates[0], equals('rtsp://192.168.1.1:7447/StreamToken'));
      expect(candidates[1], equals('rtsps://192.168.1.1:7441/StreamToken'));
      expect(candidates[2],
          equals('rtsps://192.168.1.1:7441/StreamToken?enableSrtp'));
    });

    test('getAlternateUrl swaps port and scheme between rtsp and rtsps', () {
      const String rtsp = 'rtsp://192.168.1.1:7447/StreamToken';
      final String? alt1 = RtspSanitizer.getAlternateUrl(rtsp);
      expect(alt1, equals('rtsps://192.168.1.1:7441/StreamToken'));

      const String rtsps = 'rtsps://192.168.1.1:7441/StreamToken';
      final String? alt2 = RtspSanitizer.getAlternateUrl(rtsps);
      expect(alt2, equals('rtsp://192.168.1.1:7447/StreamToken'));
    });
  });
}
