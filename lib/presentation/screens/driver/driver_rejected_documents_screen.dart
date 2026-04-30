import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';

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
    if (authState is AuthLoading) {
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

    return Scaffold(
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
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Corrige estos documentos para poder conectarte.',
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: rejectedDocs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final doc = rejectedDocs[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.darkSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.errorRed.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: doc.url.isNotEmpty
                                      ? Image.network(doc.url, fit: BoxFit.cover)
                                      : const ColoredBox(
                                          color: AppTheme.darkSurfaceElevated,
                                          child: Icon(
                                            Icons.description_outlined,
                                            color: AppTheme.darkTextSecondary,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  doc.label,
                                  style: const TextStyle(
                                    color: AppTheme.darkText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(Icons.error, color: AppTheme.errorRed),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => context.push(
                                    '/become-driver?doc=${doc.key}',
                                  ),
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Corregir este documento'),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => context.push('/become-driver'),
                    child: const Text('Corregir documentos'),
                  ),
                ],
              ),
      ),
    );
  }

  List<_RejectedDoc> _rejectedDocs(UserEntity user) {
    final docs = <_RejectedDoc>[
      _RejectedDoc(
        key: _docDniFront,
        label: 'DNI frontal',
        status: user.dniFrontStatus,
        url: user.dniFrontUrl ?? '',
      ),
      _RejectedDoc(
        key: _docDniBack,
        label: 'DNI posterior',
        status: user.dniBackStatus,
        url: user.dniBackUrl ?? '',
      ),
      _RejectedDoc(
        key: _docLicense,
        label: 'Licencia',
        status: user.licenseStatus,
        url: user.licenseUrl ?? '',
      ),
      _RejectedDoc(
        key: _docSoat,
        label: 'SOAT',
        status: user.soatStatus,
        url: user.soatUrl ?? '',
      ),
      _RejectedDoc(
        key: _docPropertyCard,
        label: 'Tarjeta de propiedad',
        status: user.propertyCardStatus,
        url: user.propertyCardUrl ?? '',
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
  });

  final String key;
  final String label;
  final String status;
  final String url;
}
