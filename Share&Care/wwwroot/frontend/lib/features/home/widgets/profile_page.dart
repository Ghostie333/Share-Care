import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/announcement_service.dart';
import '../../../services/user_profile_service.dart';
import '../../../config/app_config.dart';
import '../../../utils/animations.dart';
import '../../auth/edit_profile_page.dart';
import '../../auth/change_password_page.dart';
import '../../models/annoucement.dart';
import '../../settings/settings_page.dart';
import '../../announcements/annoucements_detail_page.dart';
import '../../announcements/announcement_form_sheet.dart';
import '../../announcements/announcement_metadata.dart';
import 'announcement_grid.dart';
import '../../auth/auth_login_page.dart';
import '../../chat/chat_page.dart';
import '../../history/history_page.dart';
import '../../navigation/app_bar.dart';
import '../../search/search_page.dart';
import '../home_page.dart';
import '../../payments/payment_authorization_page.dart';

class ProfileScreen extends StatefulWidget {
  final AuthResult authResult;

  const ProfileScreen({super.key, required this.authResult});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late String _firstName;
  late String _lastName;
  late String _email;
  late String _city;
  String _phoneNumber = '';
  String _raiting = '';
  String _type = '';

  final List<Announcement> _ads = [];
  bool _showActiveAds = true;

  String get _initials {
    final firstInitial = _firstName.isNotEmpty ? _firstName[0] : '';
    final lastInitial = _lastName.isNotEmpty ? _lastName[0] : '';
    final combined = (firstInitial + lastInitial).toUpperCase();
    return combined.isEmpty ? '?' : combined;
  }

  @override
  void initState() {
    super.initState();
    _firstName = widget.authResult.firstName;
    _lastName = widget.authResult.lastName;
    _email = widget.authResult.email;
    _city = '';
    _loadUserProfile();
    _loadUserAds();
  }

