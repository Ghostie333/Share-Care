import 'package:flutter/material.dart';

/// Prosty dolny pasek nawigacji z 5 ikonami.
///
/// Nazwa pliku historycznie sugeruje "app_bar", ale UI jest dolnym paskiem
/// widocznym na dole ekranu.
enum BottomNavTab { home, search, messages, profile }

class MainBottomNavBar extends StatelessWidget {
  final BottomNavTab currentTab;

  final VoidCallback onHomeTap;
  final VoidCallback onSearchTap;
  final VoidCallback onAddTap;
  final VoidCallback onMessagesTap;
  final VoidCallback onProfileTap;

  const MainBottomNavBar({
    super.key,
    required this.currentTab,
    required this.onHomeTap,
    required this.onSearchTap,
    required this.onAddTap,
    required this.onMessagesTap,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
    final foregroundColor = theme.appBarTheme.foregroundColor ?? Colors.white;
    final unselectedColor = foregroundColor.withOpacity(0.75);

    Color selectedIconColor(BottomNavTab tab) =>
        currentTab == tab ? foregroundColor : unselectedColor;

    Widget navIcon({
      required IconData icon,
      required BottomNavTab tab,
      required VoidCallback onTap,
    }) {
      return IconButton(
        tooltip: tab.name,
        icon: Icon(
          icon,
          color: selectedIconColor(tab),
          size: 28,
        ),
        onPressed: onTap,
      );
    }

    return BottomAppBar(
      color: backgroundColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              navIcon(
                icon: Icons.home,
                tab: BottomNavTab.home,
                onTap: onHomeTap,
              ),
              navIcon(
                icon: Icons.search,
                tab: BottomNavTab.search,
                onTap: onSearchTap,
              ),
              Center(
                child: Material(
                  color: foregroundColor.withOpacity(0.18),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onAddTap,
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Icon(
                        Icons.add,
                        color: foregroundColor,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
              navIcon(
                icon: Icons.message,
                tab: BottomNavTab.messages,
                onTap: onMessagesTap,
              ),
              navIcon(
                icon: Icons.person,
                tab: BottomNavTab.profile,
                onTap: onProfileTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

