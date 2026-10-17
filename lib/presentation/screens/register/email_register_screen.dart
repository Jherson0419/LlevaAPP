import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

/// Alta con correo y contraseña (Supabase Auth `signUp`). Solo crea la cuenta
/// de Auth: el perfil se completa en el onboarding (nombre → avatar → correo),
/// igual que con Google.
class EmailRegisterScreen extends StatefulWidget {
  const EmailRegisterScreen({super.key});

  @override
  State<EmailRegisterScreen> createState() => _EmailRegisterScreenState();
}

class _EmailRegisterScreenState extends State<EmailRegisterScreen> {
  static const Color _blue = AppTheme.primaryBlue;
  static const Color _textDark = Color(0xFF1A1A1A);
  static const int _minPasswordLength = 6;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
          SignUpWithEmailPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  Future<void> _showConfirmationDialog(String email) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirma tu correo'),
        content: Text(
          'Te enviamos un enlace a $email. Ábrelo para activar tu cuenta y '
          'luego inicia sesión con tu correo y contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
    if (mounted) context.pop();
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        );
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF0F6FF),
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
      prefixIcon: Icon(icon, color: _blue, size: 20),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      border: border(_blue),
      enabledBorder: border(_blue),
      focusedBorder: border(_blue),
      errorBorder: border(AppTheme.errorRed),
      focusedErrorBorder: border(AppTheme.errorRed),
    );
  }

  Widget _visibilityToggle() {
    return IconButton(
      icon: Icon(
        _obscurePassword
            ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
        color: const Color(0xFF888888),
        size: 20,
      ),
      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (_, __) => ModalRoute.of(context)?.isCurrent ?? true,
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              // 10 s para poder leer el error completo de Supabase.
              duration: const Duration(seconds: 10),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        } else if (state is AuthEmailConfirmationSent) {
          _showConfirmationDialog(state.email);
        } else if (state is AuthNeedsRegistration) {
          // Sesión abierta y sin perfil: sigue el onboarding con el correo
          // ya rellenado.
          context.pushReplacement(
            '/onboarding/name',
            extra: {'name': '', 'email': state.prefilledEmail},
          );
        } else if (state is AuthAuthenticated) {
          // El correo ya tenía perfil (alta previa por teléfono o Google).
          context.go(
            '/splash/returning-user',
            extra: {'userName': state.user.fullName},
          );
        }
      },
      builder: (context, state) {
        final loading = state is AuthLoading;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: _textDark,
            elevation: 0,
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Crear cuenta',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Regístrate con tu correo y una contraseña.',
                      style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.email],
                      cursorColor: _blue,
                      style: const TextStyle(color: _textDark, fontSize: 16),
                      decoration: _decoration(
                        hint: 'correo@ejemplo.com',
                        icon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty ||
                            !email.contains('@') ||
                            !email.contains('.')) {
                          return 'Ingresa un correo válido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                      cursorColor: _blue,
                      style: const TextStyle(color: _textDark, fontSize: 16),
                      decoration: _decoration(
                        hint: 'Contraseña',
                        icon: Icons.lock_outline,
                        suffix: _visibilityToggle(),
                      ),
                      validator: (value) {
                        if ((value ?? '').length < _minPasswordLength) {
                          return 'Mínimo $_minPasswordLength caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSubmit(),
                      cursorColor: _blue,
                      style: const TextStyle(color: _textDark, fontSize: 16),
                      decoration: _decoration(
                        hint: 'Confirmar contraseña',
                        icon: Icons.lock_outline,
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: loading ? null : _handleSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              _blue.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Crear cuenta',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
