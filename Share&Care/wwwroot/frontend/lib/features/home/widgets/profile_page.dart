import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/announcement_service.dart';
import '../../../services/user_profile_service.dart';
import '../../../core/classic_style.dart';
import '../../../utils/animations.dart';
import '../../auth/edit_profile_page.dart';
import '../../models/annoucement.dart';
import '../../settings/settings_page.dart';
import '../../announcements/annoucements_detail_page.dart';
import '../../announcements/announcement_form_sheet.dart';
import 'announcement_grid.dart';
import '../../auth/auth_login_page.dart';

class ProfileScreen extends StatefulWidget {
  final AuthResult authResult;

  const ProfileScreen({super.key, required this.authResult});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late String _firstName;
  late String _lastName;
  late String _email;
  late String _city;
  String _phoneNumber = '';
  String _raiting = '';
  String _type = '';

  final List<Announcement> _ads = [];

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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onCreateAdPressed,
        backgroundColor: ClassicStyle.my_light_green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Utwórz ogłoszenie'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.5,
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
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _onEditProfilePressed,
                          icon: const Icon(Icons.edit),
                          label: const Text('Edytuj dane'),
                        ),
                        TextButton.icon(
                          onPressed: _onLogoutPressed,
                          icon: const Icon(Icons.logout),
                          label: const Text('Wyloguj'),
                        ),
                        TextButton.icon(
                            onPressed: _onSettingsPressed,
                          icon: const Icon(Icons.settings),
                          label: const Text('Ustawienia'),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 18),
                      Text(
                        'Profil użytkownika',
                        textAlign: TextAlign.center,
                        style: isDark
                            ? ClassicStyle.title_dark_theme
                            : ClassicStyle.title,
                      ),
                      const SizedBox(height: 32),
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildUserInfoSection(),
                      const SizedBox(height: 24),
                      _buildAdsSection(),
                      const SizedBox(height: 24),
                      _buildOtherSectionsPlaceholder(),
                      const SizedBox(height: 96),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: ClassicStyle.my_light_green,
          child: Text(
            _initials,
            style: const TextStyle(
              fontSize: 28,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_firstName $_lastName',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _email,
                style: const TextStyle(color: Colors.black87),
              ),
              if (_city.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  _city,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Dane konta',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        _infoRow('Imię', _firstName),
        _infoRow('Nazwisko', _lastName),
        _infoRow('Email', _email),
        _infoRow('Miasto', _city.isEmpty ? '-' : _city),
        _infoRow('Telefon', _phoneNumber.isEmpty ? '-' : _phoneNumber),
        _infoRow('Typ konta', _type.isEmpty ? '-' : _type),
        _infoRow('Ocena', _raiting.isEmpty ? '-' : _raiting),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsSection() {
    final activeAds = _ads.where((ad) => ad.isActive).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aktywne ogłoszenia',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        AnnouncementGrid(
          announcements: activeAds,
          onTap: _openAdDetails,
        ),
      ],
    );
  }

  Widget _buildOtherSectionsPlaceholder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Inne sekcje (do zaimplementowania):',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        const Text('- Ustawienia konta i prywatności (zmiana hasła, itp.)'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ustawienia wyświetlania'),
          subtitle:
              const Text('Motyw, kontrast, czcionka, język (w przygotowaniu)'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
        const Text('- Historia wyszukiwania'),
        const Text('- Historia czatów'),
        const Text('- Historia ogłoszeń'),
        const Text('- Punkty / nagrody'),
      ],
    );
  }

  Future<void> _onCreateAdPressed() async {
    await _openAdForm();
  }

  Future<void> _onEditProfilePressed() async {
    final result = await Navigator.of(context).push(
      createSlideFadeRoute(
        EditProfileScreen(authResult: widget.authResult),
      ),
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
    Navigator.of(context).push(
      createSlideFadeRoute(const SettingsPage()),
    );
  }

  void _onLogoutPressed() {
    Navigator.of(context).pushAndRemoveUntil(
      createSlideFadeRoute(const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openAdForm({Announcement? existingAd}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return AnnouncementFormSheet(
          existingAd: existingAd,
          ownerName: '$_firstName $_lastName',
          onSubmit: (title, description, location, deposit) async {
            final userId = widget.authResult.userId;
            if (userId == null || userId.isEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Brak identyfikatora użytkownika – nie można zapisać ogłoszenia.'),
                  ),
                );
              }
              return;
            }

            try {
              if (existingAd == null) {
                final newAnnouncement = Announcement(
                  id: '',
                  userId: userId,
                  title: title,
                  description: description,
                  location: location,
                  deposit: deposit,
                  ownerName: '$_firstName $_lastName',
                  isActive: true,
                  createdAt: DateTime.now(),
                  imageUrls: const [],
                  isOwner: true,
                  category: 'Inne',
                  contactName: '$_firstName $_lastName',
                  contactNumber: _phoneNumber.isEmpty ? null : _phoneNumber,
                );

                final created = await AnnouncementService.createOffer(newAnnouncement);

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
          onDelete: () {
            setState(() {
              _ads.removeWhere((a) => a.id == ad.id);
            });
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }
}
