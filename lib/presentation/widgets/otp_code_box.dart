import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

/// Casilla de un dígito del código OTP, compartida por SmsVerificationScreen
/// y OnboardingCodeScreen: fondo blanco, borde gris que pasa a azul (con
/// sombra suave) mientras tiene el foco.
class OtpCodeBox extends StatelessWidget {
  const OtpCodeBox({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.width,
    required this.height,
    required this.fontSize,
    required this.onChanged,
    this.onTap,
    this.onSubmitted,
  });

  static const Color _inactiveBorder = Color(0xFFE0E0E0);
  static const Color _textColor = Color(0xFF1A1A1A);

  final TextEditingController controller;
  final FocusNode focusNode;
  final double width;
  final double height;
  final double fontSize;
  final ValueChanged<String> onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, child) {
        final active = focusNode.hasFocus;
        return Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? AppTheme.primaryBlue : _inactiveBorder,
              width: 2,
            ),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x220066CC),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        cursorColor: AppTheme.primaryBlue,
        style: TextStyle(
          fontSize: fontSize,
          color: _textColor,
          fontWeight: FontWeight.w600,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        // El borde y el fondo los pinta el Container; aquí se anula lo que
        // aporta inputDecorationTheme (relleno y bordes propios).
        decoration: const InputDecoration(
          counterText: '',
          filled: false,
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: onChanged,
        onTap: onTap,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
