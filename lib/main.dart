import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/network/api_client.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/direct_request_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/request_provider.dart';
import 'providers/user_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/settings_provider.dart';
import 'views/auth/login_screen.dart';
import 'views/home/home_screen.dart';
import 'views/splash/splash_screen.dart';
import 'views/onboarding/onboarding_screen.dart';
import 'views/notification/notifications_screen.dart';
import 'views/request/request_details_screen.dart';

/// Global navigator key so the Dio auth interceptor can force a redirect
/// back to the login screen on a 401 without needing a BuildContext of
/// its own — this keeps the interceptor a pure networking class with no
/// UI knowledge, per the app's clean-architecture rule that services never
/// touch widgets.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PushNotificationService.initialize(
    onNotificationOpened: (data) {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      final link = data['link']?.toString() ?? '';
      final requestId = data['relatedRequestId']?.toString() ??
          Uri.tryParse(link)?.queryParameters['highlight'];
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => requestId != null && requestId.isNotEmpty
              ? RequestDetailsScreen(requestId: requestId)
              : const NotificationsScreen(),
        ),
      );
    },
  );

  // Wire the Dio client's 401 handler to clear the AuthProvider's session
  // and pop back to the login screen, from anywhere in the app.
  ApiClient.instance.configure(
    onUnauthorized: () async {
      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..restoreSession()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => RequestProvider()),
        ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, notifications) {
            final provider = notifications ?? NotificationProvider();
            provider.setUserId(auth.currentUser?.id);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => DirectRequestProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..load()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()..load()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'BloodLink',
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          locale: Locale(settings.languageCode),
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('en'), Locale('bn')],
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class BloodLinkApp extends MyApp {
  const BloodLinkApp({super.key});
}

/// Root widget that decides between the login flow and the authenticated
/// home shell based on [AuthProvider.status], and shows a splash while the
/// persisted session is still being restored.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;

    switch (status) {
      case AuthStatus.unknown:
        // Shown on every app open while a persisted session (if any) is
        // being restored — see SplashScreen for why this also covers a
        // cold Render backend.
        return const SplashScreen();
      case AuthStatus.authenticated:
        return const HomeScreen();
      case AuthStatus.unauthenticated:
        return FutureBuilder<bool>(
          future: StorageService.instance.hasCompletedOnboarding(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SplashScreen();
            return snapshot.data!
                ? const LoginScreen()
                : const OnboardingScreen();
          },
        );
    }
  }
}
