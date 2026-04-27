import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../core/app_theme.dart';
import '../../utils/animations.dart';
import '../announcements/announcement_metadata.dart';
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
  late bool _reduceMotion;
  late bool _highContrast;
  late double _textScale;

  @override
  void initState() {
    super.initState();
    _isDark = AppTheme.themeMode.value == ThemeMode.dark;
    _reduceMotion = AppTheme.reduceMotion.value;
    _highContrast = AppTheme.highContrast.value;
    _textScale = AppTheme.textScale.value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        children: [
          ListTile(
            title: const Text('Wygląd'),
            subtitle: const Text('Dostosuj motyw i czytelność interfejsu'),
            leading: const Icon(Icons.palette_outlined),
          ),
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
          SwitchListTile(
            title: const Text('Wysoki kontrast'),
            subtitle: const Text(
              'Poprawia czytelność elementów formularzy i kart',
            ),
            value: _highContrast,
            onChanged: (value) {
              setState(() {
                _highContrast = value;
              });
              AppTheme.setHighContrast(value);
            },
          ),
          ListTile(
            title: const Text('Rozmiar tekstu'),
            subtitle: Text('${(_textScale * 100).round()}%'),
            leading: const Icon(Icons.text_fields),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              min: 0.95,
              max: 1.30,
              divisions: 7,
              value: _textScale,
              label: '${(_textScale * 100).round()}%',
              onChanged: (value) {
                final rounded = (value * 20).round() / 20;
                setState(() {
                  _textScale = rounded;
                });
                AppTheme.setTextScale(rounded);
              },
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Komfort'),
            subtitle: const Text(
              'Zmniejsz ruch i rozpraszające efekty wizualne',
            ),
            leading: const Icon(Icons.tune),
          ),
          SwitchListTile(
            title: const Text('Ogranicz animacje'),
            subtitle: const Text(
              'Ułatwia korzystanie osobom wrażliwym na ruch',
            ),
            value: _reduceMotion,
            onChanged: (value) {
              setState(() {
                _reduceMotion = value;
              });
              AppTheme.setReduceMotion(value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Ustawienia są zapisywane automatycznie'),
            subtitle: const Text(
              'Po ponownym uruchomieniu aplikacji Twoje preferencje zostaną zachowane.',
            ),
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
            createSlideFadeRoute(SearchPage(authResult: widget.authResult)),
          );
        },
        onAddTap: () {
          showCreateAnnouncementSheet(
            context: context,
            authResult: widget.authResult,
            initialCategory: AnnouncementMetadata.defaultCategory,
            initialType: AnnouncementMetadata.defaultAnnouncementType,
            categories: AnnouncementMetadata.categories,
            types: AnnouncementMetadata.types,
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
            createSlideFadeRoute(ChatPage(authResult: widget.authResult)),
          );
        },
        onProfileTap: () {},
      ),
    );
  }
}
