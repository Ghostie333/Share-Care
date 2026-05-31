import 'package:flutter/material.dart';
import '../../utils/animations.dart';
import 'auth_login_page.dart';
import '../../core/classic_style.dart';
import 'package:flutter/services.dart';

import '../../services/auth_service.dart';
import '../../services/address_validation_service.dart';
import '../profile/profile_page.dart';
import '../home/home_page.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final phoneNumberController = TextEditingController();
  final dateBirthController = TextEditingController();
  final addressNameController = TextEditingController();
  final streetController = TextEditingController();
  final buildingNumberController = TextEditingController();
  final postCodeController = TextEditingController();
  final emailController = TextEditingController();
  final emailConfirmController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();

  bool showEmailConfirm = false;
  bool showPasswordConfirm = false;

  bool _isLoading = false;
  SocialAuthProvider? _socialLoadingProvider;

  @override
  void initState() {
    super.initState();

    emailController.addListener(() {
      setState(() {
        showEmailConfirm = emailController.text.isNotEmpty;
      });
    });

    passwordController.addListener(() {
      setState(() {
        showPasswordConfirm = passwordController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneNumberController.dispose();
    dateBirthController.dispose();
    addressNameController.dispose();
    streetController.dispose();
    buildingNumberController.dispose();
    postCodeController.dispose();
    emailController.dispose();
    emailConfirmController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final city = addressNameController.text.trim();
      final postalCode = postCodeController.text.trim();

      final isAddressValid =
          await AddressValidationService.validateCityAndPostalCode(
            city: city,
            postalCode: postalCode,
          );

      if (!isAddressValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Miasto i kod pocztowy wydają się nie pasować. Sprawdź dane.',
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      await AuthService.registerUser(
        email: emailController.text.trim(),
        password: passwordController.text,
        firstName: firstNameController.text.trim(),
        lastName: lastNameController.text.trim(),
        phoneNumber: phoneNumberController.text.trim().isEmpty
            ? null
            : phoneNumberController.text.trim(),
        birthday: dateBirthController.text.trim(),
        city: addressNameController.text.trim().isEmpty
            ? null
            : addressNameController.text.trim(),
        postalCode: postCodeController.text.trim().isEmpty
            ? null
            : postCodeController.text.trim(),
        street: streetController.text.trim().isEmpty
            ? null
            : streetController.text.trim(),
        buildingNumber: buildingNumberController.text.trim().isEmpty
            ? null
            : buildingNumberController.text.trim(),
      );

      // Auto-logowanie po pomyślnej rejestracji — używamy tego samego
      // endpointu co przy normalnym logowaniu.
      final authResult = await AuthService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        createSlideFadeRoute(ProfileScreen(authResult: authResult)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitSocialRegistration(SocialAuthProvider provider) async {
    setState(() => _socialLoadingProvider = provider);

    try {
      final authResult = await AuthService.registerWithSocial(
        provider: provider,
      );
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        createSlideFadeRoute(ProfileScreen(authResult: authResult)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd rejestracji społecznościowej: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _socialLoadingProvider = null);
      }
    }
  }

  Widget _buildSocialRegisterButton({
    required String label,
    required IconData icon,
    required SocialAuthProvider provider,
  }) {
    final isLoading = _socialLoadingProvider == provider;

    return OutlinedButton.icon(
      onPressed: (_isLoading || _socialLoadingProvider != null)
          ? null
          : () => _submitSocialRegistration(provider),
      icon: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Future<void> _pickBirthday(BuildContext context) async {
    final now = DateTime.now();
    DateTime? initial;
    final raw = dateBirthController.text.trim();
    if (raw.isNotEmpty) {
      try {
        final parts = raw.split('.');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          initial = DateTime(year, month, day);
        }
      } catch (_) {
        initial = null;
      }
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (selected == null) return;

    final day = selected.day.toString().padLeft(2, '0');
    final month = selected.month.toString().padLeft(2, '0');
    final year = selected.year.toString();

    setState(() {
      dateBirthController.text = '$day.$month.$year';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 520;
    final horizontalPadding = width < 600 ? 16.0 : 24.0;
    final scaffoldBg = theme.brightness == Brightness.dark
        ? ClassicStyle.my_dark_theme
        : ClassicStyle.my_light_green;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Rejestracja'),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // Jak w ekranie logowania: brak poprzedniej strony – wróć na stronę główną jako gość.
              final guestAuth = AuthResult(
                userId: null,
                email: '',
                firstName: '',
                lastName: '',
              );
              Navigator.of(context).pushReplacement(
                createSlideFadeRoute(HomePage(authResult: guestAuth)),
              );
            }
          },
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 620),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Theme.of(context).colorScheme.surface,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 14,
                          spreadRadius: 2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Rejestracja',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Row: Imię i Nazwisko
                        isNarrow
                            ? Column(
                                children: [
                                  TextFormField(
                                    controller: firstNameController,
                                    decoration: const InputDecoration(
                                      labelText: "Imię",
                                      filled: true,
                                      fillColor: Colors.transparent,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Podaj imię";
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: lastNameController,
                                    decoration: const InputDecoration(
                                      labelText: "Nazwisko",
                                      filled: true,
                                      fillColor: Colors.transparent,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return "Podaj nazwisko";
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: firstNameController,
                                      decoration: const InputDecoration(
                                        labelText: "Imię",
                                        filled: true,
                                        fillColor: Colors.transparent,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return "Podaj imię";
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: lastNameController,
                                      decoration: const InputDecoration(
                                        labelText: "Nazwisko",
                                        filled: true,
                                        fillColor: Colors.transparent,
                                      ),
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return "Podaj nazwisko";
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj email";
                            }
                            final emailRegex = RegExp(
                              r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,4}$',
                            );
                            if (!emailRegex.hasMatch(value)) {
                              return "Niepoprawny email";
                            }
                            return null;
                          },
                        ),

                        /// WYSUWANE POLE POTWIERDZENIA EMAILA
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: showEmailConfirm
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: TextFormField(
                                    key: const ValueKey("emailConfirm"),
                                    controller: emailConfirmController,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                      labelText: "Potwierdź email",
                                      filled: true,
                                      fillColor: Colors.transparent,
                                    ),
                                    validator: (value) {
                                      if (showEmailConfirm) {
                                        if (value == null || value.isEmpty) {
                                          return "Potwierdź email";
                                        }
                                        if (emailController.text != value) {
                                          return "Adresy email nie są takie same";
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneNumberController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Numer Telefonu",
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj numer telefonu";
                            }
                            final phoneRegex = RegExp(r'^[0-9]{9}$');
                            if (!phoneRegex.hasMatch(value)) {
                              return "Numer musi mieć 9 cyfr";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: dateBirthController,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.datetime,
                          decoration: InputDecoration(
                            labelText: "Data urodzenia (DD.MM.RRRR)",
                            filled: true,
                            fillColor: Colors.transparent,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today_outlined),
                              onPressed: () => _pickBirthday(context),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj datę urodzenia";
                            }
                            final dateRegex = RegExp(r'^\d{2}\.\d{2}\.\d{4}$');
                            if (!dateRegex.hasMatch(value)) {
                              return "Format daty: DD.MM.RRRR";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressNameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Adres zamieszkania (miasto)",
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj adres";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: streetController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Ulica",
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj ulicę";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: buildingNumberController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Numer budynku",
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj numer budynku";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: postCodeController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Kod pocztowy (NN-NNN)",
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj kod pocztowy";
                            }
                            final postRegex = RegExp(r'^[0-9]{2}-[0-9]{3}$');
                            if (!postRegex.hasMatch(value)) {
                              return "Format kodu: NN-NNN";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Hasło",
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj hasło";
                            }
                            if (value.length < 6) {
                              return "Hasło musi mieć min. 6 znaków";
                            }
                            return null;
                          },
                        ),

                        /// WYSUWANE POLE POTWIERDZENIA HASŁA
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: showPasswordConfirm
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: TextFormField(
                                    key: const ValueKey("passConfirm"),
                                    controller: passwordConfirmController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    onFieldSubmitted: (_) {
                                      if (!_isLoading) {
                                        _submitRegistration();
                                      }
                                    },
                                    decoration: const InputDecoration(
                                      labelText: "Potwierdź hasło",
                                      filled: true,
                                      fillColor: Colors.transparent,
                                    ),
                                    validator: (value) {
                                      if (showPasswordConfirm) {
                                        if (value == null || value.isEmpty) {
                                          return "Potwierdź hasło";
                                        }
                                        if (passwordController.text != value) {
                                          return "Hasła nie są takie same";
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitRegistration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClassicStyle.my_light_green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Utwórz konto"),
                        ),

                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('lub'),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 14),
                        _buildSocialRegisterButton(
                          label: 'Zarejestruj przez Google',
                          icon: Icons.g_mobiledata,
                          provider: SocialAuthProvider.google,
                        ),
                        const SizedBox(height: 8),
                        _buildSocialRegisterButton(
                          label: 'Zarejestruj przez Outlook',
                          icon: Icons.mail_outline,
                          provider: SocialAuthProvider.outlook,
                        ),
                        const SizedBox(height: 8),
                        _buildSocialRegisterButton(
                          label: 'Zarejestruj przez Apple',
                          icon: Icons.apple,
                          provider: SocialAuthProvider.apple,
                        ),

                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(
                              context,
                            ).push(createSlideFadeRoute(LoginScreen()));
                          },
                          child: const Text(
                            "Masz już konto? Zaloguj się",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: ClassicStyle.my_orange,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
