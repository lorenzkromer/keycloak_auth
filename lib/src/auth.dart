part of '../keycloak_auth.dart';

/// A wrapper around the Keycloak authentication service.
///
/// Provides functionalities for user authentication, token management, and resource authorization.
class KeycloakAuth {
  KeycloakAuthState get initialStreamData => KeycloakAuthState.unauthenticated;

  static KeycloakAuth? _instance;

  bool _isInitialized = false;

  final KeycloakConfig _keycloakConfig;

  late final _streamController =
      StreamController<KeycloakAuthState>.broadcast();

  /// Called whenever an error gets caught.
  ///
  /// By default, all errors will be printed into the console.
  void Function(String message, Object error, StackTrace stackTrace) onError =
      (message, error, stackTrace) => developer.log(
        message,
        name: 'keycloak_auth',
        error: error,
        stackTrace: stackTrace,
      );

  /// The details from making a successful token exchange.
  TokenResponse? tokenResponse;

  factory KeycloakAuth({required KeycloakConfig config}) =>
      _instance ??= KeycloakAuth._(config);

  KeycloakAuth._(this._keycloakConfig);

  /// Returns the access token string.
  ///
  /// To get the payload, do `JWT.decode(keycloakAuth.accessToken).payload`.
  String? get accessToken => tokenResponse?.accessToken;

  /// The stream of the user authentication state.
  ///
  /// Returns true if the user is currently logged in.
  Stream<KeycloakAuthState> get authenticationStream =>
      _streamController.stream;

  /// Returns the id token string.
  ///
  /// To get the payload, do `JWT.decode(keycloakAuth.idToken).payload`.
  String? get idToken => tokenResponse?.idToken;

  /// Whether this package has been initialized.
  bool get isInitialized => _isInitialized;

  /// Returns the refresh token string.
  ///
  /// To get the payload, do `JWT.decode(keycloakAuth.refreshToken).payload`.
  String? get refreshToken => tokenResponse?.refreshToken;

  /// Retrieves the current user information.
  Future<Map<String, dynamic>?> getUserInfo() async {
    _assertInitialization();
    try {
      final url = Uri.parse(_keycloakConfig.userInfoEndpoint);
      final client = HttpClient();
      final request = await client.getUrl(url)
        ..headers.add(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      client.close();
      return jsonDecode(responseBody) as Map<String, dynamic>?;
    } catch (e, s) {
      onError('Failed to fetch user info.', e, s);
      return null;
    }
  }

  /// Initializes the user authentication state and refreshes the token.
  Future<void> initialize() async {
    const key = 'keycloak:hasRunBefore';
    final prefs = SharedPreferencesAsync();
    final hasRunBefore = await prefs.getBool(key) ?? false;

    if (!hasRunBefore) {
      SECURE_STORAGE.deleteAll();
      prefs.setBool(key, true);
    }

    try {
      _isInitialized = true;
      await updateToken();
    } catch (e, s) {
      _isInitialized = false;
      _streamController.add(KeycloakAuthState.unauthenticated);
      onError('Failed to initialize plugin.', e, s);
    }
  }

  /// Logs the user in.
  ///
  /// Returns true if login is successful.
  Future<bool> login() async {
    _assertInitialization();
    try {
      _streamController.add(KeycloakAuthState.pending);

      tokenResponse = await APP_AUTH.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _keycloakConfig.clientId,
          _keycloakConfig.redirectUri,
          issuer: _keycloakConfig.issuer,
          scopes: _keycloakConfig.scopes,
          promptValues: ['login'],
          allowInsecureConnections: _keycloakConfig.allowInsecureConnections,
          clientSecret: _keycloakConfig.clientSecret,
        ),
      );

      if (tokenResponse.isValid) {
        if (refreshToken != null) {
          await SECURE_STORAGE.write(
            key: REFRESH_TOKEN_KEY,
            value: refreshToken,
          );
        }
      } else {
        developer.log('Invalid token response.', name: 'keycloak_auth');
      }

      _streamController.add(
        tokenResponse.isValid
            ? KeycloakAuthState.authenticated
            : KeycloakAuthState.unauthenticated,
      );
      return tokenResponse.isValid;
    } catch (e, s) {
      onError('Failed to login.', e, s);
      _streamController.add(KeycloakAuthState.unauthenticated);
      return false;
    }
  }

  /// Logs the user out.
  ///
  /// Returns true if logout is successful.
  Future<bool> logout() async {
    _assertInitialization();
    try {
      _streamController.add(KeycloakAuthState.pending);

      final request = EndSessionRequest(
        idTokenHint: idToken,
        issuer: _keycloakConfig.issuer,
        postLogoutRedirectUrl: _keycloakConfig.redirectUri,
        allowInsecureConnections: _keycloakConfig.allowInsecureConnections,
      );

      await APP_AUTH.endSession(request);
      await SECURE_STORAGE.deleteAll();
      tokenResponse = null;
      _streamController.add(KeycloakAuthState.unauthenticated);
      return true;
    } catch (e, s) {
      onError('Failed to logout.', e, s);
      _streamController.add(KeycloakAuthState.authenticated);
      return false;
    }
  }

  /// Requests a new access token if it expires within the given duration.
  Future<void> updateToken([Duration? duration]) async {
    _streamController.add(KeycloakAuthState.pending);

    final securedRefreshToken = await SECURE_STORAGE.read(
      key: REFRESH_TOKEN_KEY,
    );

    if (securedRefreshToken == null) {
      developer.log('No refresh token found.', name: 'keycloak_auth');
      _streamController.add(KeycloakAuthState.unauthenticated);
    } else if (JWT
        .decode(securedRefreshToken)
        .willExpired(duration ?? Duration.zero)) {
      developer.log('Expired refresh token', name: 'keycloak_auth');
      _streamController.add(KeycloakAuthState.unauthenticated);
    } else {
      final isConnected = await hasNetwork();

      if (isConnected) {
        tokenResponse = await APP_AUTH.token(
          TokenRequest(
            _keycloakConfig.clientId,
            _keycloakConfig.redirectUri,
            issuer: _keycloakConfig.issuer,
            scopes: _keycloakConfig.scopes,
            refreshToken: securedRefreshToken,
            allowInsecureConnections: _keycloakConfig.allowInsecureConnections,
            clientSecret: _keycloakConfig.clientSecret,
          ),
        );

        if (tokenResponse.isValid) {
          if (refreshToken != null) {
            await SECURE_STORAGE.write(
              key: REFRESH_TOKEN_KEY,
              value: refreshToken,
            );
          }
        } else {
          developer.log('Invalid token response.', name: 'keycloak_auth');
        }

        _streamController.add(
          tokenResponse.isValid
              ? KeycloakAuthState.authenticated
              : KeycloakAuthState.unauthenticated,
        );
      } else {
        developer.log('No internet connection.', name: 'keycloak_auth');
        _streamController.add(KeycloakAuthState.unavailable);
      }
    }
  }

  void _assertInitialization() {
    assert(
      _isInitialized,
      'Make sure the package has been initialized prior to calling this method.',
    );
  }
}
