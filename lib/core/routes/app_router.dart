import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../di/injection_container.dart' as di;
import '../../presentation/bloc/auth/auth_bloc.dart';
import '../../presentation/bloc/auth/auth_state.dart';
import '../../presentation/cubit/passenger_driver_mode_cubit.dart';
import 'go_router_refresh.dart';
import '../../presentation/bloc/driver_stats/driver_stats_cubit.dart';
import '../../presentation/bloc/driver_status/driver_status_bloc.dart';
import '../../presentation/bloc/driver_wallet/driver_wallet_cubit.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/login/login_screen.dart';
import '../../presentation/screens/register/driver_register_screen.dart';
import '../../presentation/screens/register/client_register_screen.dart';
import '../../presentation/screens/sms_verification/sms_verification_screen.dart';
import '../../presentation/screens/auth/register_profile_screen.dart';
import '../../presentation/screens/auth/driver_approval_screen.dart';
import '../../presentation/screens/driver_dashboard/driver_dashboard_screen.dart';
import '../../presentation/screens/client_dashboard/client_dashboard_screen.dart';
import '../../presentation/screens/client/client_profile_screen.dart';
import '../../presentation/screens/client/client_wallet_screen.dart';
import '../../presentation/screens/client/client_trips_screen.dart';
import '../../presentation/screens/client/client_favorites_screen.dart';
import '../../presentation/screens/client/client_settings_screen.dart';
import '../../presentation/screens/client/client_help_screen.dart';
import '../../presentation/screens/client/client_support_screen.dart';
import '../../presentation/screens/history/ride_history_screen.dart';
import '../../presentation/screens/driver/become_driver_screen.dart';
import '../../presentation/screens/driver/driver_rejected_documents_screen.dart';
import '../../presentation/screens/driver/driver_route_placeholder_screen.dart';
import '../../presentation/screens/driver_profile/driver_profile_screen.dart';
import '../../presentation/screens/driver_wallet/driver_wallet_screen.dart';
import '../../presentation/screens/driver_support/driver_support_screen.dart';
import '../../presentation/screens/driver_help/driver_help_screen.dart';
import '../../presentation/screens/driver_settings/driver_settings_screen.dart';

class AppRouter {
  /// Rutas del panel conductor: mismos valores que [GoRoute.path] (guiones bajos).
  static const String driverProfilePath = '/driver_profile';
  static const String driverWalletPath = '/driver_wallet';
  static const String driverSupportPath = '/driver_support';
  static const String driverHelpPath = '/driver_help';
  static const String driverSettingsPath = '/driver_settings';

  static const String driverApprovalPath = '/driver_approval';
  static const String driverRejectedDocsPath = '/driver_rejected_documents';

  static DateTime? _parseIsoDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static bool _isPublicPath(String path) {
    return path == '/splash' ||
        path == '/login' ||
        path == '/driver-register' ||
        path == '/client-register' ||
        path == '/register' ||
        path.startsWith('/sms-verification');
  }

  static bool _isDriverExclusivePath(String path) {
    return path == '/dashboard' ||
        path == driverProfilePath ||
        path == driverWalletPath ||
        path == driverSupportPath ||
        path == driverHelpPath ||
        path == driverSettingsPath ||
        path == driverRejectedDocsPath ||
        path == '/city_requests';
  }

  static bool _hasRejectedDocuments(AuthState state) {
    if (state is! AuthAuthenticated) return false;
    bool isRejected(String value) => value.trim().toUpperCase() == 'REJECTED';
    final user = state.user;
    return isRejected(user.dniFrontStatus) ||
        isRejected(user.dniBackStatus) ||
        isRejected(user.licenseStatus) ||
        isRejected(user.soatStatus) ||
        isRejected(user.propertyCardStatus);
  }

