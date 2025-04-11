
# keycloak_auth

A Flutter package for easy Keycloak authentication, based on the OAuth 2.0 Authorization Code Flow.

This package is a fork of [`keycloak_wrapper`](https://pub.dev/packages/keycloak_wrapper) and leverages [`flutter_appauth`](https://pub.dev/packages/flutter_appauth) to implement the OAuth 2.0 Authorization Code Flow as a client. This enables secure and standards-compliant authentication against Keycloak servers.

**Important:** The iOS demo is currently under development. Please note the Android configuration instructions below.

## Features

*   **Easy Integration:** Provides a simple API for integrating Keycloak authentication into Flutter apps.
*   **OAuth 2.0 Authorization Code Flow:**  Uses the secure and standards-compliant Authorization Code Flow for authentication.
*   **Based on `flutter_appauth`:** Benefits from the mature implementation of `flutter_appauth`.
*   **Customizable:**  Allows configuration of various Keycloak parameters (e.g., Client ID, Redirect URI, Scope).
*   **Refresh Tokens:**  Supports the use of Refresh Tokens for a seamless user experience (sessions remain active even after the Access Token expires).

## Installation

Add `keycloak_auth` as a dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  keycloak_auth: ^<current_version>  # Replace <current_version> with the latest version from Pub.dev
```

Then, run `flutter pub get` to install the dependencies.

## Usage

Here's a simple example of how to use `keycloak_auth` in your Flutter app:

```dart
import 'package:flutter/material.dart';
import 'package:keycloak_auth/keycloak_auth.dart';

final keycloakConfig = KeycloakConfig(
  bundleIdentifier: 'com.example.example',
  clientId: '<clientId>',
  frontendUrl: '<frontendUrl>',
  realm: '<realm>',
  clientSecret: '<clientSecret>',
);
final keycloakAuth = KeycloakAuth(config: keycloakConfig);
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the plugin at the start of your app.
  keycloakAuth.initialize();
  // Listen to the errors caught by the plugin.
  keycloakAuth.onError = (message, _, __) {
    // Display the error message inside a snackbar.
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    scaffoldMessengerKey: scaffoldMessengerKey,
    // Listen to the user authentication stream.
    home: StreamBuilder<bool>(
      initialData: false,
      stream: keycloakAuth.authenticationStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        } else if (snapshot.data!) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    ),
  );
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator.adaptive()));
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // Login using the given configuration.
  Future<void> login() async {
    // Check if user has successfully logged in.
    final isLoggedIn = await keycloakAuth.login();

    if (isLoggedIn) debugPrint('User has successfully logged in.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(onPressed: login, child: const Text('Login')),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Logout from the current realm.
  Future<void> logout() async {
    // Check if user has successfully logged out.
    final isLoggedOut = await keycloakAuth.logout();

    if (isLoggedOut) debugPrint('User has successfully logged out.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FutureBuilder(
            // Retrieve the user information.
            future: keycloakAuth.getUserInfo(),
            builder: (context, snapshot) {
              final userInfo = snapshot.data ?? {};

              // Display the retrieved user information.
              return Column(
                children: [
                  ...userInfo.entries.map(
                    (entry) => Text('${entry.key}: ${entry.value}'),
                  ),
                  if (userInfo.isNotEmpty) const SizedBox(height: 20),
                ],
              );
            },
          ),
          FilledButton(onPressed: logout, child: const Text('Logout')),
        ],
      ),
    ),
  );
}
```

**Note:** Replace `YOUR_KEYCLOAK_URL`, `YOUR_REALM`, `YOUR_CLIENT_ID`, and `com.example.example://oauth2redirect` with your actual Keycloak configuration values.

## Android Configuration

For `keycloak_auth` to work correctly on Android, the following adjustments are required:

1.  **`build.gradle.kts` Adjustment:**

    In your `android/app/build.gradle.kts` file, add the following line to the `defaultConfig` section:

    ```kotlin
    defaultConfig {
        // ... other configurations ...
        manifestPlaceholders["appAuthRedirectScheme"] = "com.example.example"
    }
    ```

    **Important:** Replace `"com.example.example"` with the scheme of your Redirect URI. This must match the Redirect URI configured in Keycloak for your client (before the `://oauth2redirect` part).

2.  **`AndroidManifest.xml` Adjustment:**

    Remove the `android:taskAffinity=""` attribute from the `MainActivity` in your `android/app/src/main/AndroidManifest.xml` file.

    ```xml
    <activity
        android:name=".MainActivity"
        <!-- Remove this line: android:taskAffinity="" -->
        ...>
        </activity>
    ```

## iOS Configuration (Coming Soon!)

The iOS demo is still under development. Instructions for iOS configuration will be added soon.

## Parameters

The `KeycloakAuth` constructor accepts the following parameters:

*   `url`: The URL of your Keycloak server.
*   `realm`: The name of your Keycloak realm.
*   `clientId`: The Client ID of your application in Keycloak.
*   `redirectUri`: The Redirect URI configured in Keycloak for your client.
*   `discoveryUrl`: (Optional) The Discovery URL for Keycloak (if different from the standard). If not specified, it will be automatically generated from `url` and `realm`.
*   `scopes`: (Optional) A list of scopes to request for authentication. Defaults to `openid`.
*   `clientSecret`: (Optional) The Client Secret, if your client in Keycloak is configured to require one.
*   `port`: (Optional) The port for the AppAuth redirect listener. Defaults to 10000.
*   `serviceConfiguration`: (Optional) A ServiceConfiguration instance allowing to set a custom authorization and token endpoint URL.
*   `preferEphemeralSession`: (Optional) Indicates if an ephemeral session should be prefered.

## Error Handling

The package throws exceptions in various situations, such as network problems, invalid configuration, or failed authentication. It's important to catch these exceptions and handle them appropriately.

## Contributing

Contributions are welcome! Please create a pull request with your changes.

## License

This package is licensed under the [MIT License](LICENSE).

## Acknowledgments

Special thanks to the developers of [`keycloak_wrapper`](https://pub.dev/packages/keycloak_wrapper) and [`flutter_appauth`](https://pub.dev/packages/flutter_appauth) for their excellent work!