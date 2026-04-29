import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';

/// Selector de imagen con vista previa para documentos del conductor.
class DocumentPickerWidget extends StatelessWidget {
  const DocumentPickerWidget({
    super.key,
    required this.label,
    required this.file,
    required this.onFileChanged,
  });

  final String label;
  final File? file;
  final ValueChanged<File?> onFileChanged;

  static final _picker = ImagePicker();

  Future<void> _pick(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.primaryBlue),
              title: const Text(
                'Galería',
                style: TextStyle(color: AppTheme.darkText),
              ),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryBlue),
              title: const Text(
                'Cámara',
                style: TextStyle(color: AppTheme.darkText),
              ),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            if (file != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
                title: const Text(
                  'Quitar foto',
                  style: TextStyle(color: AppTheme.errorRed),
                ),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
          ],
        ),
      ),
    );

    if (action == null || !context.mounted) return;

    if (action == 'remove') {
      onFileChanged(null);
      return;
    }

    final source =
        action == 'camera' ? ImageSource.camera : ImageSource.gallery;

    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (x != null && context.mounted) {
        onFileChanged(File(x.path));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener la imagen'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.darkTextSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: AppTheme.darkSurfaceElevated,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1.4,
              child: file == null
                  ? const Center(
                      child: Icon(
                        Icons.add_a_photo_outlined,
                        size: 40,
                        color: AppTheme.darkTextSecondary,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        file!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
