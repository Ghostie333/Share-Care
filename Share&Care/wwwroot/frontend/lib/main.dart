import 'dart:async';

import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'features/home/home_page.dart';
import 'features/feedback/app_rating_page.dart';
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
              child: _SurveyPromptWrapper(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const _StartupScreen(),
        );
      },
    );
  }
}

class _SurveyPromptWrapper extends StatefulWidget {
  final Widget child;

  const _SurveyPromptWrapper({required this.child});

  @override
  State<_SurveyPromptWrapper> createState() => _SurveyPromptWrapperState();
}

class _SurveyPromptWrapperState extends State<_SurveyPromptWrapper>
    with WidgetsBindingObserver {
  static const Duration _promptDelay = Duration(minutes: 5);
  bool _shownThisSession = false;
  bool _dialogOpen = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
    }
  }

  void _startTimer() {
    if (_shownThisSession) return;
    _timer?.cancel();
    _timer = Timer(_promptDelay, _showPromptIfNeeded);
  }

  Future<void> _showPromptIfNeeded() async {
    if (!mounted || _shownThisSession || _dialogOpen) return;

    _dialogOpen = true;
    _shownThisSession = true;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Czy podoba Ci sie nasza strona/aplikacja?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Nie'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AppRatingPage(),
                  ),
                );
              },
              child: const Text('Tak'),
            ),
          ],
        );
      },
    );

    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
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
