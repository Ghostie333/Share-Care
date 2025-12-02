import 'package:flutter/material.dart';
import '../utils/animations.dart';
import 'login_screen.dart';
import '../styles/classic_style.dart';
import 'package:flutter/services.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;

class RegistrationScreen extends StatefulWidget {
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
  final postCodeController = TextEditingController();
  final emailController = TextEditingController();
  final emailConfirmController = TextEditingController();
  final passwordController = TextEditingController();
  final passwordConfirmController = TextEditingController();

  bool showEmailConfirm = false;
  bool showPasswordConfirm = false;
  
  bool _isLoading = false;

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

    final body = {
      "Email": emailController.text.trim(),
      "Password": passwordController.text, // serwer zahashuje
      "FirstName": firstNameController.text.trim(),
      "LastName": lastNameController.text.trim(),
    };

    // DOSTOSUJ: adres backendu (emulator Android: 10.0.2.2)
    const backendBase = 'http://10.0.2.2:8080';
    final uri = Uri.parse('$backendBase/UserRegistration/user-registry');

    try {
      final res = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body));

      if (res.statusCode == 200) {
        // powodzenie
        if (!mounted) return;
        showDialog(
            context: context,
            builder: (_) => AlertDialog(
                  title: const Text('Sukces'),
                  content: const Text('Rejestracja zakończona pomyślnie.'),
                  actions: [
                    TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context)
                              .push(createSlideFadeRoute(LoginScreen()));
                        },
                        child: const Text('OK'))
                  ],
                ));
      } else if (res.statusCode == 409) {
        // konflikt: już istnieje
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Email już istnieje')));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Błąd serwera: ${res.statusCode} ${res.body}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Błąd: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClassicStyle.my_dark_green,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: <Widget>[
                  Container(
                    width: MediaQuery.of(context).size.width * 0.5,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white,
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
                        const Text(
                          "Rejestracja",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),

                        // Row: Imię i Nazwisko
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: firstNameController,
                                decoration: const InputDecoration(
                                  labelText: "Imię",
                                  filled: true,
                                  fillColor: Colors.white,
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
                                  fillColor: Colors.white,
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
                          decoration: const InputDecoration(
                            labelText: "Email",
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj email";
                            }
                            final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,4}$');
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
                                    decoration: const InputDecoration(
                                      labelText: "Potwierdź email",
                                      filled: true,
                                      fillColor: Colors.white,
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
                          decoration: const InputDecoration(
                            labelText: "Numer Telefonu",
                            filled: true,
                            fillColor: Colors.white,
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
                          decoration: const InputDecoration(
                            labelText: "Data urodzenia (DD.MM.RRRR)",
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj datę urodzenia";
                            }
                            final dateRegex =
                                RegExp(r'^\d{2}\.\d{2}\.\d{4}$');
                            if (!dateRegex.hasMatch(value)) {
                              return "Format daty: DD.MM.RRRR";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressNameController,
                          decoration: const InputDecoration(
                            labelText: "Adres zamieszkania (miasto)",
                            filled: true,
                            fillColor: Colors.white,
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
                          controller: postCodeController,
                          decoration: const InputDecoration(
                            labelText: "Kod pocztowy (NN-NNN)",
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj kod pocztowy";
                            }
                            final postRegex =
                                RegExp(r'^[0-9]{2}-[0-9]{3}$');
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
                          decoration: const InputDecoration(
                            labelText: "Hasło",
                            filled: true,
                            fillColor: Colors.white,
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
                                    decoration: const InputDecoration(
                                      labelText: "Potwierdź hasło",
                                      filled: true,
                                      fillColor: Colors.white,
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
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          child: _isLoading
                          ? const SizedBox(
                              height: 20, 
                              width: 20, 
                              child: 
                              CircularProgressIndicator(strokeWidth: 2, 
                              color: Colors.white)
                          )
                          : const Text("Utwórz konto"),
                        ),

                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context)
                                .push(createSlideFadeRoute(LoginScreen()));
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
