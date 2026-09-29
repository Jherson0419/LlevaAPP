import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/ride_offer_entity.dart';

/// Banner «Estamos buscando…» con fotos de conductores que ya vieron/ofertaron.
class ClientRideDriverAttentionBanner extends StatelessWidget {
  const ClientRideDriverAttentionBanner({
    super.key,
    required this.offers,
  });

  final List<RideOfferEntity> offers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF10181D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          _DriverAvatarCluster(offers: offers),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Estamos buscando el mejor conductor para tu viaje...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF59E38A),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF59E38A).withValues(alpha: 0.55),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverAvatarCluster extends StatelessWidget {
  const _DriverAvatarCluster({required this.offers});

  final List<RideOfferEntity> offers;

  static const double _size = 38;
  static const double _overlap = 22;

  List<String> _uniqueProfileUrls() {
    final seen = <String>{};
    final urls = <String>[];
    for (final offer in offers) {
      if (!seen.add(offer.driverId)) continue;
      final url = offer.driverProfilePicUrl?.trim();
      if (url != null && url.isNotEmpty) {
        urls.add(url);
      }
    }
    return urls;
  }

  @override
  Widget build(BuildContext context) {
    final urls = _uniqueProfileUrls();
    if (urls.isEmpty) {
      return Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: AppTheme.primaryBlue.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.85),
            width: 1.2,
          ),
        ),
        child: const Icon(
          Icons.person,
          color: AppTheme.primaryBlue,
          size: 22,
        ),
      );
    }

    final count = math.min(urls.length, 3);
    final width = _size + (count - 1) * _overlap;

    return SizedBox(
      width: width,
      height: _size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < count; i++)
            Positioned(
              left: i * _overlap,
              child: _AvatarCircle(url: urls[i]),
            ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _DriverAvatarCluster._size,
      height: _DriverAvatarCluster._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.9),
          width: 1.5,
        ),
        color: AppTheme.primaryBlue.withValues(alpha: 0.12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.person,
          color: AppTheme.primaryBlue,
          size: 22,
        ),
      ),
    );
  }
}