  Future<void> _loadUserProfile() async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final info = await UserProfileService.fetchProfile(userId);
      if (!mounted) return;
      setState(() {
        _firstName = info.firstName;
        _lastName = info.lastName;
        _email = info.email;
        _city = info.city;
        _phoneNumber = info.phoneNumber;
        _raiting = info.raiting;
        _type = info.type;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać profilu: $e')),
      );
    }
  }

  // Ładowanie ogłoszenia
  Future<void> _loadUserAds() async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) {
      return;
    }

    try {
      final offers = await AnnouncementService.getUserOffers(userId);
      if (!mounted) return;

      setState(() {
        _ads
          ..clear()
          ..addAll(offers);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać ogłoszeń: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Profil'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: SizedBox(
        width: MediaQuery.of(context).size.width / 2,
        child: Drawer(
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edytuj dane'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _onEditProfilePressed();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock_reset),
                  title: const Text('Zmiana hasła'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await _onChangePasswordPressed();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Ustawienia'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _onSettingsPressed();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Wyloguj'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _onLogoutPressed();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildSectionCard(child: _buildProfileHeader()),
            const SizedBox(height: 16),
            _buildSectionCard(child: _buildUserInfoSection()),
            const SizedBox(height: 16),
            _buildSectionCard(child: _buildAdsSection()),
            const SizedBox(height: 16),
            _buildSectionCard(child: _buildOtherSectionsPlaceholder()),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Wersja: 0.1.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 96),
          ],
        ),
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
          await _onCreateAdPressed();
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
        onProfileTap: () {},
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    final theme = Theme.of(context);

    return Card(
      color: theme.cardColor,
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: theme.colorScheme.primary,
          foregroundImage: widget.authResult.userId == null
              ? null
              : NetworkImage(
                  '${AppConfig.apiBaseUrl}/UserProfile/photo/${widget.authResult.userId}',
                ),
          child: Text(
            _initials,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimary,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$_firstName $_lastName',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _email,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_city.isNotEmpty)
              _buildInfoChip(label: _city, icon: Icons.location_on_outlined),
            if (_raiting.isNotEmpty)
              _buildInfoChip(label: _raiting, icon: Icons.star_outline),
            if (_type.isNotEmpty)
              _buildInfoChip(label: _type, icon: Icons.verified_user_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip({required String label, required IconData icon}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dane konta',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Divider(color: theme.dividerColor.withOpacity(0.8)),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _infoRow('Imię', _firstName),
                  _infoRow('Nazwisko', _lastName),
                  _infoRow('Email', _email),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                children: [
                  _infoRow('Miasto', _city.isEmpty ? '-' : _city),
                  _infoRow(
                    'Telefon',
                    _phoneNumber.isEmpty ? '-' : _phoneNumber,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: Text(
              value,
              textAlign: TextAlign.left,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsSection() {
    final activeAds = _ads.where((ad) => ad.isActive).toList();
    final inactiveAds = _ads.where((ad) => !ad.isActive).toList();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _showActiveAds ? 'Aktywne ogłoszenia' : 'Nieaktywne ogłoszenia',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: _showActiveAds
                      ? theme.colorScheme.primary.withOpacity(0.18)
                      : Colors.transparent,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  if (!_showActiveAds) {
                    setState(() => _showActiveAds = true);
                  }
                },
                child: const Text('Aktywne'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: !_showActiveAds
                      ? theme.colorScheme.primary.withOpacity(0.18)
                      : Colors.transparent,
                  foregroundColor: theme.colorScheme.onSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () {
                  if (_showActiveAds) {
                    setState(() => _showActiveAds = false);
                  }
                },
                child: const Text('Nieaktywne'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnnouncementGrid(
          announcements: _showActiveAds ? activeAds : inactiveAds,
          onTap: _openAdDetails,
        ),
      ],
    );
  }

  Widget _buildOtherSectionsPlaceholder() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Inne',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Divider(color: theme.dividerColor.withOpacity(0.8)),
        const SizedBox(height: 6),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune),
          title: const Text('Ustawienia wyświetlania'),
          subtitle: const Text(
            'Motyw, kontrast, czcionka, język (w przygotowaniu)',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: const Text('Historia'),
          subtitle: const Text(
            'Wyszukiwania, ogłoszenia, czaty (w przygotowaniu)',
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.of(context).push(
              createSlideFadeRoute(HistoryPage(authResult: widget.authResult)),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.emoji_events_outlined),
          title: const Text('Punkty / nagrody'),
          subtitle: const Text('W przygotowaniu'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ],
    );
  }

  Future<void> _onCreateAdPressed() async {
    await _openAdForm();
  }

  Future<void> _onEditProfilePressed() async {
    final result = await Navigator.of(context).push(
      createSlideFadeRoute(EditProfileScreen(authResult: widget.authResult)),
    );

    final updated = result is UserProfileInfo ? result : null;

    if (updated != null && mounted) {
      setState(() {
        _firstName = updated.firstName;
        _lastName = updated.lastName;
        _email = updated.email;
        _city = updated.city;
      });
    }
  }

  void _onSettingsPressed() {
    Navigator.of(
      context,
    ).push(createSlideFadeRoute(SettingsPage(authResult: widget.authResult)));
  }

  void _onLogoutPressed() {
    AuthService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      createSlideFadeRoute(const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _onChangePasswordPressed() async {
    await Navigator.of(context).push(
      createSlideFadeRoute(ChangePasswordScreen(authResult: widget.authResult)),
    );
  }

  Future<void> _openAdForm({Announcement? existingAd}) async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Brak identyfikatora użytkownika - nie można zapisać ogłoszenia.',
            ),
          ),
        );
      }
      return;
    }

    UserProfileInfo profile;
    try {
      profile = await UserProfileService.fetchProfile(userId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać profilu: $e')),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _firstName = profile.firstName;
      _lastName = profile.lastName;
      _email = profile.email;
      _city = profile.city;
      _phoneNumber = profile.phoneNumber;
      _raiting = profile.raiting;
      _type = profile.type;
    });

    final ownerName = '${profile.firstName} ${profile.lastName}'.trim();
    final phoneNumber = profile.phoneNumber;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return AnnouncementFormSheet(
          existingAd: existingAd,
          ownerName: ownerName,
          categories: AnnouncementMetadata.categories,
          types: AnnouncementMetadata.types,
          initialCategory: AnnouncementMetadata.defaultCategory,
          initialType: AnnouncementMetadata.defaultAnnouncementType,
          initialCity: profile.city,
          initialPhoneNumber: phoneNumber,
          onSubmit:
              (
                title,
                description,
                location,
                deposit,
                images,
                category,
                type,
                contactNumber,
              ) async {
                try {
                  if (existingAd == null) {
                    final encodedCategory = AnnouncementMetadata.encode(
                      type,
                      category,
                    );
                    final newAnnouncement = Announcement(
                      id: '',
                      userId: userId,
                      title: title,
                      description: description,
                      location: location,
                      deposit: deposit,
                      ownerName: ownerName,
                      isActive: true,
                      createdAt: DateTime.now(),
                      imageUrls: const [],
                      isOwner: true,
                      category: encodedCategory,
                      contactName: ownerName,
                      contactNumber: contactNumber,
                    );

                    final created = await AnnouncementService.createOffer(
                      newAnnouncement,
                      images: images,
                    );

                    if (!mounted) return;
                    setState(() {
                      _ads.add(created);
                    });
                  } else {
                    existingAd
                      ..title = title
                      ..description = description
                      ..location = location
                      ..deposit = deposit;

                    await AnnouncementService.updateOffer(existingAd);

                    if (!mounted) return;
                    setState(() {});
                  }
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Błąd zapisu ogłoszenia: $e')),
                  );
                }
              },
        );
      },
    );
  }

  void _openAdDetails(Announcement ad) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AnnouncementDetailsDialog(
          ad: ad,
          onEdit: () {
            Navigator.of(ctx).pop();
            _openAdForm(existingAd: ad);
          },
          onClose: () async {
            final confirmed =
                await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Zmień aktywność ogłoszenia'),
                      content: const Text(
                        'Czy na pewno chcesz oznaczyć to ogłoszenie jako nieaktywne?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Nie'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Tak'),
                        ),
                      ],
                    );
                  },
                ) ??
                false;

            if (!confirmed) return;

            try {
              await AnnouncementService.closeOffer(ad.id);
              if (!mounted) return;
              setState(() {
                ad.isActive = false;
              });
              Navigator.of(ctx).pop();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Błąd zamykania ogłoszenia: $e')),
              );
            }
          },
          onDelete: () async {
            final confirmed =
                await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text('Usuń ogłoszenie'),
                      content: const Text(
                        'Czy na pewno chcesz usunąć to ogłoszenie?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Nie'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Tak'),
                        ),
                      ],
                    );
                  },
                ) ??
                false;

            if (!confirmed) return;

            try {
              await AnnouncementService.deleteOffer(ad.id);
              if (!mounted) return;
              setState(() {
                _ads.removeWhere((a) => a.id == ad.id);
              });
              Navigator.of(ctx).pop();
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Błąd usuwania ogłoszenia: $e')),
              );
            }
          },
          onChat: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).push(
              createSlideFadeRoute(
                ChatPage(authResult: widget.authResult, initialListing: ad),
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
  }
}
