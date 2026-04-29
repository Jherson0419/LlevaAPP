import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_state.dart';

/// Perfil del conductor (vehículo, documentos, ciudad).
class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.darkText),
          onPressed: () => context.pop(),
        ),
        title: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (p, c) =>
              p.runtimeType != c.runtimeType ||
              (p is AuthAuthenticated &&
                  c is AuthAuthenticated &&
                  p.user.fullName != c.user.fullName),
          builder: (context, auth) {
            final name =
                auth is AuthAuthenticated ? auth.user.fullName : 'Conductor';
            return Text(
              name,
              style: const TextStyle(
                color: AppTheme.darkText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.darkSurfaceElevated,
                child: const Icon(
                  Icons.person,
                  color: AppTheme.primaryBlue,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Mis vehículos',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            color: AppTheme.darkSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const ListTile(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Icon(
                Icons.directions_car,
                color: AppTheme.primaryBlue,
                size: 32,
              ),
              title: Text(
                'Chevrolet',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Onix RS 2025',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(
                Icons.schedule,
                color: Colors.orangeAccent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estamos verificando tus documentos',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            color: AppTheme.darkSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: const ListTile(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Icon(
                Icons.location_city,
                color: AppTheme.primaryBlue,
                size: 28,
              ),
              title: Text(
                'Ciudad de trabajo',
                style: TextStyle(
                  color: AppTheme.darkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Trujillo',
                style: TextStyle(
                  color: AppTheme.darkTextSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
