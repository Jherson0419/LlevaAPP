import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/entities/document_review_status.dart';
import '../../../domain/entities/user.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../widgets/common/signed_remote_image.dart';

class DriverRejectedDocumentsScreen extends StatefulWidget {
  const DriverRejectedDocumentsScreen({super.key});

  @override
  State<DriverRejectedDocumentsScreen> createState() =>
      _DriverRejectedDocumentsScreenState();
}

class _DriverRejectedDocumentsScreenState
    extends State<DriverRejectedDocumentsScreen> {
  static const _docDniFront = 'dniFront';
  static const _docDniBack = 'dniBack';
  static const _docLicense = 'license';
  static const _docSoat = 'soat';
  static const _docPropertyCard = 'propertyCard';

  final Map<String, File> _localReplacements = {};
  final ImagePicker _picker = ImagePicker();
  String? _uploadingDocKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(RefreshProfileEvent());
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState is AuthLoading && _uploadingDocKey == null) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
      );
    }

    final user = authState is AuthAuthenticated ? authState.user : null;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: Text(
            'No se pudo cargar tu perfil.',
            style: TextStyle(color: AppTheme.darkText),
          ),
        ),
      );
    }

    final rejectedDocs = _rejectedDocs(user);

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (_, curr) => _uploadingDocKey != null && curr is! AuthLoading,
      listener: (context, state) {
        if (_uploadingDocKey == null) return;
        if (state is AuthAuthenticated) {
          final doneDoc = _uploadingDocKey!;
          setState(() {
            _localReplacements.remove(doneDoc);
            _uploadingDocKey = null;
          });
          context.read<AuthBloc>().add(RefreshProfileEvent());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Documento enviado. Estado actualizado a En revisión.'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          return;
        }
        if (state is AuthError) {
          setState(() => _uploadingDocKey = null);
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
          title: const Text('Documentos rechazados'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: rejectedDocs.isEmpty
              ? const Center(
                  child: Text(
                    'No tienes documentos rechazados.',
                    style: TextStyle(color: AppTheme.darkTextSecondary),
                  ),
                )
              : ListView.separated(
                  itemCount: rejectedDocs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doc = rejectedDocs[index];
                    final localFile = _localReplacements[doc.key];
                    final isUploading = _uploadingDocKey == doc.key;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.errorRed.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 1.15,
                              child: localFile != null
                                  ? Image.file(localFile, fit: BoxFit.cover)
                                  : doc.url.isNotEmpty
                                      ? SignedRemoteImage(value: doc.url)
                                      : const ColoredBox(
                                          color: AppTheme.darkSurfaceElevated,
                                          child: Icon(
                                            Icons.description_outlined,
                                            color: AppTheme.darkTextSecondary,
                                            size: 56,
                                          ),
                                        ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            doc.label,
                            style: const TextStyle(
                              color: AppTheme.darkText,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isUploading
                                      ? null
                                      : () => _pickReplacement(doc.key),
                                  icon: const Icon(Icons.photo_camera),
                                  label: const Text('Reemplazar'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: (isUploading || localFile == null)
                                      ? null
                                      : () => _submitReplacement(
                                            doc: doc,
                                            localFile: localFile,
                                          ),
                                  icon: isUploading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : const Icon(Icons.upload_file),
                                  label: const Text('Subir'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Future<void> _pickReplacement(String key) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryBlue),
              title: const Text('Galería', style: TextStyle(color: AppTheme.darkText)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryBlue),
              title: const Text('Cámara', style: TextStyle(color: AppTheme.darkText)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (image == null || !mounted) return;
    setState(() {
      _localReplacements[key] = File(image.path);
    });
  }

  Future<void> _submitReplacement({
    required _RejectedDoc doc,
    required File localFile,
  }) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    setState(() => _uploadingDocKey = doc.key);

    final storage = di.sl<StorageService>();
    try {
      final uploadedUrl = await storage.uploadImage(localFile, doc.storageFileBase);
      final base = _userModelFromEntity(authState.user);
      final updated = _applyDocUpdate(
        base: base,
        docKey: doc.key,
        url: uploadedUrl,
      );
      if (!mounted) return;
      context.read<AuthBloc>().add(SubmitDriverApplicationEvent(updated));
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingDocKey = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo subir ${doc.label}: $e'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  UserModel _userModelFromEntity(UserEntity u) {
    return UserModel(
      id: u.id,
      phone: u.phone,
      role: u.role,
      isDriverApplicant: u.isDriverApplicant,
      fullName: u.fullName,
      email: u.email,
      dni: u.dni,
      carPlate: u.carPlate,
      carBrand: u.carBrand,
      carModel: u.carModel,
      isApproved: u.isApproved,
      isBanned: u.isBanned,
      carYear: u.carYear,
      carColor: u.carColor,
      soatExpiration: u.soatExpiration,
      propertyCardExpiration: u.propertyCardExpiration,
      technicalReviewExpiration: u.technicalReviewExpiration,
      licenseCategory: u.licenseCategory,
      licenseNumber: u.licenseNumber,
      birthDate: u.birthDate,
      dniFrontUrl: u.dniFrontUrl,
      dniBackUrl: u.dniBackUrl,
      licenseUrl: u.licenseUrl,
      soatUrl: u.soatUrl,
      propertyCardUrl: u.propertyCardUrl,
      profilePicUrl: u.profilePicUrl,
      dniFrontStatus: u.dniFrontStatus,
      dniBackStatus: u.dniBackStatus,
      licenseStatus: u.licenseStatus,
      soatStatus: u.soatStatus,
      propertyCardStatus: u.propertyCardStatus,
    );
  }

  UserModel _applyDocUpdate({
    required UserModel base,
    required String docKey,
    required String url,
  }) {
    final pending = DocumentReviewStatus.pending.value;
    switch (docKey) {
      case _docDniFront:
        return base.copyWith(
          dniFrontUrl: url,
          dniFrontStatus: pending,
        );
      case _docDniBack:
        return base.copyWith(
          dniBackUrl: url,
          dniBackStatus: pending,
        );
      case _docLicense:
        return base.copyWith(
          licenseUrl: url,
          licenseStatus: pending,
        );
      case _docSoat:
        return base.copyWith(
          soatUrl: url,
          soatStatus: pending,
        );
      case _docPropertyCard:
        return base.copyWith(
          propertyCardUrl: url,
          propertyCardStatus: pending,
        );
      default:
        return base;
    }
  }

  List<_RejectedDoc> _rejectedDocs(UserEntity user) {
    final docs = <_RejectedDoc>[
      _RejectedDoc(
        key: _docDniFront,
        label: 'DNI frontal',
        status: user.dniFrontStatus,
        url: user.dniFrontUrl ?? '',
        storageFileBase: 'dni_front',
      ),
      _RejectedDoc(
        key: _docDniBack,
        label: 'DNI posterior',
        status: user.dniBackStatus,
        url: user.dniBackUrl ?? '',
        storageFileBase: 'dni_back',
      ),
      _RejectedDoc(
        key: _docLicense,
        label: 'Licencia',
        status: user.licenseStatus,
        url: user.licenseUrl ?? '',
        storageFileBase: 'license',
      ),
      _RejectedDoc(
        key: _docSoat,
        label: 'SOAT',
        status: user.soatStatus,
        url: user.soatUrl ?? '',
        storageFileBase: 'soat',
      ),
      _RejectedDoc(
        key: _docPropertyCard,
        label: 'Tarjeta de propiedad',
        status: user.propertyCardStatus,
        url: user.propertyCardUrl ?? '',
        storageFileBase: 'property_card',
      ),
    ];
    return docs
        .where((d) => d.status.trim().toUpperCase() == 'REJECTED')
        .toList(growable: false);
  }
}

class _RejectedDoc {
  const _RejectedDoc({
    required this.key,
    required this.label,
    required this.status,
    required this.url,
    required this.storageFileBase,
  });

  final String key;
  final String label;
  final String status;
  final String url;
  final String storageFileBase;
}
