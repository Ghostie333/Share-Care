import 'package:flutter/material.dart';
import '../../utils/animations.dart';
import 'auth_registration_page.dart';
import '../../core/classic_style.dart';
import '../../services/auth_service.dart';
import '../home/home_page.dart';

class LoginScreen extends StatefulWidget {
  final void Function(AuthResult)? onLoginSuccess;

  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;
  SocialAuthProvider? _socialLoadingProvider;

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
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!(result);
      } else {
        Navigator.of(
          context,
        ).pushReplacement(createSlideFadeRoute(HomePage(authResult: result)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Błąd logowania: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitSocialLogin(SocialAuthProvider provider) async {
    setState(() => _socialLoadingProvider = provider);

    try {
      final result = await AuthService.loginWithSocial(provider: provider);
      if (!mounted) return;
      if (widget.onLoginSuccess != null) {
        widget.onLoginSuccess!(result);
      } else {
        Navigator.of(
          context,
        ).pushReplacement(createSlideFadeRoute(HomePage(authResult: result)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd logowania społecznościowego: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _socialLoadingProvider = null);
      }
    }
  }

  Widget _buildSocialButton({
    required String label,
    required IconData icon,
    required SocialAuthProvider provider,
  }) {
    final isLoading = _socialLoadingProvider == provider;

    return OutlinedButton.icon(
      onPressed: (_isLoading || _socialLoadingProvider != null)
          ? null
          : () => _submitSocialLogin(provider),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClassicStyle.my_light_green,
      appBar: AppBar(
        elevation: 0,
        title: const Text('Logowanie'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              // Brak poprzedniej strony w stosie – wróć na stronę główną jako gość.
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
                        const Text("Logowanie", style: ClassicStyle.title),

                        const SizedBox(height: 20),
                        TextFormField(
                          controller: emailController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: "Email",
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          cursorColor: Theme.of(context).colorScheme.primary,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Podaj email";
                            }
                            // Ten sam wzorzec jak w rejestracji, bez błędnego \$ na końcu,
                            // żeby prawidłowe adresy nie były odrzucane.
                            final emailRegex = RegExp(
                              r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,4}$',
                            );
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
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) {
                              _submitLogin();
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: "Hasło",
                            filled: true,
                            fillColor: Colors.transparent,
                          ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
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
                              : const Text("Zaloguj się"),
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
                        _buildSocialButton(
                          label: 'Kontynuuj z Google',
                          icon: Icons.g_mobiledata,
                          provider: SocialAuthProvider.google,
                        ),
                        const SizedBox(height: 8),
                        _buildSocialButton(
                          label: 'Kontynuuj z Outlook',
                          icon: Icons.mail_outline,
                          provider: SocialAuthProvider.outlook,
                        ),
                        const SizedBox(height: 8),
                        _buildSocialButton(
                          label: 'Kontynuuj z Apple',
                          icon: Icons.apple,
                          provider: SocialAuthProvider.apple,
                        ),

                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(
                              context,
                            ).push(createSlideFadeRoute(RegistrationScreen()));
                          },
                          child: const Text(
                            "Nie masz konta? Zarejestruj się",
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
