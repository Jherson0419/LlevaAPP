import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const Color _blue = AppTheme.primaryBlue;
  static const Color _textDark = Color(0xFF1A1A1A);
  static const double _cardCornerRadius = 28;

  final GlobalKey<FormState> _emailFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// true mientras el AuthBloc procesa el login con correo (para el spinner
  /// del botón; Google también pasa por AuthLoading).
  bool _emailSubmitting = false;

  late final AnimationController _entryController;
  late final Animation<double> _cardSlide;
  late final Animation<double> _cardFade;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _cardSlide = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
    );
    _cardFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
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

  InputDecoration _emailFieldDecoration({
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
        backgroundColor: Colors.white,
        // El teclado no encoge el body: la tarjeta sube sola sobre él (ver
        // `bottom` abajo) y el fondo queda fijo detrás.
        resizeToAvoidBottomInset: false,
        body: Builder(
          builder: (context) {
            final screenHeight = MediaQuery.sizeOf(context).height;
            final keyboard = MediaQuery.viewInsetsOf(context).bottom;
            final topSafe = MediaQuery.paddingOf(context).top;
            // 70% de la pantalla; con el teclado abierto se recorta para no
            // salirse por arriba (deja visible una franja del degradado). El
            // contenido sobrante se desplaza dentro de la tarjeta.
            final cardHeight = math.min(
              screenHeight * 0.7,
              screenHeight - keyboard - topSafe - 24,
            );
            return Stack(
              children: [
                // Capa 1: video (o degradado mientras carga) fijo en el 30%
                // superior. Se prolonga un poco por debajo de la tarjeta para
                // que se vea detrás de sus esquinas redondeadas.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: screenHeight * 0.3 + _cardCornerRadius,
                  child: const _VideoBackground(),
                ),
                // Capa 2: tarjeta pegada encima del teclado. viewInsets ya
                // cambia cuadro a cuadro con la animación del teclado, así
                // que la tarjeta lo acompaña sin animación propia.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: keyboard,
                  height: cardHeight,
                  child: AnimatedBuilder(
                    animation: _entryController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _cardFade.value,
                        child: Transform.translate(
                          offset: Offset(0, 400 * (1 - _cardSlide.value)),
                          child: child,
                        ),
                      );
                    },
                    child: _buildLoginCard(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_cardCornerRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        // Sin el inset del teclado: la tarjeta ya está posicionada encima de
        // él (sumarlo dejaría un hueco en blanco).
        padding: EdgeInsets.fromLTRB(
          28,
          28,
          28,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        child: _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Login con correo y contraseña
        Form(
          key: _emailFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                cursorColor: _blue,
                style: const TextStyle(color: _textDark, fontSize: 16),
                decoration: _emailFieldDecoration(
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _handleEmailLogin(),
                cursorColor: _blue,
                style: const TextStyle(color: _textDark, fontSize: 16),
                decoration: _emailFieldDecoration(
                  hint: 'Contraseña',
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFF888888),
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
        ),

        const SizedBox(height: 16),

        // Botón Ingresar con email
        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: _emailSubmitting ? null : _handleEmailLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _blue.withValues(alpha: 0.6),
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
                    'Ingresar con email',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        TextButton(
          onPressed: () => context.push('/register-email'),
          child: const Text(
            'Crear cuenta con email',
            style: TextStyle(color: _blue, fontWeight: FontWeight.w600),
          ),
        ),

        const SizedBox(height: 8),

        _SocialButton(
          icon: Icons.g_mobiledata,
          iconColor: const Color(0xFF4285F4),
          label: 'Continuar con Google',
          onTap: () {
            context.read<AuthBloc>().add(const GoogleSignInRequested());
          },
        ),
        const SizedBox(height: 12),
        _SocialButton(
          icon: Icons.apple,
          iconColor: _textDark,
          label: 'Continuar con Apple',
          // TODO: inicio de sesión con Apple.
          onTap: () {},
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF444444),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fondo del login: video de Trujillo en bucle, sin sonido y recortado para
/// llenar el espacio. Mientras carga (o si no se puede reproducir) muestra el
/// degradado azul de la marca.
class _VideoBackground extends StatefulWidget {
  const _VideoBackground();

  @override
  State<_VideoBackground> createState() => _VideoBackgroundState();
}

class _VideoBackgroundState extends State<_VideoBackground> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/film/Trujillo.mp4');
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
      _controller.setLooping(true);
      _controller.setVolume(0.0);
      _controller.play();
    }).catchError((Object _) {
      // Video ausente o no reproducible: queda el degradado.
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0033AA), Color(0xFF0066CC), Color(0xFF0099FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SizedBox.expand(),
      );
    }
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
