import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../announcements/annoucements_detail_page.dart';
import '../announcements/announcement_metadata.dart';
import '../home/widgets/announcement_grid.dart';
import '../models/annoucement.dart';
import '../../core/classic_style.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/announcement_service.dart';
import '../../services/user_profile_service.dart';
import '../announcements/create_announcement_sheet.dart';
import '../../utils/animations.dart';
import '../auth/auth_login_page.dart';
import '../chat/chat_page.dart';
import '../../config/app_config.dart';
import '../navigation/app_bar.dart';
import '../search/search_page.dart';
import 'widgets/profile_page.dart';
import '../announcements/create_report_sheet.dart';

enum HomeFeedMode { all, announcements, reports }

class HomePage extends StatefulWidget {
  final AuthResult authResult;

  /// Opcjonalne wstępne filtry, ustawiane np. ze strony wyszukiwania.
  final String? initialCategory;
  final String? initialSearchQuery;

  const HomePage({
    super.key,
    required this.authResult,
    this.initialCategory,
    this.initialSearchQuery,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Announcement> _allOffers = [];
  bool _isLoading = true;

  UserProfileInfo? _profileInfo;

  HomeFeedMode _mode = HomeFeedMode.all;
  String _searchQuery = '';
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    _selectedCategory = widget.initialCategory;
    _loadProfileIfPossible();
    _loadOffers();
  }

  Future<void> _loadProfileIfPossible() async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) return;

    try {
      final info = await UserProfileService.fetchProfile(userId);
      if (!mounted) return;
      setState(() => _profileInfo = info);
    } catch (_) {
      // Profil jest opcjonalny dla strony głównej – brak snackbara.
    }
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
    } catch (_) {
      // Docelowo tu podłączysz snackbar; na razie nie blokujemy UI.
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final nick = (_profileInfo?.firstName ?? widget.authResult.firstName).trim();
    final greetingNick = nick.isEmpty ? 'w Share&Care' : nick;

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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        'Witaj, $greetingNick',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildAuthButton(theme),
              ],
            ),
            const SizedBox(height: 16),
            _buildSearchBar(context),
            const SizedBox(height: 12),
            _buildFeedModeButtons(context),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildMapCard(context),
                    const SizedBox(height: 16),
                    _buildOffersCard(context, filtered),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: MainBottomNavBar(
        currentTab: BottomNavTab.home,
        onHomeTap: () {},
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

          if (!context.mounted) return;
          if (_mode == HomeFeedMode.reports) {
            showCreateReportSheet(
              context: context,
              authResult: widget.authResult,
              initialCategory: _selectedCategory?.isNotEmpty == true
                  ? _selectedCategory!
                  : AnnouncementMetadata.defaultCategory,
              initialType: AnnouncementMetadata.defaultReportType,
              categories: AnnouncementMetadata.categories,
              types: AnnouncementMetadata.types,
              onCreated: (_) async => _loadOffers(),
            );
          } else {
            showCreateAnnouncementSheet(
              context: context,
              authResult: widget.authResult,
              initialCategory: _selectedCategory?.isNotEmpty == true
                  ? _selectedCategory!
                  : AnnouncementMetadata.defaultCategory,
              initialType: AnnouncementMetadata.defaultAnnouncementType,
              categories: AnnouncementMetadata.categories,
              types: AnnouncementMetadata.types,
              onCreated: (_) async => _loadOffers(),
            );
          }
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
        if ((_selectedCategory != null && _selectedCategory!.isNotEmpty) ||
            _searchQuery.trim().isNotEmpty)
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                createSlideFadeRoute(
                  SearchPage(authResult: widget.authResult),
                ),
              );
            },
            icon: const Icon(Icons.filter_list),
            label: const Text('Filtruj'),
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

  /// Przycisk w prawym górnym rogu: "Zaloguj się" lub "ID: ...".
  Widget _buildAuthButton(ThemeData theme) {
    final userId = widget.authResult.userId;
    final bool isLoggedIn = userId != null && userId.isNotEmpty;

    final label = isLoggedIn ? 'ID: $userId' : 'Zaloguj się';

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.appBarTheme.foregroundColor ?? Colors.white,
        side: BorderSide(
          color: theme.appBarTheme.foregroundColor ?? Colors.white,
        ),
      ),
      onPressed: () async {
        if (isLoggedIn) {
          // Nic nie robimy – przycisk informacyjny z ID.
          return;
        }

        if (!context.mounted) return;
        await Navigator.of(context).push(
          createSlideFadeRoute(
            LoginScreen(
              onLoginSuccess: (auth) {
                Navigator.of(context).pushReplacement(
                  createSlideFadeRoute(
                    HomePage(authResult: auth),
                  ),
                );
              },
            ),
          ),
        );
      },
      child: Text(label),
    );
  }

  Widget _buildMapCard(BuildContext context) {
    final theme = Theme.of(context);

    // Jeśli nie ma skonfigurowanego klucza MapTiler, nie renderujemy mapy.
    if (AppConfig.mapTilerApiKey.isEmpty) {
      return const SizedBox.shrink();
    }

    final offersWithCoords = _allOffers
        .where((a) => a.location.isNotEmpty && _parseLatLng(a.location) != null)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final topTen = offersWithCoords.take(1).toList();
    if (topTen.isEmpty) {
      return const SizedBox.shrink();
    }

    // Spróbuj użyć lokalizacji z profilu użytkownika (jeśli jest w formacie "lat,lng"),
    // w przeciwnym razie środek mapy wyznaczany jest na podstawie najnowszego ogłoszenia
    // lub domyślnie ustawiany na Warszawę.
    final LatLng? userCenter = _profileInfo == null
      ? null
      : _parseLatLng(_profileInfo!.city);

    final center = userCenter ??
      _parseLatLng(topTen.first.location) ??
      LatLng(52.2297, 21.0122); // Warszawa jako domyślne centrum

    return Container(
      width: double.infinity,
      height: 240,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
          ),
          children: [
            TileLayer(
              urlTemplate:
                'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=${AppConfig.mapTilerApiKey}',
              userAgentPackageName: 'share_care_frontend',
            ),
            MarkerLayer(
              markers: topTen
                  .map((ad) {
                    final latLng = _parseLatLng(ad.location);
                    if (latLng == null) return null;
                    return Marker(
                      point: latLng,
                      width: 40,
                      height: 40,
                      child: IconButton(
                        icon: const Icon(
                          Icons.location_on,
                          color: Colors.redAccent,
                          size: 30,
                        ),
                        onPressed: () => _openAdFromMap(ad),
                      ),
                    );
                  })
                  .whereType<Marker>()
                  .toList(),
            ),
          ],
        ),
      ),
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
    );
  }

  LatLng? _parseLatLng(String raw) {
    final parts = raw.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  void _openAdFromMap(Announcement ad) {
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
  }
}

