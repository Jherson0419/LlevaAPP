import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/age_validation.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

const _kLicenseCategories = ['A-I', 'A-IIa', 'A-IIb', 'A-III'];

class RegisterProfileScreen extends StatefulWidget {
  final String phone;

  /// Nombre completo recogido en el flujo de onboarding (OnboardingNameScreen).
  /// Si no está vacío, el campo "Nombre completo" se muestra precargado y
  /// de solo lectura.
  final String prefilledName;
  final String? prefilledRole;
  final String? prefilledFirstName;
  final String? prefilledLastName;
  final String? prefilledEmail;
  final String? prefilledDni;
  final DateTime? prefilledBirthDate;
  final String? prefilledCarBrand;
  final String? prefilledCarPlate;
  final String? prefilledCarModel;
  final int? prefilledCarYear;
  final DateTime? prefilledSoatExpiration;
  final DateTime? prefilledPropertyCardExpiration;
  final DateTime? prefilledTechnicalReviewExpiration;
  final String? prefilledLicenseCategory;
  final String? prefilledLicenseNumber;
  final String? prefilledDniFrontLocalPath;
  final String? prefilledDniBackLocalPath;
  final String? prefilledLicenseLocalPath;
  final String? prefilledSoatLocalPath;
  final String? prefilledPropertyCardLocalPath;
  final String? prefilledProfilePicLocalPath;

  const RegisterProfileScreen({
    super.key,
    required this.phone,
    this.prefilledName = '',
    this.prefilledRole,
    this.prefilledFirstName,
    this.prefilledLastName,
    this.prefilledEmail,
    this.prefilledDni,
    this.prefilledBirthDate,
    this.prefilledCarBrand,
    this.prefilledCarPlate,
    this.prefilledCarModel,
    this.prefilledCarYear,
    this.prefilledSoatExpiration,
    this.prefilledPropertyCardExpiration,
    this.prefilledTechnicalReviewExpiration,
    this.prefilledLicenseCategory,
    this.prefilledLicenseNumber,
    this.prefilledDniFrontLocalPath,
    this.prefilledDniBackLocalPath,
    this.prefilledLicenseLocalPath,
    this.prefilledSoatLocalPath,
    this.prefilledPropertyCardLocalPath,
    this.prefilledProfilePicLocalPath,
  });

  @override
  State<RegisterProfileScreen> createState() => _RegisterProfileScreenState();
}

class _RegisterProfileScreenState extends State<RegisterProfileScreen> {
  static const Color _background = Color(0xFF0A0A0A);
  static const Color _accent = Color(0xFF00D4FF);
  static const Color _inactive = Color(0xFF1A1A1A);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _driverCarBrandController =
      TextEditingController();
  final TextEditingController _driverCarModelController =
      TextEditingController();
  final TextEditingController _driverCarPlateController =
      TextEditingController();
  final TextEditingController _driverCarYearController =
      TextEditingController();
  final TextEditingController _driverEmailController = TextEditingController();
  final TextEditingController _driverDniController = TextEditingController();
  final TextEditingController _driverLicenseNumberController =
      TextEditingController();
  final TextEditingController _clientEmailController = TextEditingController();
  final TextEditingController _clientDniController = TextEditingController();

  DateTime? _clientBirthDate;
  String? _driverLicenseCategory;
  DateTime? _driverSoatExpiration;
  DateTime? _driverPropertyCardExpiration;
  DateTime? _driverTechnicalReviewExpiration;

  late String _selectedRole;

  static final _dateFmt = DateFormat('dd/MM/yyyy');

  static bool _hasLocalPath(String? s) => s != null && s.trim().isNotEmpty;

  bool get _hasPrefilledVehicle =>
      widget.prefilledCarPlate != null &&
      widget.prefilledCarModel != null &&
      widget.prefilledCarPlate!.trim().isNotEmpty &&
      widget.prefilledCarModel!.trim().isNotEmpty;