  static String? _authRedirect(
    AuthBloc authBloc,
    PassengerDriverModeCubit modeCubit,
    GoRouterState state,
  ) {
    final path = state.uri.path;
    final authState = authBloc.state;

    if (authState is AuthLoading) {
      return null;
    }

    // Durante la subida de fotos del conductor el estado no es AuthAuthenticated;
    // sin esta excepción, [GoRouter] redirige a /login y parece que la app "reinicia".
    if (authState is AuthUploadingDriverDocs) {
      return null;
    }

    // Cualquier error de auth no debe forzar /login: la UI muestra el mensaje en la misma pantalla.
    if (authState is AuthError) {
      return null;
    }

    if (authState is! AuthAuthenticated) {
      if (_isPublicPath(path)) {
        return null;
      }
      if (path == driverApprovalPath) {
        return '/login';
      }
      return '/login';
    }

    final user = authState.user;
    final mode = modeCubit.state;

    if (shouldUseDriverHome(user, mode)) {
      if (path == '/become-driver') {
        if (_hasRejectedDocuments(authState)) return null;
        return '/dashboard';
      }
      if (user.isBanned) {
        final onBannedScreen = path == driverApprovalPath &&
            state.uri.queryParameters['banned'] == '1';
        if (onBannedScreen) {
          return null;
        }
        return '$driverApprovalPath?banned=1';
      }
      if (!user.isApproved) {
        final onPendingScreen = path == driverApprovalPath &&
            state.uri.queryParameters['banned'] != '1';
        if (onPendingScreen) {
          return null;
        }
        return driverApprovalPath;
      }
      if (path == driverApprovalPath) {
        return '/dashboard';
      }
      if (path.startsWith('/client')) {
        return '/dashboard';
      }
      return null;
    }

    // Interfaz pasajero (cliente solo o conductor en modo «pedir taxi»)
    if (path == driverApprovalPath || _isDriverExclusivePath(path)) {
      return '/client-dashboard';
    }
    return null;
  }

