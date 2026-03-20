import 'package:flutter/material.dart';
import '../../utils/animations.dart';
import 'auth_registration_page.dart';
import '../../core/classic_style.dart';
import '../../services/auth_service.dart';
import '../home/widgets/profile_page.dart';


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.login(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        createSlideFadeRoute(ProfileScreen(authResult: result)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd logowania: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        const SizedBox(height: 20),
                        const Text(
                          "Logowanie",
                          style: ClassicStyle.title,
                        ),

                        const SizedBox(height: 20),
                        TextFormField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            filled: true, 
                            fillColor: Colors.transparent,
                          ),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          cursorColor: Theme.of(context).colorScheme.primary,
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

                        const SizedBox(height: 5),
                        TextFormField(
                         controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Hasło",
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          cursorColor: Theme.of(context).colorScheme.primary,
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

                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitLogin,
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Zaloguj się"),
                        ),

                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context)
                                .push(createSlideFadeRoute(RegistrationScreen()));
                          },
                          child: const Text(
                            "Nie masz konta? Zarejestruj się",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: ClassicStyle.my_orange,
                                decoration: TextDecoration.underline
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