  bool get _hasCompleteDriverLegalPackage =>
      _hasPrefilledVehicle &&
      (widget.prefilledCarBrand?.trim().isNotEmpty ?? false) &&
      widget.prefilledCarYear != null &&
      widget.prefilledCarYear! >= 2005 &&
      (widget.prefilledEmail?.trim().isNotEmpty ?? false) &&
      (widget.prefilledDni?.trim().isNotEmpty ?? false) &&
      (widget.prefilledFirstName?.trim().isNotEmpty ?? false) &&
      (widget.prefilledLastName?.trim().isNotEmpty ?? false) &&
      widget.prefilledSoatExpiration != null &&
      widget.prefilledPropertyCardExpiration != null &&
      widget.prefilledTechnicalReviewExpiration != null &&
      (widget.prefilledLicenseCategory?.trim().isNotEmpty ?? false) &&
      (widget.prefilledLicenseNumber?.trim().isNotEmpty ?? false) &&
      _hasLocalPath(widget.prefilledDniFrontLocalPath) &&
      _hasLocalPath(widget.prefilledDniBackLocalPath) &&
      _hasLocalPath(widget.prefilledLicenseLocalPath) &&
      _hasLocalPath(widget.prefilledSoatLocalPath) &&
      _hasLocalPath(widget.prefilledPropertyCardLocalPath) &&
      _hasLocalPath(widget.prefilledProfilePicLocalPath);

  bool get _hasCompleteClientPackage =>
      widget.prefilledRole == 'client' &&
      (widget.prefilledFirstName?.trim().isNotEmpty ?? false) &&
      (widget.prefilledLastName?.trim().isNotEmpty ?? false) &&
      (widget.prefilledEmail?.trim().isNotEmpty ?? false) &&
      (widget.prefilledDni?.trim().isNotEmpty ?? false) &&
      widget.prefilledBirthDate != null &&
      AgeValidation.isAtLeastYearsOld(widget.prefilledBirthDate!, 18);

  bool get _isDriverFlowLocked => widget.prefilledRole == 'driver';
  bool get _isClientFlowLocked => widget.prefilledRole == 'client';

  bool get _needsManualClientFields =>
      _selectedRole == 'client' && !_hasCompleteClientPackage;

