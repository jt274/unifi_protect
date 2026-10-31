import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'unifi_protect_options.dart';

/// Creates an [http.Client] that respects [UnifiProtectOptions.allowSelfSignedCertificates].
http.Client createHttpClient(UnifiProtectOptions options) {
  if (!options.allowSelfSignedCertificates || options.isCloudMode) {
    return http.Client();
  }

  final HttpClient innerIoClient = HttpClient()
    ..badCertificateCallback = (X509Certificate cert, String host, int port) {
      final String normalizedHost = host.toLowerCase().trim();
      final String targetHost = options.cleanHost.toLowerCase().trim();
      return normalizedHost == targetHost;
    };

  return IOClient(innerIoClient);
}
