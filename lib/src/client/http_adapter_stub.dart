import 'package:http/http.dart' as http;

import 'unifi_protect_options.dart';

/// Creates an [http.Client] on platforms without dart:io (such as Web).
http.Client createHttpClient(UnifiProtectOptions options) {
  return http.Client();
}
