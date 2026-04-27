import 'package:flutter/material.dart';

import '../../core/classic_style.dart';
import '../../services/announcement_service.dart';
import '../../services/auth_service.dart';
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
import '../payments/payment_authorization_page.dart';
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
  String? _announcementTypeFilter;

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
    _announcementTypeFilter = switch (widget.initialMode) {
      HomeFeedMode.announcements => 'Ogłoszenie',
      HomeFeedMode.reports => 'Zgłoszenie',
      HomeFeedMode.all => null,
    };
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
    final activeFilters = _buildActiveFiltersSummary();

    List<Announcement> filtered = _allOffers;

    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      filtered = filtered
          .where(
            (a) =>
                a.title.toLowerCase().contains(q) ||
                a.description.toLowerCase().contains(q),
          )
          .toList();
    }

    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered
          .where(
            (a) =>
                AnnouncementMetadata.parseCategory(a.category) ==
                _selectedCategory,
          )
          .toList();
    }

    // Zastosowanie dodatkowych filtrów (cena, lokalizacja, sortowanie).
    final filters = SearchFilters(
      sortOption: _sortOption,
      announcementType: _announcementTypeFilter,
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
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: ClassicStyle.my_dark_green,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black,
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          _announcementTypeFilter == null
                              ? 'Ogłoszenia i zgłoszenia'
                              : _announcementTypeFilter!,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSearchBar(context),
                    const SizedBox(height: 12),
                    activeFilters,
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: _buildOffersCard(context, filtered),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          style: TextButton.styleFrom(
            backgroundColor: isDark
                ? Colors.transparent
                : ClassicStyle.my_dark_green,
            foregroundColor: isDark ? null : Colors.white,
          ),
          onPressed: () async {
            final initialFilters = SearchFilters(
              sortOption: _sortOption,
              announcementType: _announcementTypeFilter,
              category: _selectedCategory,
              minDeposit: _minDeposit,
              maxDeposit: _maxDeposit,
              location: _locationFilter,
              radiusKm: _radiusKm,
              searchText: _searchQuery,
            );

            final result = await Navigator.of(context).push<SearchFilters>(
              createSlideFadeRoute(FiltersPage(initial: initialFilters)),
            );

            if (result != null && mounted) {
              setState(() {
                _sortOption = result.sortOption;
                _announcementTypeFilter = result.announcementType;
                _selectedCategory = result.category;
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

  Widget _buildActiveFiltersSummary() {
    final labels = <String>[];

    if (_announcementTypeFilter != null &&
        _announcementTypeFilter!.isNotEmpty) {
      labels.add('Typ: ${_announcementTypeFilter!}');
    }
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      labels.add('Kategoria: ${_selectedCategory!}');
    }
    if (_minDeposit != null || _maxDeposit != null) {
      final minText = _minDeposit != null
          ? _minDeposit!.toStringAsFixed(0)
          : '0';
      final maxText = _maxDeposit != null
          ? _maxDeposit!.toStringAsFixed(0)
          : 'bez limitu';
      labels.add('Kaucja: $minText - $maxText');
    }
    if (_locationFilter != null && _locationFilter!.isNotEmpty) {
      labels.add('Lokalizacja: ${_locationFilter!}');
    }
    if (_sortOption != null) {
      labels.add('Sortowanie: ${_sortOptionLabel(_sortOption!)}');
    }

    final theme = Theme.of(context);

    if (labels.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('Aktywne filtry: brak', style: theme.textTheme.bodyMedium),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: labels
            .map(
              (label) => Chip(
                label: Text(label),
                backgroundColor: theme.colorScheme.primaryContainer,
                labelStyle: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: BorderSide(
                  color: theme.colorScheme.primary.withOpacity(0.35),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  String _sortOptionLabel(SortOption option) {
    switch (option) {
      case SortOption.nameAsc:
        return 'Nazwa A-Z';
      case SortOption.nameDesc:
        return 'Nazwa Z-A';
      case SortOption.depositAsc:
        return 'Kaucja rosnąco';
      case SortOption.depositDesc:
        return 'Kaucja malejąco';
    }
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
                _announcementTypeFilter == null
                    ? 'Aktywne ogłoszenia / zgłoszenia'
                    : _announcementTypeFilter == 'Ogłoszenie'
                    ? 'Aktywne ogłoszenia'
                    : 'Aktywne zgłoszenia',
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
                        onPayment: () {
                          Navigator.of(context).push(
                            createSlideFadeRoute(
                              PaymentAuthorizationPage(
                                authResult: widget.authResult,
                                announcement: ad,
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
