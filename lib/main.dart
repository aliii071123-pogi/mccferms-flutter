import 'package:flutter/material.dart';

import 'api_client.dart';
import 'ferms_app.dart';
import 'ferms_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  final uri = Uri.tryParse(apiBaseUrl);
  if (uri == null ||
      !const {'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.host == 'your-laravel-api.example.com') {
    runApp(const _ConfigurationError());
    return;
  }

  final api = FermsApiClient(baseUrl: apiBaseUrl);
  runApp(FermsApp(api: api, repository: FermsRepository(api)));
}

class _ConfigurationError extends StatelessWidget {
  const _ConfigurationError();

  @override
  Widget build(BuildContext context) => const MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Set API_BASE_URL in config/app.json to your Laravel API host, then rebuild the app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
