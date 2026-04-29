import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/driver_repository_impl.dart';
import '../../data/repositories/ride_repository_impl.dart';
import '../../data/repositories/user_repository_impl.dart';
import '../../domain/repositories/driver_repository.dart';
import '../../domain/repositories/ride_repository.dart';
import '../../domain/repositories/user_repository.dart';
import '../../presentation/bloc/auth/auth_bloc.dart';
import '../../presentation/cubit/passenger_driver_mode_cubit.dart';
import '../../presentation/bloc/client_ride/client_ride_bloc.dart';
import '../../presentation/bloc/driver_stats/driver_stats_cubit.dart';
import '../../presentation/bloc/driver_status/driver_status_bloc.dart';
import '../../presentation/bloc/driver_wallet/driver_wallet_cubit.dart';
import '../../presentation/bloc/ride_history/ride_history_cubit.dart';
import '../services/places_service.dart';
import '../services/storage_service.dart';

final sl = GetIt.instance;

/// Registra dependencias tras [Supabase.initialize].
Future<void> initDI() async {
  // Core / externo
  sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);

  // Servicios
  sl.registerLazySingleton<PlacesService>(PlacesService.new);
  sl.registerLazySingleton<StorageService>(() => StorageService(sl()));

  // Repositorios
  sl.registerLazySingleton<UserRepository>(() => UserRepositoryImpl());
  sl.registerLazySingleton<RideRepository>(() => RideRepositoryImpl());
  sl.registerLazySingleton<DriverRepository>(() => DriverRepositoryImpl());

  sl.registerLazySingleton<PassengerDriverModeCubit>(
    PassengerDriverModeCubit.new,
  );

  // BLoCs
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(
      userRepository: sl(),
      storageService: sl(),
    ),
  );
  sl.registerFactory<DriverStatusBloc>(
    () => DriverStatusBloc(rideRepository: sl()),
  );
  sl.registerFactory<DriverStatsCubit>(
    () => DriverStatsCubit(
      rideRepository: sl(),
      driverRepository: sl(),
    ),
  );
  sl.registerFactory<DriverWalletCubit>(
    () => DriverWalletCubit(driverRepository: sl()),
  );
  sl.registerFactory<ClientRideBloc>(
    () => ClientRideBloc(
      placesService: sl(),
      rideRepository: sl(),
    ),
  );
  sl.registerFactory<RideHistoryCubit>(
    () => RideHistoryCubit(rideRepository: sl()),
  );
}
