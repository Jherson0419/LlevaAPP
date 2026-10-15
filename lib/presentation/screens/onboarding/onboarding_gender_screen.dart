import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/onboarding_feedback.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';

class OnboardingGenderScreen extends StatefulWidget {
  const OnboardingGenderScreen({
    super.key,
    required this.name,
    this.verifiedPhone,
  });

  final String name;

  /// Teléfono ya verificado por SMS (llegada desde el login). Si viene, se
  /// salta los pasos de teléfono y código y se continúa en el correo.
  final String? verifiedPhone;

  @override
  State<OnboardingGenderScreen> createState() => _OnboardingGenderScreenState();
}

class _OnboardingGenderScreenState extends State<OnboardingGenderScreen> {
  String? _selectedGender;

  Future<void> _handleContinue() async {
    final gender = _selectedGender;
    if (gender == null) return;
    await playOnboardingFeedback();
    if (!mounted) return;
    final verifiedPhone = widget.verifiedPhone?.trim() ?? '';
    if (verifiedPhone.isNotEmpty) {
      context.push(
        '/onboarding/email',
        extra: {'name': widget.name, 'phone': verifiedPhone, 'gender': gender},
      );
    } else {
      context.push(
        '/onboarding/phone',
        extra: {'name': widget.name, 'gender': gender},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      activeStep: 2,
      icon: Icons.wc_rounded,
      title: '¿Cuál es tu género?',
      subtitle: 'Esto nos ayuda a personalizar\ntu experiencia.',
      buttonText: 'Continuar',
      // null deshabilita el botón (el scaffold lo pinta al 50 %).
      onButtonPressed: _selectedGender == null ? null : _handleContinue,
      content: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            _buildOption(
              value: 'male',
              label: 'Masculino',
              icon: Icons.male_rounded,
            ),
            _buildOption(
              value: 'female',
              label: 'Femenino',
              icon: Icons.female_rounded,
            ),
            _buildOption(
              value: 'other',
              label: 'Prefiero no decir',
              icon: Icons.person_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF5FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : const Color(0xFFE0E0E0),
            width: isSelected ? 2.0 : 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryBlue : const Color(0xFF888888),
              size: 28,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    isSelected ? AppTheme.primaryBlue : const Color(0xFF1A1A1A),
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryBlue,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
