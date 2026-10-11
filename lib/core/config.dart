import 'package:flutter/foundation.dart';

const _configuredApi = String.fromEnvironment('API_BASE_URL');
String get apiBaseUrl =>
    _configuredApi.isNotEmpty ? _configuredApi : (kIsWeb ? '/api' : '');
