import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/pending_driver_documents.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

class SmsVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? dni;
  final String? carBrand;
  final String? carPlate;
  final String? carModel;
  final String? carYear;
  final String? soatExpiration;
  final String? propertyCardExpiration;
  final String? technicalReviewExpiration;
  final String? licenseCategory;
  final String? licenseNumber;
  final String? birthDate;

  const SmsVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.role,
    this.firstName,
    this.lastName,
    this.email,
    this.dni,
    this.carBrand,
    this.carPlate,
    this.carModel,
    this.carYear,
    this.soatExpiration,
    this.propertyCardExpiration,
    this.technicalReviewExpiration,
    this.licenseCategory,
    this.licenseNumber,
    this.birthDate,
  });

  @override
  State<SmsVerificationScreen> createState() => _SmsVerificationScreenState();
}

class _SmsVerificationScreenState extends State<SmsVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    AppConstants.smsCodeLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    AppConstants.smsCodeLength,
    (_) => FocusNode(),
  );
  Timer? _resendTimer;
  int _remainingSeconds = AppConstants.smsResendCooldown.inSeconds;
  bool _isVerifying = false;
  Map<String, String>? _pendingDocPaths;
  bool _pendingDocsResolved = false;

  bool get _awaitingPendingDocs =>
      widget.role == 'driver' && !_pendingDocsResolved;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    PendingDriverDocuments.load().then((m) {
      if (mounted) {
        setState(() {
          _pendingDocPaths = m;
          _pendingDocsResolved = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  String get _pinCode {
    return _controllers.map((c) => c.text).join();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _remainingSeconds = AppConstants.smsResendCooldown.inSeconds;

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _handleVerify() async {
    if (_awaitingPendingDocs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cargando documentos, espera un momento'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final code = _pinCode;

    if (code.length != AppConstants.smsCodeLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa el código completo'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isVerifying = false;
      });

      context.read<AuthBloc>().add(VerifyPhoneNumber(widget.phoneNumber));
    }
  }

  void _handleResend() {
    if (_remainingSeconds == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código reenviado'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
      _startResendTimer();
    }
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < AppConstants.smsCodeLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_pinCode.length == AppConstants.smsCodeLength) {
          _handleVerify();
        }
      }
    }
  }

  bool _isDriverFullPackage() {
    bool ne(String? s) => s != null && s.trim().isNotEmpty;
    return widget.role == 'driver' &&
        ne(widget.firstName) &&
        ne(widget.lastName) &&
        ne(widget.email) &&
        ne(widget.dni) &&
        ne(widget.carBrand) &&
        ne(widget.carPlate) &&
        ne(widget.carModel) &&
        ne(widget.carYear) &&
        ne(widget.soatExpiration) &&
        ne(widget.propertyCardExpiration) &&
        ne(widget.technicalReviewExpiration) &&
        ne(widget.licenseCategory) &&
        ne(widget.licenseNumber) &&
        _pendingDocsResolved &&
        PendingDriverDocuments.isComplete(_pendingDocPaths);
  }

  bool _isClientFullPackage() {
    bool ne(String? s) => s != null && s.trim().isNotEmpty;
    return widget.role == 'client' &&
        ne(widget.firstName) &&
        ne(widget.lastName) &&
        ne(widget.email) &&
        ne(widget.dni) &&
        ne(widget.birthDate);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthNeedsRegistration) {
          if (_isDriverFullPackage()) {
            context.push(
              '/register',
              extra: <String, dynamic>{
                'phone': state.phone,
                'role': 'driver',
                'first_name': widget.firstName!.trim(),
                'last_name': widget.lastName!.trim(),
                'email': widget.email!.trim(),
                'dni': widget.dni!.trim(),
                'car_brand': widget.carBrand!.trim(),
                'car_plate': widget.carPlate!.trim(),
                'car_model': widget.carModel!.trim(),
                'car_year': widget.carYear!.trim(),
                'soat_expiration': widget.soatExpiration!.trim(),
                'property_card_expiration':
                    widget.propertyCardExpiration!.trim(),
                'technical_review_expiration':
                    widget.technicalReviewExpiration!.trim(),
                'license_category': widget.licenseCategory!.trim(),
                'license_number': widget.licenseNumber!.trim(),
                if (_pendingDocPaths != null) ..._pendingDocPaths!,
              },
            );
          } else if (_isClientFullPackage()) {
            context.push(
              '/register',
              extra: <String, dynamic>{
                'phone': state.phone,
                'role': 'client',
                'first_name': widget.firstName!.trim(),
                'last_name': widget.lastName!.trim(),
                'email': widget.email!.trim(),
                'dni': widget.dni!.trim(),
                'birth_date': widget.birthDate!.trim(),
              },
            );
          } else {
            context.push('/register', extra: state.phone);
          }
        }
        if (state is AuthAuthenticated) {
          if (state.user.role == 'driver') {
            context.go('/dashboard');
          } else {
            context.go('/client-dashboard');
          }
        }
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new),
            onPressed: () => context.pop(),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Text(
                  'Verificación',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ingresa el código de 6 dígitos que enviamos a',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '+51 ${widget.phoneNumber}',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(flex: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    AppConstants.smsCodeLength,
                    (index) => SizedBox(
                      width: 56,
                      height: 56,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(
                          fontSize: 24,
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: AppTheme.darkSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppTheme.primaryBlue,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (value) => _onChanged(index, value),
                        onTap: () {
                          _controllers[index].selection =
                              TextSelection.fromPosition(
                            TextPosition(
                              offset: _controllers[index].text.length,
                            ),
                          );
                        },
                        onSubmitted: (_) {
                          if (index < AppConstants.smsCodeLength - 1) {
                            _focusNodes[index + 1].requestFocus();
                          } else {
                            _focusNodes[index].unfocus();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isVerifying ? null : _handleVerify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isVerifying
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
                          'Verificar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: _remainingSeconds > 0
                      ? Text(
                          'Reenviar código en ${_remainingSeconds}s',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.darkTextSecondary,
                                  ),
                        )
                      : TextButton(
                          onPressed: _handleResend,
                          child: Text(
                            'Reenviar código',
                            style: TextStyle(
                              color: AppTheme.primaryBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
