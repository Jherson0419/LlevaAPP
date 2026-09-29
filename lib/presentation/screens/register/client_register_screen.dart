import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/age_validation.dart';

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _phoneController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dniController = TextEditingController();
  final _emailController = TextEditingController();

  DateTime? _birthDate;

  bool _isLoading = false;
  bool _acceptTerms = false;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _phoneController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ThemeData _pickerTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppTheme.primaryBlue,
        onPrimary: Colors.black,
        surface: AppTheme.darkSurface,
        onSurface: AppTheme.darkText,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppTheme.darkSurface,
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final maxDate = AgeValidation.maxBirthDateForMinimumAge(18);
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? maxDate,
      firstDate: DateTime(1920),
      lastDate: maxDate,
      helpText: 'Debes tener al menos 18 años',
      builder: (ctx, child) =>
          Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona tu fecha de nacimiento'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (!AgeValidation.isAtLeastYearsOld(_birthDate!, 18)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes tener al menos 18 años para registrarte'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes aceptar los términos y condiciones'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _isLoading = false);

    final uri = Uri(
      path: '/sms-verification',
      queryParameters: {
        'phone': _phoneController.text.trim(),
        'role': 'client',
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'dni': _dniController.text.trim(),
        'email': _emailController.text.trim(),
        'birth_date': _birthDate!.toUtc().toIso8601String(),
      },
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Registro de Usuario'),
      ),
      body: Form(
        key: _formKey,
        child: Scrollbar(
          controller: _scrollController,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Únete a Lleva',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea tu cuenta y comienza a viajar',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(9),
                  ],
                  style: TextStyle(color: colors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Teléfono',
                    labelStyle:
                        TextStyle(color: colors.textSecondary),
                    filled: true,
                    fillColor: colors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 16, right: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '+51',
                            style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 24,
                            margin: const EdgeInsets.only(left: 12),
                            color: colors.textSecondary
                                .withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa tu número de celular';
                    }
                    if (v.trim().length != 9) return 'Debe tener 9 dígitos';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: _fieldDeco('Nombre', Icons.person_outline),
                  validator: (v) {
                    if (v == null || v.trim().length < 2) {
                      return 'Ingresa tu nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: colors.textPrimary),
                  decoration: _fieldDeco('Apellidos', Icons.person_outline),
                  validator: (v) {
                    if (v == null || v.trim().length < 2) {
                      return 'Ingresa tus apellidos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dniController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(8),
                  ],
                  style: TextStyle(color: colors.textPrimary),
                  decoration: _fieldDeco('DNI', Icons.badge_outlined),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.length != 8) return 'DNI debe tener 8 dígitos';
                    if (int.tryParse(s) == null) return 'Solo números';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: colors.textPrimary),
                  decoration:
                      _fieldDeco('Correo electrónico', Icons.email_outlined),
                  validator: (v) {
                    final s = v?.trim() ?? '';
                    if (s.isEmpty) return 'Ingresa tu correo';
                    if (!s.contains('@') || !s.contains('.')) {
                      return 'Correo no válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickBirthDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _fieldDeco(
                      'Fecha de nacimiento',
                      Icons.cake_outlined,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        _birthDate != null
                            ? _dateFmt.format(_birthDate!)
                            : 'Toca para seleccionar (mayor de 18 años)',
                        style: TextStyle(
                          color: _birthDate != null
                              ? colors.textPrimary
                              : colors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _acceptTerms,
                      onChanged: (v) =>
                          setState(() => _acceptTerms = v ?? false),
                      activeColor: AppTheme.primaryBlue,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _acceptTerms = !_acceptTerms),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: RichText(
                            text: TextSpan(
                              style: Theme.of(context).textTheme.bodyMedium,
                              children: [
                                const TextSpan(text: 'Acepto los '),
                                TextSpan(
                                  text: 'términos y condiciones',
                                  style: const TextStyle(
                                    color: AppTheme.primaryBlue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const TextSpan(text: ' y la '),
                                TextSpan(
                                  text: 'política de privacidad',
                                  style: const TextStyle(
                                    color: AppTheme.primaryBlue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          'Continuar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium,
                        children: [
                          const TextSpan(text: '¿Ya tienes cuenta? '),
                          TextSpan(
                            text: 'Inicia sesión',
                            style: const TextStyle(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
  }

  InputDecoration _fieldDeco(String label, IconData icon) {
    final colors = AppTheme.of(context);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textSecondary),
      prefixIcon: Icon(icon, color: AppTheme.primaryBlue),
      filled: true,
      fillColor: colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
