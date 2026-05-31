import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';

class ProfilePrivacySettingsPage extends StatefulWidget {
  final AuthResult authResult;

  const ProfilePrivacySettingsPage({super.key, required this.authResult});

  @override
  State<ProfilePrivacySettingsPage> createState() =>
      _ProfilePrivacySettingsPageState();
}

class _ProfilePrivacySettingsPageState extends State<ProfilePrivacySettingsPage> {
  bool _loading = true;
  bool _saving = false;
  UserProfileInfo? _profile;

  late bool _showFirstName;
  late bool _showLastName;
  late bool _showCity;
  late bool _showPhoneNumber;
  late bool _showProfileImage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    try {
      final profile = await UserProfileService.fetchProfile(userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _showFirstName = profile.showFirstName;
        _showLastName = profile.showLastName;
        _showCity = profile.showCity;
        _showPhoneNumber = profile.showPhoneNumber;
        _showProfileImage = profile.showProfileImage;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać ustawień profilu: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final profile = _profile;
    if (profile == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Udostępnianie danych'),
        content: const Text(
          'Czy na pewno chcesz aby dane zostały udostępnione?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await UserProfileService.updateProfile(
        firstName: profile.firstName,
        lastName: profile.lastName,
        email: profile.email,
        birthday: profile.brithday,
        phoneNumber: profile.phoneNumber,
        city: profile.city,
        postalCode: profile.postalCode,
        street: profile.street,
        buildingNumber: profile.buildingNumber,
        showFirstName: _showFirstName,
        showLastName: _showLastName,
        showCity: _showCity,
        showPhoneNumber: _showPhoneNumber,
        showProfileImage: _showProfileImage,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ustawienia prywatności zostały zapisane.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Nie udało się zapisać ustawień prywatności: $e'),
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: 
        AppBar(
          title: const Text('Prywatność profilu'),
          flexibleSpace: SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dziękuję że jesteś'),
                ),
              );
            },
            child: Image.asset(
              'images/logo/shareandcare_logo.png',
              height: 40,
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Wybierz osobno, które dane mają być widoczne publicznie.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Imię'),
                  subtitle: const Text('Pokaż imię na publicznym profilu'),
                  value: _showFirstName,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _showFirstName = value),
                ),
                SwitchListTile(
                  title: const Text('Nazwisko'),
                  subtitle: const Text('Pokaż nazwisko na publicznym profilu'),
                  value: _showLastName,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _showLastName = value),
                ),
                SwitchListTile(
                  title: const Text('Miasto'),
                  subtitle: const Text('Pokaż miasto na publicznym profilu'),
                  value: _showCity,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _showCity = value),
                ),
                SwitchListTile(
                  title: const Text('Numer telefonu'),
                  subtitle: const Text('Pokaż numer telefonu na publicznym profilu'),
                  value: _showPhoneNumber,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _showPhoneNumber = value),
                ),
                SwitchListTile(
                  title: const Text('Zdjęcie profilowe'),
                  subtitle: const Text('Pokaż zdjęcie profilowe na publicznym profilu'),
                  value: _showProfileImage,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _showProfileImage = value),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Zapisz zmiany'),
                ),
              ],
            ),
    );
  }
}