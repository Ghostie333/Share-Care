import 'package:flutter/material.dart';

import '../../core/classic_style.dart';
import '../../services/auth_service.dart';
import '../../utils/animations.dart';
import '../announcements/announcement_metadata.dart';
import '../announcements/announcements_feed_page.dart';
import '../auth/auth_login_page.dart';
import '../chat/chat_page.dart';
import '../home/home_page.dart';
import '../home/widgets/profile_page.dart';
import '../navigation/app_bar.dart';

class SearchPage extends StatefulWidget {
  final AuthResult authResult;

  const SearchPage({super.key, required this.authResult});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  HomeFeedMode _mode = HomeFeedMode.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openFeedWithFilters({String? category}) {
    Navigator.of(context).pushReplacement(
      createSlideFadeRoute(
        AnnouncementsFeedPage(
          authResult: widget.authResult,
          initialCategory: category,
          initialSearchQuery: _searchController.text.trim().isEmpty
              ? null
              : _searchController.text.trim(),
          initialMode: _mode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kategorie'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: ClassicStyle.my_dark_green,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeedModeButtons(context),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Szukaj ogłoszeń...',
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                        filled: true,
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: () =>
                              _openFeedWithFilters(category: _selectedCategory),
                        ),
                      ),
                      onSubmitted: (_) =>
                          _openFeedWithFilters(category: _selectedCategory),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategoryList(context),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentTab: BottomNavTab.search,
        onHomeTap: () {
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(HomePage(authResult: widget.authResult)),
          );
        },
        onSearchTap: () {},
        onAddTap: () async {
          final loggedIn = await AuthService.isLoggedIn();
          if (!loggedIn) {
            if (!context.mounted) return;
            await Navigator.of(context).push(
              createSlideFadeRoute(
                LoginScreen(
                  onLoginSuccess: (_) {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            );
            return;
          }

          if (!context.mounted) return;
          // Tworzenie ogłoszenia – po zalogowaniu użytkownik może wrócić i spróbować ponownie.
          // Logika tworzenia pozostaje na stronie głównej/profilu.
        },
        onMessagesTap: () async {
          final loggedIn = await AuthService.isLoggedIn();
          if (!loggedIn) {
            if (!context.mounted) return;
            await Navigator.of(context).push(
              createSlideFadeRoute(
                LoginScreen(
                  onLoginSuccess: (_) {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            );
            return;
          }

          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(ChatPage(authResult: widget.authResult)),
          );
        },
        onProfileTap: () async {
          final loggedIn = await AuthService.isLoggedIn();
          if (!loggedIn) {
            if (!context.mounted) return;
            await Navigator.of(context).push(
              createSlideFadeRoute(
                LoginScreen(
                  onLoginSuccess: (auth) {
                    Navigator.of(context).pushReplacement(
                      createSlideFadeRoute(ProfileScreen(authResult: auth)),
                    );
                  },
                ),
              ),
            );
            return;
          }

          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(ProfileScreen(authResult: widget.authResult)),
          );
        },
      ),
    );
  }

  Widget _buildFeedModeButtons(BuildContext context) {
    final bool isAnnouncements = _mode == HomeFeedMode.announcements;
    final bool isReports = _mode == HomeFeedMode.reports;

    final width = MediaQuery.of(context).size.width;
    final bool compact = width < 420;

    return Row(
      children: [
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: isAnnouncements
                  ? ClassicStyle.my_light_green.withOpacity(0.2)
                  : Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () {
              setState(() => _mode = HomeFeedMode.announcements);
            },
            child: compact
                ? const Icon(Icons.campaign_outlined)
                : const Text('Ogłoszenia'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextButton(
            style: TextButton.styleFrom(
              backgroundColor: isReports
                  ? ClassicStyle.my_light_green.withOpacity(0.2)
                  : Colors.transparent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            onPressed: () {
              setState(() => _mode = HomeFeedMode.reports);
            },
            child: compact
                ? const Icon(Icons.report_gmailerrorred_outlined)
                : const Text('Zgłoszenia'),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList(BuildContext context) {
    final theme = Theme.of(context);

    IconData _iconForCategory(String label) {
      switch (label.toLowerCase()) {
        case 'książki':
          return Icons.menu_book;
        case 'elektronika':
          return Icons.devices_other;
        case 'artykuły budowlane':
          return Icons.construction;
        case 'motoryzacja':
          return Icons.directions_car;
        default:
          return Icons.category_outlined;
      }
    }

    Widget buildCategoryTile({
      required String title,
      required String subtitle,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
              ? ClassicStyle.my_light_green.withOpacity(0.15)
              : theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                ? ClassicStyle.my_light_green
                : theme.dividerColor.withOpacity(0.6),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                  ? ClassicStyle.my_light_green
                  : theme.iconTheme.color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: selected
                  ? ClassicStyle.my_light_green
                  : theme.iconTheme.color?.withOpacity(0.7),
              ),
            ],
          ),
        ),
      );
    }

    final tiles = <Widget>[
      buildCategoryTile(
        title: 'Wszystkie kategorie',
        subtitle: 'Przeglądaj wszystkie ogłoszenia',
        icon: Icons.view_list,
        selected: _selectedCategory == null || _selectedCategory!.isEmpty,
        onTap: () {
          setState(() => _selectedCategory = null);
          _openFeedWithFilters(category: null);
        },
      ),
      for (final c in AnnouncementMetadata.categories)
        if (c.toLowerCase() != 'wszystkie kategorie')
          buildCategoryTile(
            title: c,
            subtitle: 'Zobacz ogłoszenia w tej kategorii',
            icon: _iconForCategory(c),
            selected: _selectedCategory == c,
            onTap: () {
              setState(() => _selectedCategory = c);
              _openFeedWithFilters(category: c);
            },
          ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < tiles.length; i++) ...[
          tiles[i],
          if (i != tiles.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

