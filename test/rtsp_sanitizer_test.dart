import 'package:test/test.dart';
import 'package:unifi_protect/unifi_protect.dart';

void main() {
  group('RtspSanitizer', () {
    test('instance is accessible', () {
      expect(RtspSanitizer.instance, isNotNull);
    });

    test(
        'sanitize converts UniFi RTSPS port 7441 URL to low-latency RTSP port 7447',
        () {
      const String raw = 'rtsps://192.168.1.1:7441/AbCdEfGhIjKlMnOp?enableSrtp';
      final String sanitized = RtspSanitizer.sanitize(raw);
      expect(sanitized, equals('rtsp://192.168.1.1:7447/AbCdEfGhIjKlMnOp'));

      expect(RtspSanitizer.sanitize(''), isEmpty);
      expect(RtspSanitizer.sanitize('http://example.com'),
          equals('http://example.com'));
      expect(RtspSanitizer.sanitize('rtsp://ha.local:8554/cam'),
          equals('rtsp://ha.local:8554/cam'));
      expect(RtspSanitizer.sanitize('invalid_uri'), equals('invalid_uri'));
    });

    test('cleanStreamUrl strips ?enableSrtp parameter and handles edge cases',
        () {
      const String raw = 'rtsps://10.0.0.1:7441/StreamToken?enableSrtp&other=1';
      final String cleaned = RtspSanitizer.cleanStreamUrl(raw);
      expect(cleaned, equals('rtsps://10.0.0.1:7441/StreamToken?other=1'));

      expect(RtspSanitizer.cleanStreamUrl(''), isEmpty);
      expect(RtspSanitizer.cleanStreamUrl('rtsp://host/path'),
          equals('rtsp://host/path'));
    });

    test('toRtsps converts RTSP 7447 to RTSPS 7441 and handles edge cases', () {
      const String raw = 'rtsp://192.168.1.1:7447/MyToken';
      final String rtsps = RtspSanitizer.toRtsps(raw);
      expect(rtsps, equals('rtsps://192.168.1.1:7441/MyToken'));

      expect(RtspSanitizer.toRtsps(''), isEmpty);
      expect(RtspSanitizer.toRtsps('no_host'), equals('no_host'));
    });

    test(
        'toRtspsWithSrtp appends enableSrtp flag with existing or new query parameters',
        () {
      const String raw = 'rtsp://192.168.1.1:7447/MyToken';
      final String rtspsSrtp = RtspSanitizer.toRtspsWithSrtp(raw);
      expect(rtspsSrtp, equals('rtsps://192.168.1.1:7441/MyToken?enableSrtp'));

      const String rawWithQuery = 'rtsp://192.168.1.1:7447/MyToken?channel=0';
      final String rtspsWithQuery = RtspSanitizer.toRtspsWithSrtp(rawWithQuery);
      expect(rtspsWithQuery,
          equals('rtsps://192.168.1.1:7441/MyToken?channel=0&enableSrtp'));

      expect(RtspSanitizer.toRtspsWithSrtp(''), isEmpty);
      expect(RtspSanitizer.toRtspsWithSrtp('no_host'), equals('no_host'));
    });

    test(
        'isCameraIdPlaceholderUrl detects 24-hex camera IDs vs 16-char tokens and handles edge cases',
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

      // Edge cases
      expect(RtspSanitizer.isCameraIdPlaceholderUrl(''), isFalse);
      expect(RtspSanitizer.isCameraIdPlaceholderUrl('rtsp://192.168.1.1:7447'),
          isFalse);
      expect(RtspSanitizer.isCameraIdPlaceholderUrl('rtsp://192.168.1.1:7447/'),
          isFalse);
    });

    test(
        'getCandidateUrls returns ordered fallback stream URLs for rtsp and rtsps',
        () {
      const String rtspRaw = 'rtsp://192.168.1.1:7447/StreamToken';
      final List<String> rtspCandidates =
          RtspSanitizer.getCandidateUrls(rtspRaw);

      expect(rtspCandidates, hasLength(3));
      expect(rtspCandidates[0], equals('rtsp://192.168.1.1:7447/StreamToken'));
      expect(rtspCandidates[1], equals('rtsps://192.168.1.1:7441/StreamToken'));
      expect(rtspCandidates[2],
          equals('rtsps://192.168.1.1:7441/StreamToken?enableSrtp'));

      const String rtspsRaw = 'rtsps://192.168.1.1:7441/StreamToken';
      final List<String> rtspsCandidates =
          RtspSanitizer.getCandidateUrls(rtspsRaw);

      expect(rtspsCandidates, hasLength(3));
      expect(
          rtspsCandidates[0], equals('rtsps://192.168.1.1:7441/StreamToken'));
      expect(rtspsCandidates[1], equals('rtsp://192.168.1.1:7447/StreamToken'));
      expect(rtspsCandidates[2],
          equals('rtsps://192.168.1.1:7441/StreamToken?enableSrtp'));

      // Non-unifi and empty edge cases
      expect(RtspSanitizer.getCandidateUrls(''), isEmpty);
      expect(RtspSanitizer.getCandidateUrls('no_host'),
          equals(<String>['no_host']));
      expect(
        RtspSanitizer.getCandidateUrls('rtsp://ha.local:8554/cam'),
        equals(<String>['rtsp://ha.local:8554/cam']),
      );
    });

    test(
        'getAlternateUrl swaps port and scheme between rtsp and rtsps and handles non-swappable URLs',
        () {
      const String rtsp = 'rtsp://192.168.1.1:7447/StreamToken';
      final String? alt1 = RtspSanitizer.getAlternateUrl(rtsp);
      expect(alt1, equals('rtsps://192.168.1.1:7441/StreamToken'));

      const String rtsps = 'rtsps://192.168.1.1:7441/StreamToken';
      final String? alt2 = RtspSanitizer.getAlternateUrl(rtsps);
      expect(alt2, equals('rtsp://192.168.1.1:7447/StreamToken'));

      expect(RtspSanitizer.getAlternateUrl(''), isNull);
      expect(RtspSanitizer.getAlternateUrl('no_host'), isNull);
      expect(RtspSanitizer.getAlternateUrl('rtsp://ha.local:8554/cam'), isNull);
    });
  });
}
