import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../announcements/annoucements_detail_page.dart';
import '../announcements/announcement_metadata.dart';
import '../announcements/announcement_grid.dart';
import '../models/annoucement.dart';
import '../../core/classic_style.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/announcement_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/rental_service.dart';
import '../announcements/create_announcement_sheet.dart';
import '../../utils/animations.dart';
import '../auth/auth_login_page.dart';
import '../chat/chat_page.dart';
import '../navigation/app_bar.dart';
import '../search/search_page.dart';
import '../profile/profile_page.dart';
import '../announcements/create_report_sheet.dart';
import '../payments/payment_authorization_page.dart';
import '../../widgets/ad_placeholder.dart';

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

  final MapController _mapController = MapController();

  UserProfileInfo? _profileInfo;
  LatLng? _profileCenter;
  bool _didMoveToProfileCenter = false;

  HomeFeedMode _mode = HomeFeedMode.all;
  String _searchQuery = '';
  String? _selectedCategory;
  late bool _aboutExpanded;

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    _selectedCategory = widget.initialCategory;
    _aboutExpanded = !(widget.authResult.userId?.isNotEmpty ?? false);
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
      await _resolveAndCenterProfileLocation(info.city);
    } catch (_) {
      // Profil jest opcjonalny dla strony głównej – brak snackbara.
    }
  }

  Future<void> _resolveAndCenterProfileLocation(String? rawCity) async {
    if (!mounted) return;
    final city = (rawCity ?? '').trim();
    if (city.isEmpty) return;

    final parsed = _parseLatLng(city);
    LatLng? center = parsed;

    center ??= await _geocodeWithMapTiler(city);
    if (center == null) return;

    if (!mounted) return;
    setState(() {
      _profileCenter = center;
    });

    // Po pierwszym zbudowaniu mapy przesuń widok na lokalizację profilu.
    if (_didMoveToProfileCenter) return;
    _didMoveToProfileCenter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(center!, 12);
    });
  }

  Future<LatLng?> _geocodeWithMapTiler(String query) async {
    final key = AppConfig.mapTilerApiKey;
    if (key.isEmpty) return null;

    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final encoded = Uri.encodeComponent(trimmed);
    final uri = Uri.parse(
      'https://api.maptiler.com/geocoding/$encoded.json?key=$key&limit=1',
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final features = (data['features'] as List<dynamic>? ?? const []);
      if (features.isEmpty) return null;

      final first = features.first as Map<String, dynamic>;
      final geometry = first['geometry'] as Map<String, dynamic>?;
      final coords = geometry?['coordinates'];

      // MapTiler geocoding: [lng, lat]
      if (coords is List && coords.length >= 2) {
        final lng = coords[0];
        final lat = coords[1];
        if (lat is num && lng is num) {
          return LatLng(lat.toDouble(), lng.toDouble());
        }
      }
    } catch (_) {
      return null;
    }

    return null;
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

    final nick = (_profileInfo?.firstName ?? widget.authResult.firstName)
        .trim();
    final greetingNick = nick.isEmpty ? 'w Share&Care' : nick;

    List<Announcement> filtered = _allOffers;
    if (_mode == HomeFeedMode.announcements) {
      filtered = filtered
          .where(
            (a) => AnnouncementMetadata.parseType(a.category) == 'Ogłoszenie',
          )
          .toList();
    } else if (_mode == HomeFeedMode.reports) {
      filtered = filtered
          .where(
            (a) => AnnouncementMetadata.parseType(a.category) == 'Zgłoszenie',
          )
          .toList();
    }

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
                    Row(
                      children: [
                        Container(
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
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 140,
                            ),
                            child: Text(
                              'Witaj, $greetingNick',
                              softWrap: true,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const Spacer(),

                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Dziękuję że jesteś'),
                              ),
                            );
                          },
                          child: Image.asset(
                            'images/logo/shareandcare_logo.png',
                            height: 60,
                          ),
                        ),

                        const Spacer(),

                        _buildAuthButton(theme),
                                            
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildSearchBar(context),
                    const SizedBox(height: 12),
                    _buildFeedModeButtons(context),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  _buildAboutTile(context),
                  const SizedBox(height: 12),
                  _buildMapCard(context),
                  const SizedBox(height: 16),
                  _buildOffersCard(context, filtered),
                ],
              ),
            ),
          ),
        ],
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
              initialOfferKind: AnnouncementMetadata.offerKinds.first,
              categories: AnnouncementMetadata.categories,
              types: AnnouncementMetadata.types,
              offerKinds: AnnouncementMetadata.offerKinds,
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
                createSlideFadeRoute(SearchPage(authResult: widget.authResult)),
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

    final shortId = isLoggedIn
      ? '${userId.length > 10 ? userId.substring(0, 10) : userId.substring(0, 10)}...'
      : '';

    final label = isLoggedIn ? 'ID: $shortId' : 'Zaloguj się';

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
                  createSlideFadeRoute(HomePage(authResult: auth)),
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

    final allSorted = List<Announcement>.from(_allOffers)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final userCityRaw = (_profileInfo?.city ?? '').trim();
    final userCity = userCityRaw.toLowerCase();

    final cityScopedOffers = userCity.isEmpty
        ? const <Announcement>[]
        : allSorted
              .where((a) => a.location.trim().toLowerCase().contains(userCity))
              .toList();

    final tileAds = (cityScopedOffers.isNotEmpty ? cityScopedOffers : allSorted)
        .take(6)
        .toList();

    final markerAds = tileAds
        .where((a) => a.lat != null && a.lng != null)
        .toList();

    // Spróbuj użyć lokalizacji z profilu użytkownika (jeśli jest w formacie "lat,lng"),
    // w przeciwnym razie środek mapy wyznaczany jest na podstawie najnowszego markera
    // lub domyślnie ustawiany na Warszawę.
    final LatLng? userCenter =
        _profileCenter ??
        (_profileInfo == null ? null : _parseLatLng(_profileInfo!.city));

    final center =
        userCenter ??
        (markerAds.isNotEmpty
            ? LatLng(markerAds.first.lat!, markerAds.first.lng!)
            : const LatLng(52.2297, 21.0122)); // Warszawa jako domyślne centrum
    

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
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=${AppConfig.mapTilerApiKey}',
                  userAgentPackageName: 'share_care_frontend',
                ),
                if (userCenter != null && markerAds.isNotEmpty)
                  PolylineLayer(
                    polylines: markerAds
                        .map(
                          (ad) => Polyline(
                            points: [userCenter, LatLng(ad.lat!, ad.lng!)],
                            strokeWidth: 2,
                            color: Colors.blueAccent.withOpacity(0.55),
                          ),
                        )
                        .toList(),
                  ),
                MarkerLayer(
                  markers: [
                    if (userCenter != null)
                      Marker(
                        point: userCenter,
                        width: 46,
                        height: 46,
                        child: const Icon(
                          Icons.person_pin_circle,
                          size: 34,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ...markerAds.map((ad) {
                      final lat = ad.lat;
                      final lng = ad.lng;
                      if (lat == null || lng == null) return null;
                      return Marker(
                        point: LatLng(lat, lng),
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
                    }).whereType<Marker>(),
                  ],
                ),
              ],
            ),
            if (tileAds.isNotEmpty) ...[
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.dividerColor.withOpacity(0.7),
                      ),
                    ),
                    child: Text(
                      'Najnowsze ogłoszenia',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 48,
                bottom: 10,
                child: _buildMapTileColumn(
                  ads: tileAds.take((tileAds.length / 2).ceil()).toList(),
                ),
              ),
              Positioned(
                right: 10,
                top: 48,
                bottom: 10,
                child: _buildMapTileColumn(
                  ads: tileAds.skip((tileAds.length / 2).ceil()).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

   Widget _buildAboutTile(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      child: ExpansionTile(
        initiallyExpanded: _aboutExpanded,
        onExpansionChanged: (value) {
          setState(() => _aboutExpanded = value);
        },
        title: const Text('Share&Care - o platformie'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Center(
            child: Image.asset(
              'images/logo/shareandcare_logo.png',
              height: 72,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Dziel się, wypożyczaj i dawaj drugie życie rzeczom.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Text(
              'Share&Care to lokalna platforma wymiany i wypożyczania. '
              'Znajdź ogloszenia w okolicy, pomóż innym i buduj zaufanie '
              'dzięki wspólnym spotkaniom i bezpiecznemu mechanizmowi wypożyczania,'
              'który dba o ineteresy obu stron',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapTileColumn({required List<Announcement> ads}) {
    final theme = Theme.of(context);

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: ads.map((ad) {
        final city = ad.location.trim().isEmpty ? '—' : ad.location.trim();
        return GestureDetector(
          onTap: () {
            final lat = ad.lat;
            final lng = ad.lng;
            if (lat != null && lng != null) {
              _mapController.move(LatLng(lat, lng), 13);
            }
            _openAdFromMap(ad);
          },
          child: Container(
            width: 130,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.dividerColor.withOpacity(0.7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ad.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOffersCard(BuildContext context, List<Announcement> filtered) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 10),
          const AdPlaceholder(label: 'Reklama'),
          const SizedBox(height: 8),
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
                      onPayment: () => _handleTakeAction(ad),
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
    if (lat < -90 || lat > 90) return null;
    if (lng < -180 || lng > 180) return null;
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
                ChatPage(authResult: widget.authResult, initialListing: ad),
              ),
            );
          },
          onPayment: () {
            _handleTakeAction(ad);
          },
        );
      },
    );
  }

  Future<void> _handleTakeAction(Announcement ad) async {
    if (ad.offerKind == 'Give') {
      try {
        await RentalService.startRental(offerId: ad.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prośba o oddanie została wysłana.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się wysłać prośby: $e')),
        );
      }
      return;
    }

    Navigator.of(context).push(
      createSlideFadeRoute(
        PaymentAuthorizationPage(
          authResult: widget.authResult,
          announcement: ad,
        ),
      ),
    );
  }
}
