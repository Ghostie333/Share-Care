import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/classic_style.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../services/user_profile_service.dart';
import '../models/annoucement.dart';

class PaymentAuthorizationPage extends StatefulWidget {
  final AuthResult authResult;
  final Announcement announcement;

  const PaymentAuthorizationPage({
    super.key,
    required this.authResult,
    required this.announcement,
  });

  @override
  State<PaymentAuthorizationPage> createState() =>
      _PaymentAuthorizationPageState();
}

class _PaymentAuthorizationPageState extends State<PaymentAuthorizationPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _cityController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _streetController;
  late final TextEditingController _buildingNumberController;
  late final TextEditingController _apartmentNumberController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _taxIdController;

  UserProfileInfo? _profile;
  bool _isLoadingProfile = false;
  bool _isSubmitting = false;

  bool _useProfileName = true;
  bool _useProfileEmail = true;
  bool _useProfilePhone = true;
  bool _useProfileCity = true;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.authResult.firstName,
    );
    _lastNameController = TextEditingController(
      text: widget.authResult.lastName,
    );
    _emailController = TextEditingController(text: widget.authResult.email);
    _phoneController = TextEditingController();
    _cityController = TextEditingController();
    _postalCodeController = TextEditingController();
    _streetController = TextEditingController();
    _buildingNumberController = TextEditingController();
    _apartmentNumberController = TextEditingController();
    _companyNameController = TextEditingController();
    _taxIdController = TextEditingController();

    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _postalCodeController.dispose();
    _streetController.dispose();
    _buildingNumberController.dispose();
    _apartmentNumberController.dispose();
    _companyNameController.dispose();
    _taxIdController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final userId = widget.authResult.userId;
    if (userId == null || userId.isEmpty) return;

    setState(() => _isLoadingProfile = true);
    try {
      final profile = await UserProfileService.fetchProfile(userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
      _applyProfileData();
    } catch (_) {
      // Profil jest opcjonalny dla formularza płatności.
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingProfile = false);
    }
  }

  void _applyProfileData() {
    final profile = _profile;
    if (profile == null) return;

    if (_useProfileName) {
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
    }
    if (_useProfileEmail) {
      _emailController.text = profile.email;
    }
    if (_useProfilePhone) {
      _phoneController.text = profile.phoneNumber;
    }
    if (_useProfileCity) {
      _cityController.text = profile.city;
      _postalCodeController.text = profile.postalCode;
      _streetController.text = profile.street;
      _buildingNumberController.text = profile.buildingNumber;
    }
  }

  void _onUseProfileChanged({
    required bool enabled,
    required void Function(bool) setLocalState,
    required void Function(UserProfileInfo profile) apply,
  }) {
    setState(() {
      setLocalState(enabled);
      if (enabled && _profile != null) {
        apply(_profile!);
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final invoiceData = InvoiceData(
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        street: _streetController.text.trim(),
        buildingNumber: _buildingNumberController.text.trim(),
        apartmentNumber: _apartmentNumberController.text.trim(),
        companyName: _companyNameController.text.trim(),
        taxId: _taxIdController.text.trim(),
      );

      final draft = PaymentService.preparePayment(
        announcement: widget.announcement,
        invoiceData: invoiceData,
      );

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Autoryzacja przygotowana'),
            content: SingleChildScrollView(
              child: Text(
                'Kod autoryzacji: ${draft.authorizationCode}\n\n'
                'Kwota: ${draft.amount.toStringAsFixed(2)} zł\n\n'
                'Dane płatności (JSON):\n${const JsonEncoder.withIndent('  ').convert(draft.toJson())}',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Zamknij'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(draft);
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deposit = widget.announcement.deposit;
    final depositText = deposit != null
        ? '${deposit.toStringAsFixed(2)} zł'
        : 'Brak kaucji';
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width < 600 ? 16.0 : 24.0;
    final scaffoldBg = theme.brightness == Brightness.dark
        ? ClassicStyle.my_dark_theme
        : ClassicStyle.my_light_green;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Autoryzacja płatności'),
        backgroundColor: ClassicStyle.my_dark_green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 980),
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
                    Text(
                      'Płatność za ogłoszenie',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      widget.announcement.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: ClassicStyle.my_beige,
                        border: Border.all(
                          color: ClassicStyle.my_dark_green.withOpacity(0.35),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.savings_outlined),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Kaucja: $depositText',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingProfile)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: LinearProgressIndicator(),
                      ),
                    Text(
                      'Dane do faktury',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildTwoColumns(
                      left: _buildField(
                        controller: _firstNameController,
                        label: 'Imię',
                        readOnly: _useProfileName,
                        validator: _requiredValidator,
                      ),
                      right: _buildField(
                        controller: _lastNameController,
                        label: 'Nazwisko',
                        readOnly: _useProfileName,
                        validator: _requiredValidator,
                      ),
                    ),
                    _buildProfileCheckbox(
                      value: _useProfileName,
                      text: 'Użyj imienia i nazwiska z profilu',
                      onChanged: (value) {
                        _onUseProfileChanged(
                          enabled: value ?? false,
                          setLocalState: (v) => _useProfileName = v,
                          apply: (profile) {
                            _firstNameController.text = profile.firstName;
                            _lastNameController.text = profile.lastName;
                          },
                        );
                      },
                    ),
                    _buildField(
                      controller: _emailController,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      readOnly: _useProfileEmail,
                      validator: _requiredValidator,
                    ),
                    _buildProfileCheckbox(
                      value: _useProfileEmail,
                      text: 'Użyj email z profilu',
                      onChanged: (value) {
                        _onUseProfileChanged(
                          enabled: value ?? false,
                          setLocalState: (v) => _useProfileEmail = v,
                          apply: (profile) =>
                              _emailController.text = profile.email,
                        );
                      },
                    ),
                    _buildField(
                      controller: _phoneController,
                      label: 'Telefon',
                      keyboardType: TextInputType.phone,
                      readOnly: _useProfilePhone,
                    ),
                    _buildProfileCheckbox(
                      value: _useProfilePhone,
                      text: 'Użyj telefonu z profilu',
                      onChanged: (value) {
                        _onUseProfileChanged(
                          enabled: value ?? false,
                          setLocalState: (v) => _useProfilePhone = v,
                          apply: (profile) =>
                              _phoneController.text = profile.phoneNumber,
                        );
                      },
                    ),
                    _buildTwoColumns(
                      left: _buildField(
                        controller: _cityController,
                        label: 'Miasto',
                        readOnly: _useProfileCity,
                        validator: _requiredValidator,
                      ),
                      right: _buildField(
                        controller: _postalCodeController,
                        label: 'Kod pocztowy',
                        readOnly: _useProfileCity,
                        validator: _requiredValidator,
                      ),
                    ),
                    _buildProfileCheckbox(
                      value: _useProfileCity,
                      text:
                          'Użyj danych adresowych z profilu (miasto, kod, ulica, numer)',
                      onChanged: (value) {
                        _onUseProfileChanged(
                          enabled: value ?? false,
                          setLocalState: (v) => _useProfileCity = v,
                          apply: (profile) {
                            _cityController.text = profile.city;
                            _postalCodeController.text = profile.postalCode;
                            _streetController.text = profile.street;
                            _buildingNumberController.text =
                                profile.buildingNumber;
                          },
                        );
                      },
                    ),
                    _buildTwoColumns(
                      left: _buildField(
                        controller: _streetController,
                        label: 'Ulica',
                        readOnly: _useProfileCity,
                        validator: _requiredValidator,
                      ),
                      right: _buildField(
                        controller: _buildingNumberController,
                        label: 'Nr budynku',
                        readOnly: _useProfileCity,
                        validator: _requiredValidator,
                      ),
                    ),
                    _buildField(
                      controller: _apartmentNumberController,
                      label: 'Nr lokalu (opcjonalnie)',
                    ),
                    _buildField(
                      controller: _companyNameController,
                      label: 'Nazwa firmy (opcjonalnie)',
                    ),
                    _buildField(
                      controller: _taxIdController,
                      label: 'NIP (opcjonalnie)',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClassicStyle.my_light_green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: Text(
                        _isSubmitting
                            ? 'Przygotowywanie...'
                            : 'Autoryzuj płatność (wizualnie)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCheckbox({
    required bool value,
    required String text,
    required ValueChanged<bool?> onChanged,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Text(text),
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTwoColumns({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: [left, right]);
        }

        return Row(
          children: [
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    bool readOnly = false,
    String? Function(String?)? validator,
    TextInputAction textInputAction = TextInputAction.done,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        validator: validator,
        textInputAction: textInputAction,
        onFieldSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Pole wymagane';
    }
    return null;
  }
}
