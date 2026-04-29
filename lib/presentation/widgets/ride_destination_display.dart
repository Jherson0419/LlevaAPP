import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Partes del texto de destino que envía el cliente (`ClientRideBloc._composeDestNameForPayload`).
class RideDestPayloadParts {
  const RideDestPayloadParts({
    required this.addressLine,
    required this.serviceTags,
    this.notes,
  });

  final String addressLine;
  final List<String> serviceTags;
  final String? notes;

  static RideDestPayloadParts parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return const RideDestPayloadParts(
        addressLine: '',
        serviceTags: [],
        notes: null,
      );
    }

    String? notes;
    var work = trimmed;
    const notasKey = '\nNotas:';
    final notasIdx = work.indexOf(notasKey);
    if (notasIdx != -1) {
      notes = work.substring(notasIdx + notasKey.length).trim();
      work = work.substring(0, notasIdx).trim();
    }

    final tags = <String>[];
    var address = work;
    const servKey = '[Servicio:';
    final servIdx = work.indexOf(servKey);
    if (servIdx != -1) {
      address = work.substring(0, servIdx).trim();
      final close = work.indexOf(']', servIdx);
      if (close != -1) {
        final inner = work.substring(servIdx + servKey.length, close);
        tags.addAll(
          inner
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty),
        );
      }
    }

    return RideDestPayloadParts(
      addressLine: address,
      serviceTags: tags,
      notes: notes,
    );
  }
}

/// Destino con icono, etiquetas de servicio y notas (vista conductor).
class RideDestinationDisplay extends StatelessWidget {
  const RideDestinationDisplay({
    super.key,
    required this.rawDestName,
    this.compact = false,
  });

  final String rawDestName;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final parts = RideDestPayloadParts.parse(rawDestName);
    final chipStyle = TextStyle(
      fontSize: compact ? 10 : 11,
      color: AppTheme.primaryBlue,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: compact ? 1 : 2),
              child: Icon(
                Icons.place,
                size: compact ? 14 : 18,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                parts.addressLine.isEmpty ? '—' : parts.addressLine,
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: compact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
        if (parts.serviceTags.isNotEmpty) ...[
          SizedBox(height: compact ? 6 : 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: parts.serviceTags
                .map(
                  (t) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(t, style: chipStyle),
                  ),
                )
                .toList(),
          ),
        ],
        if (parts.notes != null && parts.notes!.isNotEmpty) ...[
          SizedBox(height: compact ? 6 : 8),
          Text(
            'Notas: ${parts.notes}',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: compact ? 11 : 12,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}
