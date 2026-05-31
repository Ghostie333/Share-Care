import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../core/classic_style.dart';
import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/rental_service.dart';
import '../../services/wallet_service.dart';
import '../models/annoucement.dart';
import 'payment_survey_page.dart';

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

class _PaymentAuthorizationPageState extends State<PaymentAuthorizationPage>
    with WidgetsBindingObserver {
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
  late final TextEditingController _rentalDaysController;

  UserProfileInfo? _profile;
  bool _isLoadingProfile = false;
  bool _isSubmitting = false;

  String? _pendingTransactionId;
  PaymentDraft? _pendingDraft;
  DateTime? _pendingDeadlineAt;
  bool _isCheckingPayment = false;
  String? _lastPaymentStatus;

  Timer? _paymentPollTimer;

  bool _useProfileName = true;
  bool _useProfileEmail = true;
  bool _useProfilePhone = true;
  bool _useProfileCity = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    _rentalDaysController = TextEditingController(text: '7');

    _loadProfile();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final hasPending = _pendingTransactionId != null;
      if (hasPending) {
        _checkPaymentAndContinue();
      }
    }
  }

  @override
  void dispose() {
    _paymentPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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
    _rentalDaysController.dispose();
    super.dispose();
  }

  void _startPaymentPolling() {
    _paymentPollTimer?.cancel();
    _paymentPollTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!mounted) return;
      if (_pendingTransactionId == null) return;
      await _checkPaymentAndContinue();
    });
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
    if (_pendingTransactionId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masz już oczekującą płatność. Sprawdź jej status.')),
      );
      return;
    }

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

      final deadlineAt = _resolveDeadlineAt();
      final offerKind = widget.announcement.offerKind;

      var shouldStartRentalNow = true;

      // Flow docelowy dla wypożyczenia (Borrow): portfel -> rental/start.
      // PayU uruchamiamy tylko jeśli brakuje środków do kaucji.
      if (offerKind == 'Borrow') {
        if (draft.amount <= 0) {
          throw Exception('Kaucja musi być większa od 0');
        }

        final wallet = await WalletService.getMyWallet();
        final requiredAmount = draft.amount;

        if (wallet.availableBalance + 1e-9 >= requiredAmount) {
          shouldStartRentalNow = true;
        } else {
          shouldStartRentalNow = false;
          final missing = requiredAmount - wallet.availableBalance;
          final topUpAmount = missing <= 0 ? requiredAmount : missing;

          final deposit = await PaymentService.createDeposit(amount: topUpAmount);

          setState(() {
            _pendingTransactionId = deposit.transactionId;
            _pendingDraft = draft;
            _pendingDeadlineAt = deadlineAt;
            _lastPaymentStatus = PaymentService.pendingStatus;
          });

          _startPaymentPolling();

          final launched = await launchUrl(
            Uri.parse(deposit.redirectUrl),
            mode: LaunchMode.externalApplication,
          );

          if (!launched) {
            throw Exception('Nie udało się otworzyć strony płatności');
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'PayU otwarte (doładowanie portfela). Po płatności wróć i kliknij "Sprawdź płatność".',
              ),
            ),
          );

          return; // czekamy na potwierdzenie wpłaty
        }
      }

      if (shouldStartRentalNow) {
        await RentalService.startRental(
          offerId: widget.announcement.id,
          deadlineAt: deadlineAt,
        );
      }

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Prośba wysłana'),
            content: SingleChildScrollView(
              child: Text(
                'Przekazaliśmy prośbę do ogłoszeniodawcy.\n\n'
                'Kod autoryzacji: ${draft.authorizationCode}\n'
                'Kwota: ${draft.amount.toStringAsFixed(2)} zł',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openSurvey();
                },
                child: const Text('Przejdź do ankiety'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Później'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się rozpocząć procesu: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }

  void _openSurvey() {
    final targetUserId = widget.announcement.userId;
    if (targetUserId == null || targetUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Brak danych autora ogłoszenia.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentSurveyPage(
          targetUserId: targetUserId,
          announcementTitle: widget.announcement.title,
        ),
      ),
    );
  }

  Future<void> _checkPaymentAndContinue() async {
    final txId = _pendingTransactionId;
    if (txId == null || txId.isEmpty) return;
    if (_isCheckingPayment) return;

    setState(() => _isCheckingPayment = true);
    try {
      final tx = await PaymentService.fetchTransactionStatus(txId);
      if (!mounted) return;
      setState(() => _lastPaymentStatus = tx.status);

      if (PaymentService.isCompleted(tx.status)) {
        _paymentPollTimer?.cancel();

        await RentalService.startRental(
          offerId: widget.announcement.id,
          deadlineAt: _pendingDeadlineAt,
        );

        if (!mounted) return;
        setState(() {
          _pendingTransactionId = null;
          _pendingDeadlineAt = null;
        });

        await showDialog<void>(
          context: context,
          builder: (context) {
            final draft = _pendingDraft;
            final amountText = draft == null
                ? '-'
                : '${draft.amount.toStringAsFixed(2)} zł';
            final codeText = draft?.authorizationCode ?? '-';

            return AlertDialog(
              title: const Text('Płatność potwierdzona'),
              content: SingleChildScrollView(
                child: Text(
                  'Płatność została zakończona.\n\n'
                  'Kod autoryzacji: $codeText\n'
                  'Kwota: $amountText',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openSurvey();
                  },
                  child: const Text('Przejdź do ankiety'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Później'),
                ),
              ],
            );
          },
        );

        return;
      }

      if (PaymentService.isFailed(tx.status)) {
        _paymentPollTimer?.cancel();
        if (mounted) {
          setState(() {
            _pendingTransactionId = null;
            _pendingDeadlineAt = null;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Płatność anulowana lub nieudana.')),
        );
        return;
      }

      // Statusy pośrednie (np. Pending) obsługujemy cicho – UI odświeża się samo.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się sprawdzić płatności: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isCheckingPayment = false);
    }
  }

  DateTime? _resolveDeadlineAt() {
    final raw = _rentalDaysController.text.trim();
    final days = int.tryParse(raw);
    if (days == null || days <= 0) return null;
    return DateTime.now().add(Duration(days: days));
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
    final depositTextColor = theme.brightness == Brightness.dark
      ? Colors.black87
      : theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Autoryzacja płatności'),
        backgroundColor: ClassicStyle.my_dark_green,
        foregroundColor: Colors.white,
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
                          Icon(
                            Icons.savings_outlined,
                            color: depositTextColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Kaucja: $depositText',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: depositTextColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_pendingTransactionId != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: theme.colorScheme.surface,
                            border: Border.all(
                              color: ClassicStyle.my_dark_green.withOpacity(0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.payments_outlined),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Oczekująca płatność: ${_lastPaymentStatus ?? PaymentService.pendingStatus}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _isCheckingPayment ? null : _checkPaymentAndContinue,
                                icon: const Icon(Icons.refresh),
                                label: Text(
                                  _isCheckingPayment
                                      ? 'Sprawdzanie...'
                                      : 'Sprawdź płatność',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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
                    _buildField(
                      controller: _rentalDaysController,
                      label: 'Liczba dni wypożyczenia',
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (widget.announcement.offerKind == 'Borrow') {
                          final days = int.tryParse(value?.trim() ?? '');
                          if (days == null || days <= 0) {
                            return 'Podaj liczbę dni wypożyczenia';
                          }
                        }
                        return null;
                      },
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
                            : 'Autoryzuj płatność',
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
