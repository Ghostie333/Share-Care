import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/home/home_page.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.loadSavedSettings();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        AppTheme.themeMode,
        AppTheme.textScale,
        AppTheme.reduceMotion,
        AppTheme.highContrast,
      ]),
      builder: (context, _) {
        final mode = AppTheme.themeMode.value;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Share&Care',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: TextScaler.linear(AppTheme.textScale.value),
                disableAnimations:
                    AppTheme.reduceMotion.value || media.disableAnimations,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const _StartupScreen(),
        );
      },
    );
  }
}

class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  AuthResult? _authResult;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (loggedIn) {
      final stored = await AuthService.getStoredAuthResult();
      setState(() {
        _authResult = stored;
        _loading = false;
      });
    } else {
      setState(() {
        _authResult = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final auth =
        _authResult ??
        AuthResult(
          userId: null,
          email: '',
          firstName: '',
          lastName: '',
          accessToken: null,
        );

    return HomePage(authResult: auth);
  }
}
