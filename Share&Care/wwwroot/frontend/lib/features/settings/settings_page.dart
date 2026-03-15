import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

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
    );
  }
}
