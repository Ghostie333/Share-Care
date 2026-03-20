import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../core/app_theme.dart';
import '../../utils/animations.dart';
import '../announcements/create_announcement_sheet.dart';
import '../chat/chat_page.dart';
import '../home/home_page.dart';
import '../navigation/app_bar.dart';
import '../search/search_page.dart';

class SettingsPage extends StatefulWidget {
  final AuthResult authResult;

  const SettingsPage({super.key, required this.authResult});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _isDark = AppTheme.themeMode.value == ThemeMode.dark;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ustawienia'),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Tryb ciemny'),
            subtitle: const Text('Przełącz motyw aplikacji na ciemny/jasny'),
            value: _isDark,
            onChanged: (value) {
              setState(() {
                _isDark = value;
              });
              AppTheme.setDarkMode(value);
            },
          ),
        ],
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentTab: BottomNavTab.profile,
        onHomeTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(HomePage(authResult: widget.authResult)),
          );
        },
        onSearchTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(
              SearchPage(authResult: widget.authResult),
            ),
          );
        },
        onAddTap: () {
          showCreateAnnouncementSheet(
            context: context,
            authResult: widget.authResult,
            onCreated: (_) async {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dodano ogłoszenie')),
              );
            },
          );
        },
        onMessagesTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(
              ChatPage(authResult: widget.authResult),
            ),
          );
        },
        onProfileTap: () {},
      ),
    );
  }
}
