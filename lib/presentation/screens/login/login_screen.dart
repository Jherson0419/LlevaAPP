import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  bool _isPhoneFocused = false;

  late final AnimationController _entryController;
  late final Animation<double> _cardSlide;
  late final Animation<double> _cardFade;
  late final TapGestureRecognizer _createAccountTap;

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(() {
      setState(() {
        _isPhoneFocused = _phoneFocusNode.hasFocus;
      });
    });

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

    _createAccountTap = TapGestureRecognizer()
      ..onTap = () => context.push('/onboarding/welcome');
  }

  @override
  void dispose() {
    _entryController.dispose();
    _createAccountTap.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  void _handleContinue() {
    final phoneNumber = _phoneController.text.trim();

    if (phoneNumber.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un número de celular válido'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    // Cualquier número válido continúa al flujo de verificación SMS.
    // El AuthBloc consultará en Supabase si el perfil existe o no.
    context.push('/sms-verification?phone=$phoneNumber&role=');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      // LoginScreen sigue montada debajo de /sms-verification y del
      // onboarding (que escuchan el mismo AuthBloc y navegan por su cuenta);
      // aquí solo se atiende lo que ocurre con esta pantalla visible, es
      // decir, el inicio de sesión con Google.
      listenWhen: (_, __) => ModalRoute.of(context)?.isCurrent ?? true,
      listener: (context, state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
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
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _blue,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Trujillo, Perú',
              style: TextStyle(
                color: _blue,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Bienvenido a Lleva',
          style: TextStyle(
            color: _textDark,
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Text(
          'Inicia sesión para reservar\nun viaje en segundos.',
          style: TextStyle(
            color: Color(0xFF888888),
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // Campo de número de celular
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F6FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _blue, width: 1.5),
            boxShadow: _isPhoneFocused
                ? const [
                    BoxShadow(
                      color: Color(0x220066CC),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: const BoxDecoration(
                  border: Border(
                    right: BorderSide(color: Color(0xFFDDEEFF), width: 1.5),
                  ),
                ),
                child: const Text(
                  '+51',
                  style: TextStyle(
                    color: _blue,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  cursorColor: _blue,
                  style: const TextStyle(color: _textDark, fontSize: 18),
                  // El borde y el relleno los pinta el contenedor; aquí se
                  // anula lo que aporta inputDecorationTheme.
                  decoration: const InputDecoration(
                    filled: false,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '999 999 999',
                    hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Te enviaremos un código de verificación',
          style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
        ),

        const SizedBox(height: 20),

        // Botón Continuar
        Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0055BB), Color(0xFF0099FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Color(0x440066CC),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleContinue,
              borderRadius: BorderRadius.circular(12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Continuar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Divider con texto
        const Row(
          children: [
            Expanded(child: Divider(color: Color(0xFFEEEEEE))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'o continúa con',
                style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 12),
              ),
            ),
            Expanded(child: Divider(color: Color(0xFFEEEEEE))),
          ],
        ),

        const SizedBox(height: 16),

        // Botones sociales
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                icon: Icons.g_mobiledata,
                iconColor: const Color(0xFF4285F4),
                label: 'Google',
                onTap: () {
                  context.read<AuthBloc>().add(const GoogleSignInRequested());
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SocialButton(
                icon: Icons.apple,
                iconColor: _textDark,
                label: 'Apple',
                // TODO: inicio de sesión con Apple.
                onTap: () {},
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        Center(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 14),
              children: [
                const TextSpan(
                  text: '¿No tienes cuenta? ',
                  style: TextStyle(color: Color(0xFF888888)),
                ),
                TextSpan(
                  text: 'Crear cuenta',
                  style: const TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w600,
                  ),
                  recognizer: _createAccountTap,
                ),
              ],
            ),
          ),
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
