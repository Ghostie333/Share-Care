import 'package:flutter/material.dart';

import '../../core/classic_style.dart';
import '../../services/announcement_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../auth/auth_login_page.dart';
import '../chat/chat_page.dart';
import '../home/home_page.dart' show HomeFeedMode, HomePage;
import '../home/widgets/announcement_grid.dart';
import '../home/widgets/profile_page.dart';
import '../models/annoucement.dart';
import '../navigation/app_bar.dart';
import '../search/search_page.dart';
import '../search/filters_page.dart';
import '../search/search_filters.dart';
import '../announcements/annoucements_detail_page.dart';
import '../announcements/announcement_metadata.dart';
import '../../utils/animations.dart';

class AnnouncementsFeedPage extends StatefulWidget {
  final AuthResult authResult;
  final String? initialCategory;
  final String? initialSearchQuery;
  final HomeFeedMode initialMode;

  const AnnouncementsFeedPage({
    super.key,
    required this.authResult,
    this.initialCategory,
    this.initialSearchQuery,
    this.initialMode = HomeFeedMode.all,
  });

  @override
  State<AnnouncementsFeedPage> createState() => _AnnouncementsFeedPageState();
}

class _AnnouncementsFeedPageState extends State<AnnouncementsFeedPage> {
  final List<Announcement> _allOffers = [];
  bool _isLoading = true;

  String _searchQuery = '';
  String? _selectedCategory;
  HomeFeedMode _mode = HomeFeedMode.all;

  // Dodatkowe filtry z ekranu "Filtry".
  SortOption? _sortOption;
  double? _minDeposit;
  double? _maxDeposit;
  String? _locationFilter;
  double? _radiusKm;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    _selectedCategory = widget.initialCategory;
    _mode = widget.initialMode;
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    setState(() => _isLoading = true);
    try {
      final offers = await AnnouncementService.getActiveOffers(
        currentUserId: widget.authResult.userId,
      );
      if (!mounted) return;
      setState(() {
        _allOffers
          ..clear()
          ..addAll(offers);
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    List<Announcement> filtered = _allOffers;
    if (_mode == HomeFeedMode.announcements) {
      filtered = filtered
          .where((a) => AnnouncementMetadata.parseType(a.category) == 'Ogłoszenie')
          .toList();
    } else if (_mode == HomeFeedMode.reports) {
      filtered = filtered
          .where((a) => AnnouncementMetadata.parseType(a.category) == 'Zgłoszenie')
          .toList();
    }

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered
          .where((a) =>
              a.title.toLowerCase().contains(q) ||
              a.description.toLowerCase().contains(q))
          .toList();
    }

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where((a) => AnnouncementMetadata.parseCategory(a.category) == _selectedCategory)
          .toList();
    }

    // Zastosowanie dodatkowych filtrów (cena, lokalizacja, sortowanie).
    final filters = SearchFilters(
      sortOption: _sortOption,
      category: _selectedCategory,
      minDeposit: _minDeposit,
      maxDeposit: _maxDeposit,
      location: _locationFilter,
      radiusKm: _radiusKm,
      searchText: _searchQuery,
    );
    filtered = SearchFilters.applyTo(filtered, filters);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              _mode == HomeFeedMode.announcements
                  ? 'Ogłoszenia'
                  : _mode == HomeFeedMode.reports
                      ? 'Zgłoszenia'
                      : 'Ogłoszenia i zgłoszenia',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSearchBar(context),
            const SizedBox(height: 12),
            _buildFeedModeButtons(context),
            const SizedBox(height: 12),
            Expanded(child: _buildOffersCard(context, filtered)),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentTab: BottomNavTab.search,
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

          // tworzenie ogłoszenia / zgłoszenia odbywa się z poziomu strony głównej / profilu
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
            createSlideFadeRoute(HomePage(authResult: widget.authResult)),
          );
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

  Widget _buildSearchBar(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Szukaj...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              filled: true,
            ),
            onChanged: (v) {
              setState(() => _searchQuery = v);
            },
          ),
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: () async {
            final initialFilters = SearchFilters(
              sortOption: _sortOption,
              category: _selectedCategory,
              minDeposit: _minDeposit,
              maxDeposit: _maxDeposit,
              location: _locationFilter,
              radiusKm: _radiusKm,
              searchText: _searchQuery,
            );

            final result = await Navigator.of(context).push<SearchFilters>(
              createSlideFadeRoute(
                FiltersPage(initial: initialFilters),
              ),
            );

            if (result != null && mounted) {
              setState(() {
                _sortOption = result.sortOption;
                _selectedCategory = result.category ?? _selectedCategory;
                _minDeposit = result.minDeposit;
                _maxDeposit = result.maxDeposit;
                _locationFilter = result.location;
                _radiusKm = result.radiusKm;
              });
            }
          },
          icon: const Icon(Icons.filter_list),
          label: const Text('Filtry'),
        ),
      ],
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

  Widget _buildOffersCard(BuildContext context, List<Announcement> filtered) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.cardColor,
        boxShadow: const [
          BoxShadow(
            color: Colors.black,
            blurRadius: 14,
            spreadRadius: 2,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                _mode == HomeFeedMode.announcements
                    ? 'Aktywne ogłoszenia'
                    : _mode == HomeFeedMode.reports
                        ? 'Aktywne zgłoszenia'
                        : 'Aktywne ogłoszenia / zgłoszenia',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              AnnouncementGrid(
                announcements: filtered,
                onTap: (ad) {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) {
                      return AnnouncementDetailsDialog(
                        ad: ad,
                        onEdit: null,
                        onDelete: null,
                        onClose: null,
                        onChat: () async {
                          Navigator.of(ctx).pop();
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
                          Navigator.of(context).push(
                            createSlideFadeRoute(
                              ChatPage(
                                authResult: widget.authResult,
                                initialListing: ad,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
