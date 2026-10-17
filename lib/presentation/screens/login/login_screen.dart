import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _blue = AppTheme.primaryBlue;
  static const Color _textPrimary = AppTheme.lightTextPrimary;
  static const Color _textSecondary = AppTheme.lightTextSecondary;

  final GlobalKey<FormState> _emailFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// true mientras el AuthBloc procesa el login con correo (para el spinner
  /// del botón; Google también pasa por AuthLoading).
  bool _emailSubmitting = false;

  late final TapGestureRecognizer _createAccountTap;

  @override
  void initState() {
    super.initState();
    _createAccountTap = TapGestureRecognizer()
      ..onTap = () => context.push('/register-email');
  }

  @override
  void dispose() {
    _createAccountTap.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleEmailLogin() {
    if (!(_emailFormKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _emailSubmitting = true);
    context.read<AuthBloc>().add(
          LoginWithEmailPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  InputDecoration _fieldDecoration({required String hint, Widget? suffix}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      filled: true,
      fillColor: AppTheme.lightSurface,
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(AppTheme.lightBorder),
      enabledBorder: border(AppTheme.lightBorder),
      focusedBorder: border(_blue, 1.5),
      errorBorder: border(AppTheme.errorRed),
      focusedErrorBorder: border(AppTheme.errorRed, 1.5),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      // LoginScreen sigue montada debajo de /register-email y del
      // onboarding (que escuchan el mismo AuthBloc y navegan por su cuenta);
      // aquí solo se atiende lo que ocurre con esta pantalla visible, es
      // decir, el inicio de sesión con correo o con Google.
      listenWhen: (_, __) => ModalRoute.of(context)?.isCurrent ?? true,
      listener: (context, state) {
        if (state is! AuthLoading && _emailSubmitting) {
          setState(() => _emailSubmitting = false);
        }
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              // 10 s para poder leer el error completo de Supabase.
              duration: const Duration(seconds: 10),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        } else if (state is AuthAuthenticated) {
          context.go(
            '/splash/returning-user',
            extra: {'userName': state.user.fullName},
          );
        } else if (state is AuthNeedsRegistration) {
          // Usuario nuevo de Google: el correo ya viene de su cuenta, solo
          // falta el nombre.
          context.push(
            '/onboarding/name',
            extra: {'name': '', 'email': state.prefilledEmail},
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.lightBackground,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // minHeight = alto visible: el "¿No tienes cuenta?" queda al
              // fondo y, con el teclado abierto, todo se desplaza.
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 48),
                        _buildHeader(),
                        const SizedBox(height: 36),
                        _buildForm(),
                        const SizedBox(height: 24),
                        _buildContinueButton(),
                        const SizedBox(height: 24),
                        _buildDivider(),
                        const SizedBox(height: 24),
                        _buildSocialButtons(),
                        const Spacer(),
                        const SizedBox(height: 24),
                        _buildCreateAccount(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      children: [
        Icon(Icons.location_on, color: _blue, size: 56),
        SizedBox(height: 16),
        Text(
          'Bienvenido a Lleva',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Inicia sesión para reservar viajes',
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('Correo electrónico'),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            autofillHints: const [AutofillHints.email],
            cursorColor: _blue,
            style: const TextStyle(color: _textPrimary, fontSize: 16),
            decoration: _fieldDecoration(hint: 'correo@ejemplo.com'),
            validator: (value) {
              final email = value?.trim() ?? '';
              if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
                return 'Ingresa un correo válido';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _fieldLabel('Contraseña'),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _handleEmailLogin(),
            cursorColor: _blue,
            style: const TextStyle(color: _textPrimary, fontSize: 16),
            decoration: _fieldDecoration(
              hint: '••••••••',
              suffix: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _textSecondary,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if ((value ?? '').isEmpty) return 'Ingresa tu contraseña';
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _emailSubmitting ? null : _handleEmailLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _blue.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _emailSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Continuar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppTheme.lightBorder)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'o',
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.lightBorder)),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            icon: const SizedBox(
              width: 20,
              height: 20,
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            label: 'Google',
            onTap: () {
              context.read<AuthBloc>().add(const GoogleSignInRequested());
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            icon: const Icon(Icons.apple, color: _textPrimary, size: 24),
            label: 'Apple',
            // TODO: inicio de sesión con Apple.
            onTap: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildCreateAccount() {
    return Center(
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 14),
          children: [
            const TextSpan(
              text: '¿No tienes cuenta? ',
              style: TextStyle(color: _textSecondary),
            ),
            TextSpan(
              text: 'Crear una',
              style: const TextStyle(
                color: _blue,
                fontWeight: FontWeight.w600,
              ),
              recognizer: _createAccountTap,
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.lightTextPrimary,
          backgroundColor: AppTheme.lightBackground,
          side: const BorderSide(color: AppTheme.lightBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "G" de Google en sus cuatro colores, dibujada a mano para no depender de
/// un asset ni de un paquete de SVG.
class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);
  static const Color _blue = Color(0xFF4285F4);

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.22;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;

    double rad(double deg) => deg * math.pi / 180;

    // Ángulos en grados, 0° = derecha, sentido horario.
    canvas.drawArc(rect, rad(-40), rad(-100), false, paint..color = _red);
    canvas.drawArc(rect, rad(-140), rad(-90), false, paint..color = _yellow);
    canvas.drawArc(rect, rad(130), rad(-100), false, paint..color = _green);
    canvas.drawArc(rect, rad(30), rad(-30), false, paint..color = _blue);

    // Barra horizontal de la G.
    final center = size.center(Offset.zero);
    canvas.drawRect(
      Rect.fromLTRB(
        center.dx,
        center.dy - stroke / 2,
        size.width,
        center.dy + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
