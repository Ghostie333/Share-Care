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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 18),
              Text(
                'Kategorie',
                style: (isDark
                        ? ClassicStyle.title_dark_theme
                        : ClassicStyle.title)
                    .copyWith(fontSize: 32),
              ),
              const SizedBox(height: 8),
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
                    onPressed: () => _openFeedWithFilters(category: _selectedCategory),
                  ),
                ),
                onSubmitted: (_) => _openFeedWithFilters(category: _selectedCategory),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 12),
              _buildCategoryList(context),
            ],
          ),
        ),
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

    Widget buildTile(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: selected
                  ? ClassicStyle.my_light_green.withOpacity(0.15)
                  : theme.cardColor,
              border: Border.all(
                color: selected
                    ? ClassicStyle.my_light_green
                    : theme.dividerColor.withOpacity(0.6),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
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
        ),
      );
    }

    final tiles = <Widget>[
      buildTile(
        'Wszystkie kategorie',
        _selectedCategory == null || _selectedCategory!.isEmpty,
        () {
          setState(() => _selectedCategory = null);
          _openFeedWithFilters(category: null);
        },
      ),
      for (final c in AnnouncementMetadata.categories)
        buildTile(
          c,
          _selectedCategory == c,
          () {
            setState(() => _selectedCategory = c);
            _openFeedWithFilters(category: c);
          },
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: tiles,
    );
  }
}

