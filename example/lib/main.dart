import 'package:flutter/material.dart';
import 'package:keycloak_auth/keycloak_auth.dart';

final keycloakConfig = KeycloakConfig(
  bundleIdentifier: 'com.example.example',
  clientId: 'neif-app',
  frontendUrl: 'https://iam.elkromer.dev',
  realm: 'neif-global',
  clientSecret: 'xxtUhI4wOVPPgMVE5GMVFw9YjBWxdZvv',
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
    home: StreamBuilder<KeycloakAuthState>(
      initialData: keycloakAuth.initialStreamData,
      stream: keycloakAuth.authenticationStream,
      builder: (context, snapshot) {
        debugPrint(snapshot.toString());
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.data == KeycloakAuthState.pending) {
          return const LoadingScreen();
        } else if (snapshot.data == KeycloakAuthState.authenticated) {
          return const HomeScreen();
        }
        return const LoginScreen();
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
