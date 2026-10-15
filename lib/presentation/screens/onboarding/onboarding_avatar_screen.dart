import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/onboarding_feedback.dart';

const Color _kBlue = AppTheme.primaryBlue;
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextMuted = Color(0xFF888888);
const Color _kGreen = Color(0xFF00AA44);

/// Avatar que se puede elegir en el onboarding. [gender] es el valor que se
/// guarda en `profiles.gender`, y decide el avatar por defecto del perfil.
typedef _AvatarChoice = ({
  String gender,
  String label,
  IconData icon,
  Color background,
  Color color,
});

const List<_AvatarChoice> _kAvatarChoices = [
  (
    gender: 'male',
    label: 'Hombre',
    icon: Icons.person_rounded,
    background: Color(0xFFE3F2FD),
    color: Color(0xFF1565C0),
  ),
  (
    gender: 'female',
    label: 'Mujer',
    icon: Icons.person_2_rounded,
    background: Color(0xFFFCE4EC),
    color: Color(0xFFC2185B),
  ),
  (
    gender: 'other',
    label: 'Prefiero no decirlo',
    icon: Icons.person_outline_rounded,
    background: Color(0xFFF1F1F1),
    color: Color(0xFF616161),
  ),
];

/// Paso 2 de la creación de cuenta: el avatar (Hombre, Mujer o Prefiero no
/// decirlo). Sigue en el correo (/onboarding/email), donde se crea la
/// cuenta. La foto real se cambia después desde el perfil.
class OnboardingAvatarScreen extends StatefulWidget {
  const OnboardingAvatarScreen({
    super.key,
    required this.name,
    required this.email,
    this.verifiedPhone,
  });

  final String name;

  /// Correo de la cuenta de Google; vacío si se llegó por teléfono.
  final String email;

  /// Teléfono ya verificado por SMS (llegada desde el login por teléfono).
  final String? verifiedPhone;

  @override
  State<OnboardingAvatarScreen> createState() => _OnboardingAvatarScreenState();
}

class _OnboardingAvatarScreenState extends State<OnboardingAvatarScreen> {
  String? _selectedGender;

  String get _firstName {
    final name = widget.name.trim();
    return name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
  }

  _AvatarChoice? get _selected {
    for (final choice in _kAvatarChoices) {
      if (choice.gender == _selectedGender) return choice;
    }
    return null;
  }

  Future<void> _continue() async {
    final gender = _selectedGender;
    if (gender == null) return;
    await playOnboardingFeedback();
    if (!mounted) return;
    final phone = widget.verifiedPhone?.trim() ?? '';
    context.push(
      '/onboarding/email',
      extra: {
        'name': widget.name,
        'email': widget.email,
        'gender': gender,
        if (phone.isNotEmpty) 'phone': phone,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final canContinue = selected != null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera: volver + pasos
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: _kTextDark,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Row(
                      children: [
                        _OnboardingStep(
                          number: 1,
                          label: 'Nombre',
                          isDone: true,
                        ),
                        _StepLine(),
                        _OnboardingStep(
                          number: 2,
                          label: 'Avatar',
                          isActive: true,
                        ),
                        _StepLine(),
                        _OnboardingStep(number: 3, label: 'Correo'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildPreview(selected),
                    const SizedBox(height: 12),
                    Text(
                      _firstName.isEmpty ? '¡Hola!' : '¡Hola, $_firstName!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Elige tu avatar',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: _kTextMuted),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _kAvatarChoices.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _AvatarChoiceCard(
                              choice: _kAvatarChoices[i],
                              isSelected: _kAvatarChoices[i].gender ==
                                  _selectedGender,
                              onTap: () => setState(
                                () => _selectedGender =
                                    _kAvatarChoices[i].gender,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Podrás poner tu foto más adelante desde tu perfil.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: _kTextMuted),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: GestureDetector(
                onTap: canContinue ? _continue : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: canContinue
                        ? const LinearGradient(
                            colors: [Color(0xFF0055BB), Color(0xFF0099FF)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
                        : null,
                    color: canContinue ? null : const Color(0xFFEEEEEE),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: canContinue
                        ? const [
                            BoxShadow(
                              color: Color(0x440066CC),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : const [],
                  ),
                  child: Center(
                    child: Text(
                      canContinue ? 'Continuar' : 'Elige un avatar',
                      style: TextStyle(
                        color: canContinue
                            ? Colors.white
                            : const Color(0xFF999999),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista previa grande del avatar elegido.
  Widget _buildPreview(_AvatarChoice? selected) {
    return Center(
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected?.background ?? const Color(0xFFEEF5FF),
              border: Border.all(color: _kBlue, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _kBlue.withValues(alpha: 0.2),
                  blurRadius: 16,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                selected?.icon ?? Icons.person_rounded,
                key: ValueKey(selected?.gender),
                color: selected?.color ?? _kBlue,
                size: 64,
              ),
            ),
          ),
          if (selected != null)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de un avatar: círculo con el ícono y su etiqueta. Elegida, se
/// marca con borde azul y check.
class _AvatarChoiceCard extends StatelessWidget {
  const _AvatarChoiceCard({
    required this.choice,
    required this.isSelected,
    required this.onTap,
  });

  final _AvatarChoice choice;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF5FF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _kBlue : const Color(0xFFE0E0E0),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? const [BoxShadow(color: Color(0x330066CC), blurRadius: 8)]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: choice.background,
              ),
              child: Icon(choice.icon, color: choice.color, size: 38),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: Center(
                child: Text(
                  choice.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? _kBlue : _kTextDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? _kBlue : const Color(0xFFCCCCCC),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Paso del indicador de la cabecera: hecho (verde con check), activo
/// (azul) o pendiente (gris).
class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.number,
    required this.label,
    this.isActive = false,
    this.isDone = false,
  });

  final int number;
  final String label;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final Color circle;
    final Color text;
    if (isDone) {
      circle = _kGreen;
      text = _kGreen;
    } else if (isActive) {
      circle = _kBlue;
      text = _kBlue;
    } else {
      circle = const Color(0xFFEEEEEE);
      text = const Color(0xFFAAAAAA);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(shape: BoxShape.circle, color: circle),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                : Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.white : const Color(0xFFAAAAAA),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                isActive || isDone ? FontWeight.w600 : FontWeight.w400,
            color: text,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: const Color(0xFFEEEEEE),
      ),
    );
  }
}