  static GoRouter createRouter(
    AuthBloc authBloc,
    PassengerDriverModeCubit modeCubit,
  ) {
    final refresh = GoRouterRefreshCombined(authBloc, modeCubit);
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: refresh,
      redirect: (context, state) => _authRedirect(authBloc, modeCubit, state),
      routes: [
        GoRoute(
          path: '/splash',
          name: 'splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/driver-register',
          name: 'driver-register',
          builder: (context, state) => DriverRegisterScreen(
            initialPhone: state.uri.queryParameters['phone'],
          ),
        ),
        GoRoute(
          path: '/client-register',
          name: 'client-register',
          builder: (context, state) => const ClientRegisterScreen(),
        ),
        GoRoute(
          path: '/sms-verification',
          name: 'sms-verification',
          builder: (context, state) {
            final phoneNumber = state.uri.queryParameters['phone'] ?? '';
            final role = state.uri.queryParameters['role'] ?? '';
            return SmsVerificationScreen(
              phoneNumber: phoneNumber,
              role: role,
              firstName: state.uri.queryParameters['first_name'],
              lastName: state.uri.queryParameters['last_name'],
              email: state.uri.queryParameters['email'],
              dni: state.uri.queryParameters['dni'],
              carBrand: state.uri.queryParameters['car_brand'],
              carPlate: state.uri.queryParameters['car_plate'],
              carModel: state.uri.queryParameters['car_model'],
              carYear: state.uri.queryParameters['car_year'],
              soatExpiration: state.uri.queryParameters['soat_expiration'],
              propertyCardExpiration:
                  state.uri.queryParameters['property_card_expiration'],
              technicalReviewExpiration:
                  state.uri.queryParameters['technical_review_expiration'],
              licenseCategory: state.uri.queryParameters['license_category'],
              licenseNumber: state.uri.queryParameters['license_number'],
              birthDate: state.uri.queryParameters['birth_date'],
            );
          },
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) {
            final extra = state.extra;
            if (extra is Map) {
              final phone = extra['phone']?.toString() ?? '';
              final carYearRaw = extra['car_year']?.toString();
              return RegisterProfileScreen(
                phone: phone,
                prefilledRole: extra['role']?.toString(),
                prefilledFirstName: extra['first_name']?.toString(),
                prefilledLastName: extra['last_name']?.toString(),
                prefilledEmail: extra['email']?.toString(),
                prefilledDni: extra['dni']?.toString(),
                prefilledCarBrand: extra['car_brand']?.toString(),
                prefilledCarPlate: extra['car_plate']?.toString(),
                prefilledCarModel: extra['car_model']?.toString(),
                prefilledCarYear: carYearRaw != null && carYearRaw.isNotEmpty
                    ? int.tryParse(carYearRaw)
                    : null,
                prefilledSoatExpiration: _parseIsoDate(
                  extra['soat_expiration']?.toString(),
                ),
                prefilledPropertyCardExpiration: _parseIsoDate(
                  extra['property_card_expiration']?.toString(),
                ),
                prefilledTechnicalReviewExpiration: _parseIsoDate(
                  extra['technical_review_expiration']?.toString(),
                ),
                prefilledLicenseCategory: extra['license_category']?.toString(),
                prefilledLicenseNumber: extra['license_number']?.toString(),
                prefilledBirthDate: _parseIsoDate(
                  extra['birth_date']?.toString(),
                ),
                prefilledDniFrontLocalPath: extra['dni_front_path']?.toString(),
                prefilledDniBackLocalPath: extra['dni_back_path']?.toString(),
                prefilledLicenseLocalPath: extra['license_path']?.toString(),
                prefilledSoatLocalPath: extra['soat_path']?.toString(),
                prefilledPropertyCardLocalPath:
                    extra['property_card_path']?.toString(),
                prefilledProfilePicLocalPath:
                    extra['profile_pic_path']?.toString(),
              );
            }
            final phone = extra is String ? extra : '';
            return RegisterProfileScreen(phone: phone);
          },
        ),
        GoRoute(
          path: driverApprovalPath,
          name: 'driver_approval',
          builder: (context, state) {
            final banned = state.uri.queryParameters['banned'] == '1';
            return DriverApprovalScreen(isBanned: banned);
          },
        ),
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<DriverStatsCubit>(
                create: (_) => di.sl<DriverStatsCubit>(),
              ),
              BlocProvider<DriverStatusBloc>(
                create: (_) => di.sl<DriverStatusBloc>(),
              ),
              BlocProvider<DriverWalletCubit>(
                create: (_) => di.sl<DriverWalletCubit>(),
              ),
            ],
            child: const DriverDashboardScreen(),
          ),
        ),
        GoRoute(
          path: driverProfilePath,
          name: 'driver_profile',
          builder: (context, state) => const DriverProfileScreen(),
        ),
        GoRoute(
          path: '/client-dashboard',
          name: 'client-dashboard',
          builder: (context, state) => const ClientDashboardScreen(),
        ),
        GoRoute(
          path: '/become-driver',
          name: 'become-driver',
          builder: (context, state) => BecomeDriverScreen(
            initialDocumentToFix: state.uri.queryParameters['doc'],
          ),
        ),
        GoRoute(
          path: driverRejectedDocsPath,
          name: 'driver-rejected-documents',
          builder: (context, state) => const DriverRejectedDocumentsScreen(),
        ),
        GoRoute(
          path: '/client-profile',
          name: 'client-profile',
          builder: (context, state) => const ClientProfileScreen(),
        ),
        GoRoute(
          path: '/client-wallet',
          name: 'client-wallet',
          builder: (context, state) => const ClientWalletScreen(),
        ),
        GoRoute(
          path: '/client-trips',
          name: 'client-trips',
          builder: (context, state) => const ClientTripsScreen(),
        ),
        GoRoute(
          path: '/client-favorites',
          name: 'client-favorites',
          builder: (context, state) => const ClientFavoritesScreen(),
        ),
        GoRoute(
          path: '/client-settings',
          name: 'client-settings',
          builder: (context, state) => const ClientSettingsScreen(),
        ),
        GoRoute(
          path: '/client-help',
          name: 'client-help',
          builder: (context, state) => const ClientHelpScreen(),
        ),
        GoRoute(
          path: '/client-support',
          name: 'client-support',
          builder: (context, state) => const ClientSupportScreen(),
        ),
        GoRoute(
          path: '/history',
          name: 'history',
          builder: (context, state) {
            String userId = '';
            String role = 'client';
            final extra = state.extra;
            if (extra is Map) {
              userId = extra['userId']?.toString() ?? '';
              role = extra['role']?.toString() ?? 'client';
            }
            return RideHistoryScreen(
              userId: userId,
              role: role,
            );
          },
        ),
        GoRoute(
          path: '/city_requests',
          name: 'city_requests',
          builder: (context, state) => const DriverRoutePlaceholderScreen(
            title: 'Ciudad (solicitudes)',
          ),
        ),
        GoRoute(
          path: driverWalletPath,
          name: 'driver_wallet',
          builder: (context, state) => BlocProvider(
            create: (_) {
              final cubit = di.sl<DriverWalletCubit>();
              final auth = context.read<AuthBloc>().state;
              if (auth is AuthAuthenticated) {
                cubit.loadWallet(auth.user.id);
              }
              return cubit;
            },
            child: const DriverWalletScreen(),
          ),
        ),
        GoRoute(
          path: driverSupportPath,
          name: 'driver_support',
          builder: (context, state) => const DriverSupportScreen(),
        ),
        GoRoute(
          path: driverHelpPath,
          name: 'driver_help',
          builder: (context, state) => const DriverHelpScreen(),
        ),
        GoRoute(
          path: driverSettingsPath,
          name: 'driver_settings',
          builder: (context, state) => const DriverSettingsScreen(),
        ),
      ],
    );
  }
}
