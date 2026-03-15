import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';
import '../../../services/announcement_service.dart';
import '../../../core/classic_style.dart';
import '../../../utils/animations.dart';
import '../../auth/edit_profile_page.dart';
import '../../models/annoucement.dart';
import '../../settings/settings_page.dart';
import '../../announcements/annoucements_detail_page.dart';
import '../../announcements/announcement_form_sheet.dart';
import 'announcement_grid.dart';

class ProfileScreen extends StatefulWidget {
  final AuthResult authResult;

  const ProfileScreen({super.key, required this.authResult});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final String _firstName;
  late final String _lastName;
  late final String _email;
  late final String _city;

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
    _loadUserAds();
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                color: Colors.white,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    'Profil użytkownika',
                    textAlign: TextAlign.center,
                    style: ClassicStyle.title,
                  ),
                  const SizedBox(height: 20),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dane konta',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _infoRow('Imię', _firstName),
        _infoRow('Nazwisko', _lastName),
        _infoRow('Email', _email),
        _infoRow('Miasto', _city.isEmpty ? '-' : _city),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _onEditProfilePressed,
            icon: const Icon(Icons.settings),
            label: const Text('Edytuj ustawienia konta'),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
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
        const Text(
          'Aktywne ogłoszenia',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        const Text(
          'Inne sekcje (do zaimplementowania):',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('- Ustawienia konta i prywatności (zmiana hasła, itp.)'),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Ustawienia wyświetlania'),
          subtitle:
              const Text('Motyw, kontrast, czcionka, język (w przygotowaniu)'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            Navigator.of(context).push(
              createSlideFadeRoute(const SettingsPage()),
            );
          },
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

  void _onEditProfilePressed() {
    Navigator.of(context).push(
      createSlideFadeRoute(
        EditProfileScreen(authResult: widget.authResult),
      ),
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
          onSubmit: (title, description, location, deposit) {
            setState(() {
              if (existingAd == null) {
                _ads.add(
                  Announcement(
                    id: DateTime.now().microsecondsSinceEpoch.toString(),
                    title: title,
                    description: description,
                    location: location,
                    deposit: deposit,
                    ownerName: '$_firstName $_lastName',
                    isActive: true,
                    createdAt: DateTime.now(),
                    imageUrls: const [],
                    isOwner: true,
                  ),
                );
              } else {
                existingAd
                  ..title = title
                  ..description = description
                  ..location = location
                  ..deposit = deposit;
              }
            });
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