  /// Solo registro conductor vía SMS incompleto; el flujo abierto va a [DriverRegisterScreen].
  bool get _needsManualDriverFields =>
      widget.prefilledRole == 'driver' && !_hasCompleteDriverLegalPackage;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.phone);
    _selectedRole = widget.prefilledRole == 'driver' ? 'driver' : 'client';
    final prefEmail = widget.prefilledEmail?.trim() ?? '';
    if (prefEmail.isNotEmpty) {
      _clientEmailController.text = prefEmail;
    }
    final prefName = widget.prefilledName.trim();
    final fn = widget.prefilledFirstName?.trim() ?? '';
    final ln = widget.prefilledLastName?.trim() ?? '';
    if (prefName.isNotEmpty) {
      _nameController.text = prefName;
    } else if (fn.isNotEmpty || ln.isNotEmpty) {
      _nameController.text = '$fn $ln'.trim();
    }
    _driverEmailController.text = widget.prefilledEmail?.trim() ?? '';
    _driverDniController.text = widget.prefilledDni?.trim() ?? '';
    _driverCarBrandController.text = widget.prefilledCarBrand?.trim() ?? '';
    _driverCarModelController.text = widget.prefilledCarModel?.trim() ?? '';
    _driverCarPlateController.text = widget.prefilledCarPlate?.trim() ?? '';
    if (widget.prefilledCarYear != null) {
      _driverCarYearController.text = '${widget.prefilledCarYear}';
    }
    final licPref = widget.prefilledLicenseCategory?.trim();
    _driverLicenseCategory =
        (licPref != null && licPref.isNotEmpty) ? licPref : null;
    _driverLicenseNumberController.text =
        widget.prefilledLicenseNumber?.trim() ?? '';
    _driverSoatExpiration = widget.prefilledSoatExpiration;
    _driverPropertyCardExpiration = widget.prefilledPropertyCardExpiration;
    _driverTechnicalReviewExpiration =
        widget.prefilledTechnicalReviewExpiration;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _driverCarBrandController.dispose();
    _driverCarModelController.dispose();
    _driverCarPlateController.dispose();
    _driverCarYearController.dispose();
    _driverEmailController.dispose();
    _driverDniController.dispose();
    _driverLicenseNumberController.dispose();
    _clientEmailController.dispose();
    _clientDniController.dispose();
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

  Future<void> _pickClientBirth() async {
    final maxDate = AgeValidation.maxBirthDateForMinimumAge(18);
    final picked = await showDatePicker(
      context: context,
      initialDate: _clientBirthDate ?? maxDate,
      firstDate: DateTime(1920),
      lastDate: maxDate,
      helpText: 'Mayor de 18 años',
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked != null) setState(() => _clientBirthDate = picked);
  }

  Future<void> _pickDriverDate({
    required DateTime? current,
    required void Function(DateTime) onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 15)),
      builder: (ctx, child) => Theme(data: _pickerTheme(ctx), child: child!),
    );
    if (picked != null) onPicked(picked);
  }

  Widget _driverDateTile({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: _inactive,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(icon, color: Colors.white70),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            value != null ? _dateFmt.format(value) : 'Toca para elegir fecha',
            style: TextStyle(
              color: value != null ? Colors.white : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    String? carPlate;
    String? carModel;
    int? carYear;
    String? carBrand;
    String? email;
    String? dni;
    DateTime? soatExpiration;
    DateTime? propertyCardExpiration;
    DateTime? technicalReviewExpiration;
    String? licenseCategory;
    String? licenseNumber;
    DateTime? birthDate;
    String? dniFrontLocalPath;
    String? dniBackLocalPath;
    String? licenseLocalPath;
    String? soatLocalPath;
    String? propertyCardLocalPath;
    String? profilePicLocalPath;

    if (_selectedRole == 'driver') {
      if (_hasCompleteDriverLegalPackage) {
        carPlate = widget.prefilledCarPlate!.trim();
        carModel = widget.prefilledCarModel!.trim();
        carYear = widget.prefilledCarYear;
        carBrand = widget.prefilledCarBrand!.trim();
        email = widget.prefilledEmail!.trim();
        dni = widget.prefilledDni!.trim();
        soatExpiration = widget.prefilledSoatExpiration;
        propertyCardExpiration = widget.prefilledPropertyCardExpiration;
        technicalReviewExpiration = widget.prefilledTechnicalReviewExpiration;
        licenseCategory = widget.prefilledLicenseCategory!.trim();
        licenseNumber = widget.prefilledLicenseNumber!.trim();
        dniFrontLocalPath = widget.prefilledDniFrontLocalPath!.trim();
        dniBackLocalPath = widget.prefilledDniBackLocalPath!.trim();
        licenseLocalPath = widget.prefilledLicenseLocalPath!.trim();
        soatLocalPath = widget.prefilledSoatLocalPath!.trim();
        propertyCardLocalPath = widget.prefilledPropertyCardLocalPath!.trim();
        profilePicLocalPath = widget.prefilledProfilePicLocalPath!.trim();
      } else {
        carBrand = _driverCarBrandController.text.trim();
        carModel = _driverCarModelController.text.trim();
        carPlate = _driverCarPlateController.text.trim();
        carYear = int.tryParse(_driverCarYearController.text.trim());
        email = _driverEmailController.text.trim();
        dni = _driverDniController.text.trim();
        licenseCategory = _driverLicenseCategory;
        licenseNumber = _driverLicenseNumberController.text.trim();
        soatExpiration = _driverSoatExpiration;
        propertyCardExpiration = _driverPropertyCardExpiration;
        technicalReviewExpiration = _driverTechnicalReviewExpiration;
      }
      if (!_hasCompleteDriverLegalPackage) {
        if (_driverLicenseCategory == null ||
            _driverLicenseCategory!.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selecciona la categoría de tu licencia'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          return;
        }
        if (_driverSoatExpiration == null ||
            _driverPropertyCardExpiration == null ||
            _driverTechnicalReviewExpiration == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Selecciona vencimiento de SOAT, tarjeta de propiedad y revisión técnica',
              ),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          return;
        }
      }
      if (carPlate.isEmpty || carModel.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Completa marca, modelo y placa del vehículo',
            ),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }
    } else {
      if (_hasCompleteClientPackage) {
        email = widget.prefilledEmail!.trim();
        dni = widget.prefilledDni!.trim();
        birthDate = widget.prefilledBirthDate;
      } else {
        email = _clientEmailController.text.trim();
        dni = _clientDniController.text.trim();
        birthDate = _clientBirthDate;
        if (birthDate == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selecciona tu fecha de nacimiento'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          return;
        }
        if (!AgeValidation.isAtLeastYearsOld(birthDate, 18)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes tener al menos 18 años'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          return;
        }
      }
    }

    context.read<AuthBloc>().add(
          RegisterUser(
            phone: _phoneController.text.trim(),
            fullName: _nameController.text.trim(),
            role: _selectedRole,
            email: email,
            dni: dni,
            carPlate: carPlate,
            carBrand: carBrand,
            carModel: carModel,
            carYear: carYear,
            carColor: null,
            soatExpiration: soatExpiration,
            propertyCardExpiration: propertyCardExpiration,
            technicalReviewExpiration: technicalReviewExpiration,
            licenseCategory: licenseCategory,
            licenseNumber: licenseNumber,
            birthDate: birthDate,
            dniFrontLocalPath: dniFrontLocalPath,
            dniBackLocalPath: dniBackLocalPath,
            licenseLocalPath: licenseLocalPath,
            soatLocalPath: soatLocalPath,
            propertyCardLocalPath: propertyCardLocalPath,
            profilePicLocalPath: profilePicLocalPath,
          ),
        );
  }

  List<Widget> _profileFormFieldWidgets(BuildContext context) {
    final phoneEditable = widget.phone.trim().isEmpty;
    return [
      TextFormField(
        controller: _phoneController,
        readOnly: !phoneEditable,
        keyboardType: phoneEditable ? TextInputType.phone : null,
        textInputAction: phoneEditable ? TextInputAction.next : null,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: 'Teléfono',
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: _inactive,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: phoneEditable
            ? (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                if (digits.length < 9) {
                  return 'Ingresa un número de celular válido';
                }
                return null;
              }
            : null,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _nameController,
        readOnly: widget.prefilledName.trim().isNotEmpty,
        style: const TextStyle(color: Colors.white),
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Nombre completo',
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: _inactive,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          final v = value?.trim() ?? '';
          if (v.isEmpty) {
            return 'Ingresa tu nombre completo';
          }
          if (v.length < 3) {
            return 'Nombre demasiado corto';
          }
          return null;
        },
      ),
      const SizedBox(height: 20),
      if (_isDriverFlowLocked)
        _lockedBanner(
          Icons.directions_car,
          'Registro como conductor',
        )
      else if (_isClientFlowLocked)
        _lockedBanner(
          Icons.person,
          'Registro como pasajero',
        ),
      if (_needsManualClientFields) ...[
        const SizedBox(height: 16),
        TextFormField(
          controller: _clientEmailController,
          readOnly: (widget.prefilledEmail?.trim().isNotEmpty ?? false),
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: _inactive,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
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
        TextFormField(
          controller: _clientDniController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          decoration: InputDecoration(
            labelText: 'DNI',
            labelStyle: const TextStyle(color: Colors.white70),
            filled: true,
            fillColor: _inactive,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) {
            final s = v?.trim() ?? '';
            if (s.length != 8) return 'DNI: 8 dígitos';
            if (int.tryParse(s) == null) return 'Solo números';
            return null;
          },
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickClientBirth,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Fecha de nacimiento',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: _inactive,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(
                Icons.cake_outlined,
                color: Colors.white70,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                _clientBirthDate != null
                    ? _dateFmt.format(_clientBirthDate!)
                    : 'Mayor de 18 años — toca para elegir',
                style: TextStyle(
                  color:
                      _clientBirthDate != null ? Colors.white : Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ],
      if (_needsManualDriverFields) ...[
        const SizedBox(height: 20),
        Text(
          'Datos del conductor y vehículo',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _accent,
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _driverEmailController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: 'Correo electrónico',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: Colors.white70,
            ),
            filled: true,
            fillColor: _inactive,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
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
        TextFormField(
          controller: _driverDniController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          decoration: InputDecoration(
            labelText: 'DNI',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(
              Icons.badge_outlined,
              color: Colors.white70,
            ),
            filled: true,
            fillColor: _inactive,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) {
            final s = v?.trim() ?? '';
            if (s.length != 8) return 'DNI: 8 dígitos';
            if (int.tryParse(s) == null) {
              return 'Solo números';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _driverCarBrandController,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Marca del vehículo',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(
              Icons.directions_car_outlined,
              color: Colors.white70,
            ),
            filled: true,
            fillColor: _inactive,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Ingresa la marca' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _driverCarModelController,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Modelo del vehículo',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(
              Icons.directions_car,
              color: Colors.white70,
            ),
            filled: true,
            fillColor: _inactive,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Ingresa el modelo' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _driverCarPlateController,
          style: const TextStyle(color: Colors.white),
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            LengthLimitingTextInputFormatter(12),
          ],
          decoration: InputDecoration(
            labelText: 'Placa',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(
              Icons.pin,
              color: Colors.white70,
            ),
            filled: true,
            fillColor: _inactive,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Ingresa la placa' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _driverCarYearController,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            labelText: 'Año de fabricación',
            hintText: '2005 o posterior',
            hintStyle: TextStyle(
              color: Colors.white70.withValues(alpha: 0.65),
            ),
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(
              Icons.calendar_month_outlined,
              color: Colors.white70,
            ),
            filled: true,
            fillColor: _inactive,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) {
            final s = v?.trim() ?? '';
            if (s.isEmpty) return 'Ingresa el año';
            final y = int.tryParse(s);
            if (y == null || y < 2005 || y > DateTime.now().year + 1) {
              return 'Año inválido (mín. 2005)';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        _driverDateTile(
          label: 'Vencimiento SOAT',
          value: _driverSoatExpiration,
          icon: Icons.calendar_today,
          onTap: () => _pickDriverDate(
            current: _driverSoatExpiration,
            onPicked: (d) => setState(
              () => _driverSoatExpiration = d,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _driverDateTile(
          label: 'Vencimiento tarjeta de propiedad',
          value: _driverPropertyCardExpiration,
          icon: Icons.description_outlined,
          onTap: () => _pickDriverDate(
            current: _driverPropertyCardExpiration,
            onPicked: (d) => setState(
              () => _driverPropertyCardExpiration = d,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _driverDateTile(
          label: 'Vencimiento revisión técnica',
          value: _driverTechnicalReviewExpiration,
          icon: Icons.fact_check_outlined,
          onTap: () => _pickDriverDate(
            current: _driverTechnicalReviewExpiration,
            onPicked: (d) => setState(
              () => _driverTechnicalReviewExpiration = d,
            ),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: _driverLicenseCategory,
          dropdownColor: _inactive,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            labelText: 'Categoría de licencia',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(
              Icons.category_outlined,
              color: Colors.white70,
            ),
            filled: true,
            fillColor: _inactive,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          hint: const Text(
            'Selecciona categoría',
            style: TextStyle(color: Colors.white70),
          ),
          items: _kLicenseCategories
              .map(
                (c) => DropdownMenuItem<String>(
                  value: c,
                  child: Text(c),
                ),
              )
              .toList(),
          onChanged: (v) => setState(
            () => _driverLicenseCategory = v,
          ),
          validator: (v) =>
              v == null || v.isEmpty ? 'Selecciona categoría' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _driverLicenseNumberController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Número de brevete',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon: const Icon(
              Icons.credit_card,
              color: Colors.white70,
            ),
            filled: true,
            fillColor: _inactive,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          validator: (v) {
            final s = v?.trim() ?? '';
            if (s.isEmpty) {
              return 'Ingresa el número de brevete';
            }
            return null;
          },
        ),
      ],
      const SizedBox(height: 24),
    ];
  }

  Widget _buildProfileForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _profileFormFieldWidgets(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          context.go(
            '/welcome',
            extra: {
              'userName': state.user.fullName,
              'isNewUser': true,
            },
          );
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
      builder: (context, state) {
        final uploadState = state is AuthUploadingDriverDocs ? state : null;
        return Stack(
          children: [
            Scaffold(
              backgroundColor: _background,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new),
                  onPressed: () => context.pop(),
                ),
              ),
              body: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 8),
                          Text(
                            'Crea tu perfil',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          if (_isDriverFlowLocked &&
                              _hasCompleteDriverLegalPackage)
                            Text(
                              'Revisa tu nombre y confirma para enviar tu solicitud a revisión.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          if (_isClientFlowLocked && _hasCompleteClientPackage)
                            Text(
                              'Confirma tu nombre y pulsa Comenzar para finalizar el registro.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white70,
                                  ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: SingleChildScrollView(
                          child: _buildProfileForm(context),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final isLoading = state is AuthLoading ||
                              state is AuthUploadingDriverDocs;
                          return ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.black,
                                      ),
                                    ),
                                  )
                                : const Text(
                                    'Comenzar',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            if (uploadState != null)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Material(
                  color: _background,
                  elevation: 4,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LinearProgressIndicator(
                        value: uploadState.total > 0
                            ? uploadState.completed / uploadState.total
                            : null,
                        backgroundColor: _inactive,
                        color: _accent,
                        minHeight: 6,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: Text(
                          'Subiendo documentos ${uploadState.completed}/${uploadState.total}…',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _lockedBanner(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _accent, width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
