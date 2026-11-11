import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'ferms_models.dart';
import 'ferms_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required this.api,
    required this.repository,
    required this.baseUrl,
    FlutterSecureStorage? storage,
    AppLinks? appLinks,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _appLinks = appLinks ?? AppLinks();

  static const _tokenKey = 'ferms_api_token';

  final FermsApiClient api;
  final FermsRepository repository;
  final String baseUrl;
  final FlutterSecureStorage _storage;
  final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  FermsUser? user;
  bool loading = true;
  bool signingIn = false;
  String? error;
  String? _handledCode;

  bool get signedIn => user != null;

  Future<void> initialize() async {
    if (!kIsWeb) {
      _linkSubscription = _appLinks.uriLinkStream.listen(
        _handleCallback,
        onError: (Object _) =>
            _setError('Could not read the sign-in callback.'),
      );
      try {
        final initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) await _handleCallback(initialUri);
      } catch (_) {
        _setError('Could not read the sign-in callback.');
      }
    } else if (Uri.base.queryParameters.containsKey('code')) {
      await _handleCallback(Uri.base);
    }

    if (user == null) {
      final token = await _storage.read(key: _tokenKey);
      if (token != null && token.isNotEmpty) {
        api.token = token;
        try {
          user = await repository.me();
        } on ApiException catch (exception) {
          if (exception.statusCode == 401) await _clearSession();
          error = exception.message;
        } catch (_) {
          error = 'Could not reach MCC FERMS. Check your connection and retry.';
        }
      }
    }
    loading = false;
    notifyListeners();
  }

  Future<void> beginSignIn() async {
    error = null;
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    if (kIsWeb &&
        _isLoopbackHost(base.host) &&
        !_isLoopbackHost(Uri.base.host)) {
      error =
          'The API is set to localhost, which this remote browser cannot reach. '
          'Set API_BASE_URL to the running Laravel API’s forwarded or deployed URL, then rebuild.';
      notifyListeners();
      return;
    }

    signingIn = true;
    notifyListeners();
    final signInUri = base
        .resolve('auth/microsoft')
        .replace(queryParameters: {'client': kIsWeb ? 'web' : 'mobile'});
    try {
      final launched = await launchUrl(
        signInUri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
      if (!launched) error = 'Could not open Microsoft sign-in.';
    } catch (_) {
      error = 'Could not open Microsoft sign-in.';
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  bool _isLoopbackHost(String host) =>
      host == 'localhost' || host == '127.0.0.1' || host == '::1';

  Future<void> signOut() async {
    try {
      await api.delete('/api/v1/auth/session');
    } catch (_) {
      // Local sign-out must still work when the API is unavailable.
    }
    await _clearSession();
    error = null;
    notifyListeners();
  }

  void setUser(FermsUser value) {
    user = value;
    notifyListeners();
  }

  Future<void> _handleCallback(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty || code == _handledCode) return;
    _handledCode = code;
    signingIn = true;
    error = null;
    notifyListeners();
    try {
      final response = asJsonMap(
        unwrapData(
          await api.post('/api/v1/auth/exchange', body: {'code': code}),
        ),
      );
      final token = stringValue(response['token']);
      if (token.isEmpty) throw const FormatException('Missing token');
      api.token = token;
      await _storage.write(key: _tokenKey, value: token);
      final userJson = asJsonMap(response['user']);
      user = userJson.isEmpty
          ? await repository.me()
          : FermsUser.fromJson(userJson);
    } on ApiException catch (exception) {
      error = exception.message;
    } catch (_) {
      error = 'Sign-in could not be completed. Please try again.';
    } finally {
      signingIn = false;
      notifyListeners();
    }
  }

  Future<void> _clearSession() async {
    user = null;
    api.token = null;
    await _storage.delete(key: _tokenKey);
  }

  void _setError(String message) {
    error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }
}
