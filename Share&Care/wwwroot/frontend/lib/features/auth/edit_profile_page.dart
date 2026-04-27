import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/announcement_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_profile_service.dart';
import '../../core/classic_style.dart';
import '../../utils/animations.dart';
import 'auth_login_page.dart';

class EditProfileScreen extends StatefulWidget {
  final AuthResult authResult;

  const EditProfileScreen({super.key, required this.authResult});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  File? _avatarFile;

  late String _firstName;
  late String _lastName;
  late String _email;
  String _city = '';
  String? _phoneNumber;
  String? _birthday;
  String? _postalCode;
  String? _street;
  String? _buildingNumber;
  String _initialCity = '';

  @override
  void initState() {
    super.initState();
    _firstName = widget.authResult.firstName;
    _lastName = widget.authResult.lastName;
    _email = widget.authResult.email;
    _loadUserProfile();
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
        _phoneNumber = info.phoneNumber.isEmpty ? null : info.phoneNumber;
        _postalCode = info.postalCode.isEmpty ? null : info.postalCode;
        _street = info.street.isEmpty ? null : info.street;
        _buildingNumber = info.buildingNumber.isEmpty
            ? null
            : info.buildingNumber;
        _initialCity = info.city;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się pobrać profilu: $e')),
      );
    }
  }

  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (picked != null) {
      setState(() {
        _avatarFile = File(picked.path);
      });

      // TODO: w tym miejscu możesz dodać wysyłkę pliku na backend,
      // gdy pojawi się odpowiedni endpoint (np. /UserProfile/avatar).
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width < 600 ? 16.0 : 24.0;
    final scaffoldBg = theme.brightness == Brightness.dark
        ? ClassicStyle.my_dark_theme
        : ClassicStyle.my_light_green;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Edycja profilu'),
        elevation: 0,
      ),
      backgroundColor: scaffoldBg,
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 620),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.surface,
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
                  Text(
                    'Edycja profilu',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // Avatar + przycisk zmiany
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: ClassicStyle.my_light_green,
                          backgroundImage: _avatarFile != null
                              ? FileImage(_avatarFile!)
                              : null,
                          child: _avatarFile == null
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _pickAvatar,
                          child: const Text('Zmień zdjęcie profilowe'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Dane użytkownika (na razie lokalnie odczytane z AuthResult)
                  _buildEditableField(
                    'Imię',
                    _firstName,
                    () => _editField(
                      title: 'Imię',
                      initialValue: _firstName,
                      applyValue: (v) => _firstName = v,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEditableField(
                    'Nazwisko',
                    _lastName,
                    () => _editField(
                      title: 'Nazwisko',
                      initialValue: _lastName,
                      applyValue: (v) => _lastName = v,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEditableField(
                    'Email',
                    _email,
                    () => _editField(
                      title: 'Email',
                      initialValue: _email,
                      applyValue: (v) => _email = v,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEditableField(
                    'Miasto',
                    _city,
                    () => _editField(
                      title: 'Miasto',
                      initialValue: _city,
                      applyValue: (v) => _city = v,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEditableField(
                    'Kod pocztowy',
                    _postalCode ?? '',
                    () => _editField(
                      title: 'Kod pocztowy',
                      initialValue: _postalCode ?? '',
                      applyValue: (v) => _postalCode = v,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEditableField(
                    'Ulica',
                    _street ?? '',
                    () => _editField(
                      title: 'Ulica',
                      initialValue: _street ?? '',
                      applyValue: (v) => _street = v,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEditableField(
                    'Numer budynku',
                    _buildingNumber ?? '',
                    () => _editField(
                      title: 'Numer budynku',
                      initialValue: _buildingNumber ?? '',
                      applyValue: (v) => _buildingNumber = v,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEditableField(
                    'Telefon',
                    _phoneNumber ?? '',
                    () => _editField(
                      title: 'Telefon',
                      initialValue: _phoneNumber ?? '',
                      applyValue: (v) => _phoneNumber = v,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Przyciski akcji: Zapisz i Usuń profil
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: _onSavePressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ClassicStyle.my_light_green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Zapisz'),
                      ),
                      OutlinedButton(
                        onPressed: _onDeleteProfilePressed,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                        ),
                        child: const Text('Usuń profil'),
                      ),
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

  Widget _buildEditableField(String label, String value, VoidCallback onEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: ClassicStyle.my_beige,
          ),
          child: Row(
            children: [
              Expanded(child: Text(value.isEmpty ? '-' : value)),
              IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editField({
    required String title,
    required String initialValue,
    required void Function(String) applyValue,
    bool obscure = false,
  }) async {
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edytuj $title'),
          content: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(hintText: title),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) =>
                Navigator.of(context).pop(controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anuluj'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Zapisz'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        applyValue(result);
      });
    }
  }

  Future<void> _onSavePressed() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Zapisz zmiany'),
              content: const Text('Czy na pewno chcesz zapisać zmiany?'),
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
      await UserProfileService.updateProfile(
        firstName: _firstName,
        lastName: _lastName,
        email: _email,
        birthday: _birthday,
        phoneNumber: _phoneNumber,
        city: _city,
        postalCode: _postalCode,
        street: _street,
        buildingNumber: _buildingNumber,
      );

      final userId = widget.authResult.userId;
      final cityChanged = _city.trim() != _initialCity.trim();
      if (cityChanged && userId != null && userId.isNotEmpty) {
        await _syncOfferLocationsWithProfileCity(userId);
      }

      if (_avatarFile != null) {
        await UserProfileService.uploadAvatar(_avatarFile!);
      }

      _initialCity = _city;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil został zapisany.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd zapisu profilu: $e')));
      }
    }
  }

  Future<void> _syncOfferLocationsWithProfileCity(String userId) async {
    final city = _city.trim();
    if (city.isEmpty) return;

    final offers = await AnnouncementService.getUserOffers(userId);
    final toUpdate = offers
        .where((o) => o.location.trim().toLowerCase() != city.toLowerCase())
        .toList();

    for (final offer in toUpdate) {
      offer.location = city;
      await AnnouncementService.updateOffer(offer);
    }
  }

  Future<void> _onDeleteProfilePressed() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Usuń profil'),
              content: const Text(
                'Czy na pewno chcesz usunąć profil? Tej operacji nie można cofnąć.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Nie'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Tak, usuń'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) return;

    try {
      await UserProfileService.deleteProfile();
      await AuthService.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        createSlideFadeRoute(const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd usuwania profilu: $e')));
      }
    }
  }
}
