import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/di/injection_container.dart' as di;
import '../../../core/services/avatar_generator_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/repositories/user_repository.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../cubit/theme_cubit.dart';

const Color _kBlue = AppTheme.primaryBlue;
const Color _kTextDark = Color(0xFF1A1A1A);
const Color _kTextMuted = Color(0xFF888888);
const Color _kRed = Color(0xFFFF4444);
const Color _kGreen = Color(0xFF00AA44);
const Color _kChevron = Color(0xFFCCCCCC);

const ShapeBorder _kSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
);

/// Perfil del pasajero: foto, datos personales, tema de la app, accesos de
/// cuenta y cierre de sesión.
class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  /// true mientras se sube una foto de perfil nueva.
  bool _uploadingAvatar = false;

  /// Cambia tras cada subida: la foto se guarda siempre en la misma ruta,
  /// así que es lo que obliga al avatar a volver a pedirla.
  int _avatarVersion = 0;

  /// El teléfono de una cuenta creada con Google es un marcador interno
  /// (ver AuthBloc), no un número.
  static String _phoneLabel(UserEntity? user) {
    final phone = user?.phone.trim() ?? '';
    if (phone.isEmpty) return '—';
    if (phone.startsWith('g_') || phone.startsWith('email_')) {
      return 'No configurado';
    }
    return phone;
  }

  static String _orDash(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? '—' : text;
  }

  void _showSnack(String message, {Color? color}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  /// Elige una foto (galería o cámara), la sube a Storage, guarda su ruta en
  /// el perfil y refresca el usuario en sesión.
  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;
    if (authState is! AuthAuthenticated || _uploadingAvatar) return;

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) {
        _showSnack('No se pudo abrir la cámara o la galería.', color: _kRed);
      }
      return;
    }
    if (picked == null || !mounted) return;
    await _uploadAvatarFile(
      File(picked.path),
      fileName: 'profile_pic',
      successMessage: 'Foto de perfil actualizada.',
    );
  }

  /// Sube [file] a Storage como foto de perfil, guarda su ruta en el perfil
  /// y refresca el usuario en sesión.
  Future<void> _uploadAvatarFile(
    File file, {
    required String fileName,
    required String successMessage,
  }) async {
    final authBloc = context.read<AuthBloc>();
    final authState = authBloc.state;
    if (authState is! AuthAuthenticated || _uploadingAvatar) return;

    setState(() => _uploadingAvatar = true);
    try {
      final path = await di.sl<StorageService>().uploadImage(file, fileName);
      final saved = await di.sl<UserRepository>().updateProfilePicture(
            userId: authState.user.id,
            storagePath: path,
          );
      if (!mounted) return;
      if (!saved) {
        _showSnack('No se pudo guardar la foto en tu perfil.', color: _kRed);
        return;
      }
      authBloc.add(const RefreshProfileEvent());
      setState(() => _avatarVersion++);
      _showSnack(successMessage, color: _kGreen);
    } catch (_) {
      if (mounted) {
        _showSnack('No se pudo subir la foto. Intenta de nuevo.', color: _kRed);
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  /// «Generar avatar con IA»: elige una foto, pide a Gemini un avatar por
  /// estilo y deja escoger cuál guardar como foto de perfil.
  Future<void> _startAvatarGeneration() async {
    if (!AvatarGeneratorService.isConfigured) {
      _showSnack(
        'La generación de avatares no está configurada.',
        color: _kRed,
      );
      return;
    }

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) _showSnack('No se pudo abrir la galería.', color: _kRed);
      return;
    }
    if (picked == null || !mounted) return;

    // El diálogo de espera se cierra con su propio navigator: así no se
    // cierra otra ruta por error si algo cambió mientras tanto.
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: _AvatarGeneratingDialog(),
      ),
    );

    List<AvatarResult> results = const [];
    try {
      results = await di
          .sl<AvatarGeneratorService>()
          .generateAvatars(File(picked.path));
    } catch (_) {
      // Sin resultados: se avisa abajo.
    }
    navigator.pop();
    if (!mounted) return;

    if (results.isEmpty) {
      _showSnack('No se pudieron generar los avatares.', color: _kRed);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AvatarPickerSheet(
        results: results,
        onSelected: (result) {
          Navigator.pop(sheetContext);
          _saveGeneratedAvatar(result);
        },
      ),
    );
  }

  Future<void> _saveGeneratedAvatar(AvatarResult result) async {
    final File tempFile;
    try {
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/avatar_${result.styleId}.png');
      await tempFile.writeAsBytes(result.imageBytes);
    } catch (_) {
      if (mounted) _showSnack('No se pudo guardar el avatar.', color: _kRed);
      return;
    }
    if (!mounted) return;
    await _uploadAvatarFile(
      tempFile,
      fileName: 'avatar_${result.styleId}.png',
      successMessage: 'Avatar actualizado ✨',
    );
  }

  void _showAvatarOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: _kSheetShape,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHandle(),
              const SizedBox(height: 16),
              const Text(
                'Foto de perfil',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 16),
              _ActionTile(
                icon: Icons.auto_awesome_rounded,
                label: 'Generar avatar con IA ✨',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _kBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'NUEVO',
                    style: TextStyle(
                      fontSize: 10,
                      color: _kBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _startAvatarGeneration();
                },
              ),
              _ActionTile(
                icon: Icons.photo_library_outlined,
                label: 'Elegir de la galería',
                trailing: const _Chevron(),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              _ActionTile(
                icon: Icons.camera_alt_outlined,
                label: 'Tomar foto',
                trailing: const _Chevron(),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: _kSheetShape,
      builder: (sheetContext) => BlocProvider.value(
        value: context.read<ThemeCubit>(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 16),
                const Text(
                  'Tema de la aplicación',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
                const SizedBox(height: 16),
                BlocBuilder<ThemeCubit, ThemeMode>(
                  builder: (context, mode) {
                    final cubit = context.read<ThemeCubit>();
                    return Column(
                      children: [
                        _ThemeOption(
                          icon: Icons.light_mode_rounded,
                          label: 'Claro',
                          isSelected: mode == ThemeMode.light,
                          onTap: () {
                            cubit.setLight();
                            Navigator.pop(sheetContext);
                          },
                        ),
                        _ThemeOption(
                          icon: Icons.dark_mode_rounded,
                          label: 'Oscuro',
                          isSelected: mode == ThemeMode.dark,
                          onTap: () {
                            cubit.setDark();
                            Navigator.pop(sheetContext);
                          },
                        ),
                        _ThemeOption(
                          icon: Icons.phone_android_rounded,
                          label: 'Igual que el sistema',
                          isSelected: mode == ThemeMode.system,
                          onTap: () {
                            cubit.setSystem();
                            Navigator.pop(sheetContext);
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditProfile(UserEntity? user) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: _kSheetShape,
      builder: (_) => _EditProfileSheet(user: user),
    );
  }

  void _showLogoutDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Cerrar sesión?',
          style: TextStyle(fontWeight: FontWeight.w700, color: _kTextDark),
        ),
        content: const Text(
          'Tendrás que volver a iniciar sesión.',
          style: TextStyle(color: Color(0xFF666666)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: _kTextMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<AuthBloc>().add(const LogoutRequested());
              context.go('/login');
            },
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: _kRed, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          final user = authState is AuthAuthenticated ? authState.user : null;
          final name = user?.fullName.trim() ?? '';

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_rounded,
                    color: _kTextDark,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const Text(
                  'Mi perfil',
                  style: TextStyle(
                    color: _kTextDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0066CC), Color(0xFF0099FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          _buildAvatar(user),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              name.isEmpty ? 'Usuario' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SectionCard(
                        title: 'Información personal',
                        children: [
                          _InfoTile(
                            icon: Icons.person_outline_rounded,
                            label: 'Nombre completo',
                            value: _orDash(user?.fullName),
                          ),
                          _InfoTile(
                            icon: Icons.email_outlined,
                            label: 'Correo electrónico',
                            value: _orDash(user?.email),
                          ),
                          _InfoTile(
                            icon: Icons.phone_outlined,
                            label: 'Teléfono',
                            value: _phoneLabel(user),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Apariencia',
                        children: [
                          BlocBuilder<ThemeCubit, ThemeMode>(
                            builder: (context, themeMode) {
                              final String label;
                              switch (themeMode) {
                                case ThemeMode.light:
                                  label = 'Claro';
                                case ThemeMode.dark:
                                  label = 'Oscuro';
                                case ThemeMode.system:
                                  label = 'Sistema';
                              }
                              return _ActionTile(
                                icon: Icons.palette_outlined,
                                label: 'Tema de la aplicación',
                                trailing: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _kBlue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                onTap: _showThemePicker,
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: 'Cuenta',
                        children: [
                          _ActionTile(
                            icon: Icons.edit_outlined,
                            label: 'Editar perfil',
                            trailing: const _Chevron(),
                            onTap: () => _showEditProfile(user),
                          ),
                          _ActionTile(
                            icon: Icons.directions_car_outlined,
                            label: 'Convertirme en conductor',
                            trailing: const _Chevron(),
                            onTap: () => context.push('/become-driver'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showLogoutDialog,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kRed, width: 1.5),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: _kRed, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Cerrar sesión',
                                style: TextStyle(
                                  color: _kRed,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar(UserEntity? user) {
    return GestureDetector(
      onTap: _uploadingAvatar ? null : _showAvatarOptions,
      child: Stack(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                ),
              ],
            ),
            child: ClipOval(
              child: _uploadingAvatar
                  ? const ColoredBox(
                      color: Color(0xFFEEF5FF),
                      child: Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _kBlue,
                          ),
                        ),
                      ),
                    )
                  : _ProfilePhoto(
                      key: ValueKey(
                        '${user?.profilePicUrl}#$_avatarVersion',
                      ),
                      storagePath: user?.profilePicUrl,
                      gender: user?.gender,
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: _kBlue,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto de perfil. `profile_pic_url` guarda una ruta de Storage (bucket
/// privado) o, en perfiles antiguos, una URL: en ambos casos se resuelve con
/// StorageService.getSignedUrl. Sin foto, o si falla, muestra el avatar por
/// defecto.
class _ProfilePhoto extends StatefulWidget {
  const _ProfilePhoto({
    super.key,
    required this.storagePath,
    required this.gender,
  });

  final String? storagePath;
  final String? gender;

  @override
  State<_ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends State<_ProfilePhoto> {
  late final Future<String?> _url =
      di.sl<StorageService>().getSignedUrl(widget.storagePath);

  Widget _defaultAvatar() {
    return ColoredBox(
      color: const Color(0xFFEEF5FF),
      child: Center(
        child: Icon(
          widget.gender == 'female'
              ? Icons.person_2_rounded
              : Icons.person_rounded,
          color: _kBlue,
          size: 44,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _url,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) return _defaultAvatar();
        return Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _defaultAvatar(),
        );
      },
    );
  }
}

/// Diálogo de espera mientras se generan los avatares.
class _AvatarGeneratingDialog extends StatefulWidget {
  const _AvatarGeneratingDialog();

  @override
  State<_AvatarGeneratingDialog> createState() =>
      _AvatarGeneratingDialogState();
}

class _AvatarGeneratingDialogState extends State<_AvatarGeneratingDialog>
    with SingleTickerProviderStateMixin {
  static const List<String> _messages = [
    'Analizando tu foto...',
    'Generando estilo Pixar...',
    'Creando versión Flat...',
    'Diseñando avatar Anime...',
    'Finalizando versión Artística...',
  ];

  late final AnimationController _ctrl;
  Timer? _timer;
  int _msgIndex = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() => _msgIndex = (_msgIndex + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _ctrl,
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: _kBlue,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Generando tu avatar',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _messages[_msgIndex],
                key: ValueKey(_msgIndex),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: _kTextMuted),
              ),
            ),
            const SizedBox(height: 20),
            const LinearProgressIndicator(
              color: _kBlue,
              backgroundColor: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 8),
            const Text(
              'Esto puede tomar hasta un minuto',
              style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja con los avatares generados para elegir uno.
class _AvatarPickerSheet extends StatelessWidget {
  const _AvatarPickerSheet({required this.results, required this.onSelected});

  final List<AvatarResult> results;
  final ValueChanged<AvatarResult> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.paddingOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 16),
          const Text(
            'Elige tu avatar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toca el que más te guste',
            style: TextStyle(fontSize: 13, color: _kTextMuted),
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: results.length,
            itemBuilder: (context, i) {
              final result = results[i];
              return GestureDetector(
                onTap: () => onSelected(result),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE0E0E0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14),
                          ),
                          child: Image.memory(
                            result.imageBytes,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8F8F8),
                          borderRadius: BorderRadius.vertical(
                            bottom: Radius.circular(14),
                          ),
                        ),
                        child: Text(
                          result.styleName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _kTextDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFDDDDDD),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.arrow_forward_ios_rounded,
      size: 14,
      color: _kChevron,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFFF5F5F5), height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF5FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: _kBlue, size: 18),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _TileIcon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: _kTextMuted),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _kTextDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            _TileIcon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _kTextDark,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF5FF) : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _kBlue : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? _kBlue : _kTextMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? _kBlue : _kTextDark,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: _kBlue, size: 20),
          ],
        ),
      ),
    );
  }
}

/// Hoja «Editar perfil»: nombre y correo. Todavía no existe un evento para
/// guardar estos cambios, así que «Guardar» solo avisa que llegará pronto.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.user});

  final UserEntity? user;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.user?.fullName ?? '');
  late final TextEditingController _emailCtrl =
      TextEditingController(text: widget.user?.email ?? '');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Próximamente: tus cambios aún no se guardan.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  static InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kTextMuted),
      prefixIcon: Icon(icon, color: _kBlue, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBlue, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Sube con el teclado.
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: _SheetHandle()),
            const SizedBox(height: 16),
            const Text(
              'Editar perfil',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kTextDark,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: _kTextDark),
              decoration: _decoration(
                'Nombre completo',
                Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: _kTextDark),
              decoration: _decoration('Correo', Icons.email_outlined),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Guardar',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
