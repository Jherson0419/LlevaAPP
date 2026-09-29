# Flujo de Arranque, Autenticación y Enrutamiento — Lleva

*Basado en la lectura completa de: [lib/main.dart](lib/main.dart), [lib/core/routes/app_router.dart](lib/core/routes/app_router.dart), [lib/core/routes/go_router_refresh.dart](lib/core/routes/go_router_refresh.dart), [lib/core/di/injection_container.dart](lib/core/di/injection_container.dart), [lib/presentation/bloc/auth/auth_bloc.dart](lib/presentation/bloc/auth/auth_bloc.dart), [auth_state.dart](lib/presentation/bloc/auth/auth_state.dart), [auth_event.dart](lib/presentation/bloc/auth/auth_event.dart), [lib/presentation/cubit/passenger_driver_mode_cubit.dart](lib/presentation/cubit/passenger_driver_mode_cubit.dart), [lib/presentation/screens/splash/splash_screen.dart](lib/presentation/screens/splash/splash_screen.dart), [login_screen.dart](lib/presentation/screens/login/login_screen.dart), [client_dashboard_screen.dart](lib/presentation/screens/client_dashboard/client_dashboard_screen.dart), [driver_dashboard_screen.dart](lib/presentation/screens/driver_dashboard/driver_dashboard_screen.dart), y todas las pantallas referenciadas por `_authRedirect`: [driver_approval_screen.dart](lib/presentation/screens/auth/driver_approval_screen.dart), [register_profile_screen.dart](lib/presentation/screens/auth/register_profile_screen.dart), [driver_register_screen.dart](lib/presentation/screens/register/driver_register_screen.dart), [client_register_screen.dart](lib/presentation/screens/register/client_register_screen.dart), [sms_verification_screen.dart](lib/presentation/screens/sms_verification/sms_verification_screen.dart), [driver_rejected_documents_screen.dart](lib/presentation/screens/driver/driver_rejected_documents_screen.dart), [become_driver_screen.dart](lib/presentation/screens/driver/become_driver_screen.dart) — además de [client_ride_bloc.dart](lib/presentation/bloc/client_ride/client_ride_bloc.dart) y [driver_status_bloc.dart](lib/presentation/bloc/driver_status/driver_status_bloc.dart) para los pasos de "recuperar viaje activo".*

⚠️ **Corrección sobre la nomenclatura esperada**: el proyecto **no tiene un evento `AppStarted`**. `AuthBloc` nace en `AuthInitial` ([auth_bloc.dart:32](lib/presentation/bloc/auth/auth_bloc.dart#L32)) y permanece así hasta que algo dispara explícitamente `CheckAuthStatus` — y quien lo dispara es `SplashScreen`, no el propio BLoC ni `main.dart`. Esto se detalla en la sección 2.

---

## 1. Arranque de la app

Todo ocurre en `Future<void> main()` ([lib/main.dart:19-62](lib/main.dart#L19-L62)), en este orden exacto:

1. **`WidgetsFlutterBinding.ensureInitialized()`** — [main.dart:20](lib/main.dart#L20).
2. **Verificación de credenciales Supabase** — [main.dart:26-31](lib/main.dart#L26-L31): si `AppConstants.supabaseUrl` o `AppConstants.supabaseAnonKey` están vacíos (no se pasó `--dart-define-from-file=.env`), se lanza un `StateError` y **la app no arranca**. No hay valores por defecto ni modo degradado.
3. **Ajuste de renderizado de Google Maps en Android** — [main.dart:36-41](lib/main.dart#L36-L41): si la plataforma es Android, castea `GoogleMapsFlutterPlatform.instance` a `GoogleMapsFlutterAndroid` y fuerza `useAndroidViewSurface = false` (evita que el mapa se vea negro en algunos dispositivos, a costa del orden de capas).
4. **`Supabase.initialize(url:, anonKey:)`** — [main.dart:44-47](lib/main.dart#L44-L47). A partir de aquí `Supabase.instance.client` existe y puede usarse.
5. **`await di.initDI()`** — [main.dart:49](lib/main.dart#L49). Ver detalle completo en la tabla de abajo. Se ejecuta **después** de `Supabase.initialize` porque `injection_container.dart` registra `SupabaseClient` como `sl<SupabaseClient>(() => Supabase.instance.client)` — si se invirtiera el orden, esa fábrica fallaría al resolverse.
6. **`SystemChrome.setSystemUIOverlayStyle(...)`** — [main.dart:52-59](lib/main.dart#L52-L59): fuerza barra de estado/navegación en modo oscuro (iconos claros, fondo transparente/negro).
7. **`runApp(const LlevaApp())`** — [main.dart:61](lib/main.dart#L61).

### 1.1 `initDI()` — orden de registro (`lib/core/di/injection_container.dart:23-69`)

No hay dependencias circulares porque `get_it` resuelve perezosamente (`registerLazySingleton`), pero el orden textual en el archivo es:

| # | Registro | Tipo | Línea |
|---|---|---|---|
| 1 | `SupabaseClient` → `Supabase.instance.client` | lazy singleton | [25](lib/core/di/injection_container.dart#L25) |
| 2 | `PlacesService` | lazy singleton | [28](lib/core/di/injection_container.dart#L28) |
| 3 | `StorageService(sl<SupabaseClient>())` | lazy singleton | [29](lib/core/di/injection_container.dart#L29) |
| 4 | `UserRepository` → `UserRepositoryImpl()` | lazy singleton | [32](lib/core/di/injection_container.dart#L32) |
| 5 | `RideRepository` → `RideRepositoryImpl()` | lazy singleton | [33](lib/core/di/injection_container.dart#L33) |
| 6 | `DriverRepository` → `DriverRepositoryImpl()` | lazy singleton | [34](lib/core/di/injection_container.dart#L34) |
| 7 | `PassengerDriverModeCubit` | lazy singleton | [36-38](lib/core/di/injection_container.dart#L36-L38) |
| 8 | `AuthBloc(userRepository:, storageService:, supabaseClient:)` | **factory** | [41-47](lib/core/di/injection_container.dart#L41-L47) |
| 9 | `DriverStatusBloc(rideRepository:)` | **factory** | [48-50](lib/core/di/injection_container.dart#L48-L50) |
| 10 | `DriverStatsCubit(rideRepository:, driverRepository:)` | **factory** | [51-56](lib/core/di/injection_container.dart#L51-L56) |
| 11 | `DriverWalletCubit(driverRepository:)` | **factory** | [57-59](lib/core/di/injection_container.dart#L57-L59) |
| 12 | `ClientRideBloc(placesService:, rideRepository:)` | **factory** | [60-65](lib/core/di/injection_container.dart#L60-L65) |
| 13 | `RideHistoryCubit(rideRepository:)` | **factory** | [66-68](lib/core/di/injection_container.dart#L66-L68) |

*Singleton* = una única instancia viva durante toda la vida de la app. *Factory* = nueva instancia cada vez que se llama `di.sl<T>()` (típicamente una vez por ruta/pantalla).

### 1.2 Qué se provee globalmente desde el arranque

Solo **dos** providers viven en la raíz del árbol de widgets, en `LlevaApp.build()` ([main.dart:76-80](lib/main.dart#L76-L80)):

```dart
MultiBlocProvider(
  providers: [
    BlocProvider(create: (_) => di.sl<AuthBloc>()),
    BlocProvider(create: (_) => di.sl<PassengerDriverModeCubit>()),
  ],
  ...
)
```

- **`AuthBloc`** — una única instancia para toda la sesión de la app (aunque esté registrado como `factory` en DI, `di.sl<AuthBloc>()` solo se llama una vez aquí).
- **`PassengerDriverModeCubit`** — ya es singleton en DI; aquí solo se expone vía `BlocProvider`.

Todo lo demás (`ClientRideBloc`, `DriverStatusBloc`, `DriverStatsCubit`, `DriverWalletCubit`, `RideHistoryCubit`) se provee **más abajo en el árbol**, dentro de los `GoRoute.builder` de cada ruta (ver secciones 3 y 4).

Envolviendo el `MultiBlocProvider` está `_AuthLifecycleRefresh` ([main.dart:103-135](lib/main.dart#L103-L135)), un `StatefulWidget` con `WidgetsBindingObserver` que, en `didChangeAppLifecycleState`, si `state == AppLifecycleState.resumed`, dispara `context.read<AuthBloc>().add(const RefreshProfileEvent())` ([main.dart:127-130](lib/main.dart#L127-L130)) — es decir, **cada vez que la app vuelve a primer plano se refresca el perfil** desde Supabase (útil para reflejar aprobaciones/rechazos hechos por el ERP mientras la app estaba en background).

Dentro de esto, un `Builder` construye el `GoRouter` **una sola vez** con patrón *lazy-init*:

```dart
_router ??= AppRouter.createRouter(
  context.read<AuthBloc>(),
  context.read<PassengerDriverModeCubit>(),
);
```
([main.dart:84-87](lib/main.dart#L84-L87)) — y ese router se pasa a `MaterialApp.router(routerConfig: _router!)` ([main.dart:88-94](lib/main.dart#L88-L94)).

---

## 2. Flujo: primera vez (usuario sin sesión)

1. `GoRouter` se crea con `initialLocation: '/splash'` ([app_router.dart:165](lib/core/routes/app_router.dart#L165)) → se monta `SplashScreen`.
2. `SplashScreen.build()` ([splash_screen.dart:21-25](lib/presentation/screens/splash/splash_screen.dart#L21-L25)):
   ```dart
   if (!_requested) {
     _requested = true;
     context.read<AuthBloc>().add(const CheckAuthStatus());
   }
   ```
   Esta es la **única** vía por la que se dispara la verificación de sesión — no ocurre automáticamente al construir `AuthBloc` en el paso 1.2. `_requested` es una bandera de instancia que evita reenviar el evento en cada rebuild.
3. `AuthBloc._onCheckAuthStatus` ([auth_bloc.dart:173-202](lib/presentation/bloc/auth/auth_bloc.dart#L173-L202)):
   - Emite `AuthLoading` ([línea 178](lib/presentation/bloc/auth/auth_bloc.dart#L178)).
   - Lee `_supabase.auth.currentSession?.user.id` ([línea 183](lib/presentation/bloc/auth/auth_bloc.dart#L183)) — **no** usa `SharedPreferences`; la sesión real la persiste el propio SDK de Supabase Auth (JWT en su storage interno).
   - Como es la primera vez, no hay sesión → `authUid` es `null` → emite `AuthInitial` ([línea 185-186](lib/presentation/bloc/auth/auth_bloc.dart#L185-L186)) y retorna.
4. **Redirect del `GoRouter`** — cada cambio de estado de `AuthBloc` notifica a `GoRouterRefreshCombined` (que escucha `authBloc.stream`, [go_router_refresh.dart:12](lib/core/routes/go_router_refresh.dart#L12)), lo que reevalúa `_authRedirect` ([app_router.dart:86-157](lib/core/routes/app_router.dart#L86-L157)) para la ruta actual (`/splash`):
   - `authState is AuthLoading` → `return null` ([línea 94-96](lib/core/routes/app_router.dart#L94-L96)) — no redirige mientras carga.
   - Tras `AuthInitial`: `authState is! AuthAuthenticated` es verdadero → como `/splash` **sí** está en `_isPublicPath` ([línea 56](lib/core/routes/app_router.dart#L56)) → `return null` ([línea 110-112](lib/core/routes/app_router.dart#L110-L112)). El router **no mueve** la app de `/splash` por sí solo.
5. La navegación real la hace el `BlocListener<AuthBloc, AuthState>` propio de `SplashScreen` ([splash_screen.dart:27-39](lib/presentation/screens/splash/splash_screen.dart#L27-L39)):
   ```dart
   } else if (state is AuthInitial || state is AuthError) {
     context.go('/login');
   }
   ```
6. Al llegar a `/login`, `_authRedirect` se reevalúa: `/login` también está en `_isPublicPath` → `null` → no hay redirección adicional. **`LoginScreen` es la primera pantalla que ve un usuario sin sesión.**

---

## 3. Flujo: usuario cliente (sesión existente)

1. Pasos 1-2 idénticos a la sección anterior: `SplashScreen` dispara `CheckAuthStatus`.
2. `AuthBloc._onCheckAuthStatus`: esta vez `_supabase.auth.currentSession?.user.id` **sí** devuelve un `authUid` (el JWT de Supabase Auth sigue vigente desde el login anterior — no hay rehidratación manual desde `SharedPreferences`; ese mecanismo fue retirado explícitamente, ver comentario en [auth_bloc.dart:179-182](lib/presentation/bloc/auth/auth_bloc.dart#L179-L182)).
3. Se llama `_userRepository.getUserById(authUid)` ([línea 189](lib/presentation/bloc/auth/auth_bloc.dart#L189)) → `UserRepositoryImpl.getUserById` hace `SELECT * FROM profiles WHERE id = authUid`.
4. Si el perfil existe → `emit(AuthAuthenticated(user))` ([línea 190-191](lib/presentation/bloc/auth/auth_bloc.dart#L190-L191)). Con `user.role == 'client'`.
5. `SplashScreen`'s `BlocListener` ([splash_screen.dart:29-35](lib/presentation/screens/splash/splash_screen.dart#L29-L35)):
   ```dart
   if (state is AuthAuthenticated) {
     final mode = context.read<PassengerDriverModeCubit>().state;
     if (shouldUseDriverHome(state.user, mode)) {
       context.go('/dashboard');
     } else {
       context.go('/client-dashboard');
     }
   }
   ```
   Para un cliente puro (sin vehículo/solicitud de conductor), `shouldUseDriverHome` ([passenger_driver_mode_cubit.dart:55-68](lib/presentation/cubit/passenger_driver_mode_cubit.dart#L55-L68)) es `false` → `context.go('/client-dashboard')`.
6. **Redirect de seguridad**: al llegar a `/client-dashboard` con `AuthAuthenticated`, `_authRedirect` reevalúa la rama pasajero ([app_router.dart:152-156](lib/core/routes/app_router.dart#L152-L156)): la ruta no es `/driver_approval` ni una de `_isDriverExclusivePath` → `return null` → se queda en `/client-dashboard`.
7. **`ClientDashboardScreen` es la primera pantalla del cliente.** Su `build()` ([client_dashboard_screen.dart:78-172](lib/presentation/screens/client_dashboard/client_dashboard_screen.dart#L78-L172)):
   - Lee el `clientId` de forma síncrona: `context.read<AuthBloc>().state` → `authState.user.id.trim()` ([líneas 80-82](lib/presentation/screens/client_dashboard/client_dashboard_screen.dart#L80-L82)).
   - Provee `ClientRideBloc` con dos eventos encolados inmediatamente:
     ```dart
     BlocProvider(
       create: (_) => di.sl<ClientRideBloc>()
         ..add(const InitializePickupFromCurrentLocation())
         ..add(CheckActiveRide(clientId)),
       ...
     )
     ```
     ([líneas 83-86](lib/presentation/screens/client_dashboard/client_dashboard_screen.dart#L83-L86)).
   - Además, en `initState()` ([líneas 46-49](lib/presentation/screens/client_dashboard/client_dashboard_screen.dart#L46-L49)), un `postFrameCallback` dispara `AuthBloc.add(const RefreshProfileEvent())` — refresco adicional del perfil al montar el dashboard.

### 3.1 BLoC instanciado para el dashboard del cliente

Solo **`ClientRideBloc`** se provee explícitamente aquí (vía `BlocProvider` local a `ClientDashboardScreen`, no en el `GoRoute` como en el caso del conductor). El resto de BLoCs de pasajero (`RideHistoryCubit`) se instancian bajo demanda al navegar a `/history` desde el drawer.

### 3.2 Qué hace `ClientRideBloc` al iniciar

- **`InitializePickupFromCurrentLocation`** → `_onInitializePickupFromCurrentLocation` ([client_ride_bloc.dart:186-206](lib/presentation/bloc/client_ride/client_ride_bloc.dart#L186-L206)): si `state.originLatLng` ya tiene valor, no hace nada; si no, llama `LocationHelper.determinePosition()` (pide permisos GPS si hace falta), hace *reverse geocoding* con `PlacesService.reverseGeocode`, y emite el estado con `originLatLng`/`originName` poblados. Si falla (p. ej. sin permiso), el `catch` está vacío — no bloquea el flujo.
- **`CheckActiveRide(clientId)`** → `_onCheckActiveRide` ([client_ride_bloc.dart:752-829](lib/presentation/bloc/client_ride/client_ride_bloc.dart#L752-L829)) — **sí, recupera un viaje activo**:
  1. Si `clientId` está vacío, retorna.
  2. `_rideRepository.getActiveRideByClientId(clientId)` — consulta `rides` con `client_id = ?` y `status IN ('searching','accepted','negotiating','arrived','ongoing')`, ordenado por `created_at DESC`, primera fila.
  3. Si no hay ninguno, retorna sin cambios (el usuario ve el flujo normal desde `initial`).
  4. Si hay uno, se descarta si es "viejo": `DateTime.now().toUtc().difference(recovered.createdAt.toUtc()) >= _requestRecoveryWindow` (15 minutos, [línea 26](lib/presentation/bloc/client_ride/client_ride_bloc.dart#L26)) — no se rehidrata una solicitud abandonada.
  5. Si es reciente, se suscribe a `subscribeToRide(recovered.id)` y, según `recovered.status`, emite el `ClientRideStatus` correspondiente:
     - `searching`/`negotiating` → además llama `_startListeningToRideOffers(recovered.id)` y emite `searchingDriver`.
     - `accepted` → emite `driverAssigned`.
     - `arrived` → emite `driverArrived`.
     - `ongoing` → emite `tripOngoing`.
  6. Cualquier error se registra con `developer.log` y se ignora silenciosamente (no rompe el arranque del dashboard).

---

## 4. Flujo: usuario conductor (sesión existente)

1. Pasos 1-4 idénticos a la sección 3: `SplashScreen` → `CheckAuthStatus` → `AuthBloc` emite `AuthAuthenticated(user)` con `user.role == 'driver'`.
2. **Diferenciación** en `SplashScreen`'s listener: `shouldUseDriverHome(state.user, mode)` ([passenger_driver_mode_cubit.dart:55-68](lib/presentation/cubit/passenger_driver_mode_cubit.dart#L55-L68)):
   ```dart
   bool shouldUseDriverHome(UserEntity u, PassengerDriverUi mode) {
     if (u.role == 'driver') {
       if (u.isBanned) return true;
       if (!u.isApproved) return true;
       if (userCanTogglePassengerDriver(u)) {
         return mode == PassengerDriverUi.driver;
       }
       return true;
     }
     ...
   }
   ```
   Para `role == 'driver'`, esta función es `true` en casi todos los casos (baneado, no aprobado, o aprobado sin capacidad de alternar) — la única forma de que sea `false` es que el conductor haya elegido activamente el modo pasajero (sección 5). Por tanto `context.go('/dashboard')`.
3. **Redirect de seguridad al llegar a `/dashboard`** — rama conductor de `_authRedirect` ([app_router.dart:122-150](lib/core/routes/app_router.dart#L122-L150)):
   - Si `user.isBanned` → redirige a `/driver_approval?banned=1` (`DriverApprovalScreen(isBanned: true)`), **no llega al dashboard**.
   - Si `!user.isApproved` → redirige a `/driver_approval` (`DriverApprovalScreen(isBanned: false)`), **no llega al dashboard**.
   - Si está aprobado y no baneado → ninguna condición aplica para `path == '/dashboard'` → `return null` → se queda.
4. **`DriverDashboardScreen` es la primera pantalla del conductor aprobado.** Pero, a diferencia del cliente, sus BLoCs **no** se proveen dentro de la propia pantalla, sino en el `GoRoute` de `/dashboard` ([app_router.dart:276-293](lib/core/routes/app_router.dart#L276-L293)):
   ```dart
   GoRoute(
     path: '/dashboard',
     builder: (context, state) => MultiBlocProvider(
       providers: [
         BlocProvider<DriverStatsCubit>(create: (_) => di.sl<DriverStatsCubit>()),
         BlocProvider<DriverStatusBloc>(create: (_) => di.sl<DriverStatusBloc>()),
         BlocProvider<DriverWalletCubit>(create: (_) => di.sl<DriverWalletCubit>()),
       ],
       child: const DriverDashboardScreen(),
     ),
   ),
   ```

### 4.1 BLoCs instanciados para el dashboard del conductor

`DriverStatsCubit`, `DriverStatusBloc`, `DriverWalletCubit` — las tres nuevas instancias (factories de DI), provistas por el `GoRoute`, no por la pantalla.

### 4.2 Qué hace `DriverDashboardScreen` al iniciar

En `initState()` ([driver_dashboard_screen.dart:66-84](lib/presentation/screens/driver_dashboard/driver_dashboard_screen.dart#L66-L84)), dentro de un `postFrameCallback`:
```dart
context.read<AuthBloc>().add(const RefreshProfileEvent());
final auth = context.read<AuthBloc>().state;
if (auth is AuthAuthenticated) {
  context.read<DriverStatsCubit>().loadTodayStats(auth.user.id);
  context.read<DriverWalletCubit>().loadWallet(auth.user.id);
  context.read<DriverStatusBloc>().add(RecoverDriverActiveRide(auth.user.id));
}
_loadCustomMapIcons(context);
```
Es decir: refresca perfil, carga estadísticas del día, carga saldo de cartera, **y solo entonces** intenta recuperar un viaje/oferta en curso.

### 4.3 Qué hace `DriverStatusBloc` al iniciar (`RecoverDriverActiveRide`)

`DriverStatusBloc` nace en el estado **`DriverOffline`** ([driver_status_bloc.dart:24](lib/presentation/bloc/driver_status/driver_status_bloc.dart#L24)) — recuperar un viaje activo **no** lo pone automáticamente en línea para recibir nuevas solicitudes; eso requiere una acción manual del conductor (`ToggleStatus`).

`_onRecoverDriverActiveRide` ([driver_status_bloc.dart:338-395](lib/presentation/bloc/driver_status/driver_status_bloc.dart#L338-L395)):

1. Si `driverId` está vacío, retorna.
2. **Primero** intenta `rideRepository.getPendingOfferContextForDriver(driverId)` — busca si el conductor tiene una oferta `pending` propia en `ride_offers` cuyo viaje siga `searching`. Si la encuentra:
   - Se suscribe a `listenToRideOffers` (para saber si la oferta es rechazada/retirada) y a `subscribeToRide` (para saber si el pasajero acepta).
   - Emite **`DriverWaitingForPassengerDecision`** directamente — el conductor reabre la app y ve la pantalla de "esperando respuesta del pasajero" sin haber tenido que reenviar la oferta.
3. **Si no hay oferta pendiente**, llama `rideRepository.getActiveRideByDriverId(driverId)` — busca un viaje con `driver_id = ?` y `status IN ('accepted','negotiating','arrived','ongoing')`.
   - Si existe, se suscribe a `subscribeToRide` y emite según el estado:
     - `accepted` → `DriverOnTrip` + `_startLocationTracking(recovered.id)` (retoma el reporte de GPS).
     - `arrived` → `DriverArrivedAtPickup` + tracking.
     - `ongoing` → `DriverTripInProgress` + tracking.
4. Si ninguna de las dos búsquedas encuentra nada, no se emite nada — el conductor queda en `DriverOffline`, viendo el toggle "No Disponible".

---

## 5. Flujo: conductor en modo pasajero

`PassengerDriverModeCubit` ([passenger_driver_mode_cubit.dart:11-42](lib/presentation/cubit/passenger_driver_mode_cubit.dart#L11-L42)) es un `Cubit<PassengerDriverUi>` **singleton** (registrado en DI, provisto globalmente en `LlevaApp`) cuyo único propósito es recordar si un conductor —que también puede pedir viajes— eligió usar la interfaz de pasajero.

- Estado inicial: `PassengerDriverUi.passenger` ([línea 12](lib/presentation/cubit/passenger_driver_mode_cubit.dart#L12)), pero inmediatamente `_restore()` ([líneas 18-25](lib/presentation/cubit/passenger_driver_mode_cubit.dart#L18-L25)) lee `SharedPreferences['passenger_driver_ui_mode']` y, si el valor guardado es `'driver'`, emite `PassengerDriverUi.driver`.
- `setDriverMode()` / `setPassengerMode()` ([líneas 27-41](lib/presentation/cubit/passenger_driver_mode_cubit.dart#L27-L41)) actualizan el estado **y** persisten la elección en `SharedPreferences` para la próxima vez que arranque la app.

### 5.1 Cuándo se activa

Se llama `setPassengerMode()` desde `DriverDrawer` cuando el conductor toca "Pedir taxi" ([driver_drawer.dart:245-253](lib/presentation/widgets/driver/driver_drawer.dart#L245-L253)), y `setDriverMode()` desde `ClientMenuActions.onEarnMoneyDriving` cuando un cliente-con-capacidad-de-alternar toca "Gana dinero conduciendo" ([client_menu_actions.dart:74-77](lib/presentation/widgets/client/client_menu_actions.dart#L74-L77)).

Solo importa cuando `userCanTogglePassengerDriver(u)` es verdadero ([passenger_driver_mode_cubit.dart:47-52](lib/presentation/cubit/passenger_driver_mode_cubit.dart#L47-L52)):
```dart
bool userCanTogglePassengerDriver(UserEntity u) {
  if (!u.isApproved || u.isBanned) return false;
  if (u.role == 'driver') return true;
  final hasVehicle = u.carPlate != null && u.carPlate!.trim().isNotEmpty;
  return u.role == 'client' && hasVehicle && u.isDriverApplicant;
}
```
Es decir: un conductor **aprobado y no baneado** siempre puede alternar; un cliente solo puede alternar si además tiene vehículo registrado y es solicitante de conductor (`is_driver_applicant`).

### 5.2 Cómo afecta al redirect del `GoRouter`

En `shouldUseDriverHome` ([passenger_driver_mode_cubit.dart:55-68](lib/presentation/cubit/passenger_driver_mode_cubit.dart#L55-L68)), cuando `userCanTogglePassengerDriver(u)` es verdadero, el resultado depende **exclusivamente** de `mode`:
```dart
if (userCanTogglePassengerDriver(u)) {
  return mode == PassengerDriverUi.driver;
}
```
`GoRouterRefreshCombined` escucha también `modeCubit.stream` ([go_router_refresh.dart:13](lib/core/routes/go_router_refresh.dart#L13)), así que **cambiar el modo dispara una reevaluación inmediata de `_authRedirect`** sin que cambie el estado de `AuthBloc`. Si el conductor está en `/dashboard` y toca "Pedir taxi": `mode` pasa a `passenger` → `shouldUseDriverHome` pasa a `false` → la rama pasajero del redirect ([app_router.dart:152-156](lib/core/routes/app_router.dart#L152-L156)) detecta que `/dashboard` está en `_isDriverExclusivePath` ([línea 65](lib/core/routes/app_router.dart#L65)) → redirige a `/client-dashboard`.

### 5.3 Qué dashboard ve y con qué BLoCs

Ve exactamente **`ClientDashboardScreen`**, con el mismo `ClientRideBloc` descrito en la sección 3 (no hay una tercera variante de dashboard para "conductor en modo pasajero" — reutiliza literalmente la pantalla y el BLoC del pasajero). Al volver a modo conductor, vuelve a `/dashboard` con `DriverStatusBloc`/`DriverStatsCubit`/`DriverWalletCubit` recreados desde cero por el `GoRoute` (nuevas instancias — el estado de negociación previo, si lo había, se pierde, salvo lo que `RecoverDriverActiveRide` pueda reconstruir desde Supabase).

---

## 6. Flujo: registro nuevo cliente

⚠️ **Hallazgo de navegación**: se verificó con búsqueda de referencias que **ninguna pantalla en `lib/` navega a `/client-register` o `/driver-register`** mediante `context.push`/`context.go` — ambas rutas están declaradas en `AppRouter` ([app_router.dart:179-190](lib/core/routes/app_router.dart#L179-L190)) y sus pantallas (`ClientRegisterScreen`, `DriverRegisterScreen`) están completamente implementadas, pero solo son alcanzables por *deep link* directo a esa URL, no desde ningún botón visible en el código leído. `LoginScreen` no tiene ningún enlace de "crear cuenta" ([login_screen.dart](lib/presentation/screens/login/login_screen.dart) completo revisado: solo campo de teléfono, botón "Continuar" y botones sociales sin implementar). El flujo que **sí** está conectado de punta a punta para un número nuevo es el siguiente:

1. **`LoginScreen`** — usuario ingresa teléfono de 9 dígitos → `_handleContinue()` ([login_screen.dart:35-51](lib/presentation/screens/login/login_screen.dart#L35-L51)) → `context.push('/sms-verification?phone=$phoneNumber&role=')` (nótese `role=` **vacío**).
2. **`SmsVerificationScreen`** — en `initState()` ([sms_verification_screen.dart:73-93](lib/presentation/screens/sms_verification/sms_verification_screen.dart#L73-L93)), tras cargar `PendingDriverDocuments.load()` (que devolverá `null`, no aplica a este flujo), un `postFrameCallback` dispara:
   ```dart
   context.read<AuthBloc>().add(SendOtpRequested(widget.phoneNumber));
   ```
   → `AuthBloc._onSendOtpRequested` ([auth_bloc.dart:73-100](lib/presentation/bloc/auth/auth_bloc.dart#L73-L100)) emite `AuthLoading`, llama `_supabase.auth.signInWithOtp(phone: _toE164(phone))` (agrega `+51`), y emite `AuthOtpSent(phone)`.
3. Usuario ingresa el código de 6 dígitos → al completarse, `_handleVerify()` dispara `context.read<AuthBloc>().add(OtpVerified(phone:, code:))`.
4. `AuthBloc._onOtpVerified` ([auth_bloc.dart:102-164](lib/presentation/bloc/auth/auth_bloc.dart#L102-L164)):
   - `_supabase.auth.verifyOTP(phone:, token: code, type: OtpType.sms)` — si es correcto, obtiene `authUid` real.
   - Busca `getUserById(authUid)` → no existe (número nuevo).
   - Busca `getUserByPhone(phone)` (compatibilidad legacy) → tampoco existe.
   - `emit(AuthNeedsRegistration(phone))` ([línea 145](lib/presentation/bloc/auth/auth_bloc.dart#L145)).
5. El `BlocListener` de `SmsVerificationScreen` ([sms_verification_screen.dart:227-269](lib/presentation/screens/sms_verification/sms_verification_screen.dart#L227-L269)) recibe `AuthNeedsRegistration`:
   - `_isDriverFullPackage()` → `false` (no hay `role`, `car_brand`, etc. en los query params).
   - `_isClientFullPackage()` → `false` (tampoco hay `first_name`, `dni`, etc.).
   - Cae al `else`: `context.push('/register', extra: state.phone)` ([línea 267](lib/presentation/screens/sms_verification/sms_verification_screen.dart#L267)) — pasa solo el teléfono como `String`.
6. **`RegisterProfileScreen`** — el `GoRoute` de `/register` ([app_router.dart:219-267](lib/core/routes/app_router.dart#L219-L267)) detecta que `extra` es un `String` (no un `Map`) y construye `RegisterProfileScreen(phone: extra)` sin ningún campo `prefilled*`.
   - `initState()` ([register_profile_screen.dart:150-175](lib/presentation/screens/auth/register_profile_screen.dart#L150-L175)): `_selectedRole = widget.prefilledRole == 'driver' ? 'driver' : 'client'` → como `prefilledRole` es `null`, **`_selectedRole` queda en `'client'`**. No existe en esta pantalla ningún control de UI que permita cambiarlo a `'driver'` cuando se llega por esta vía — confirmando que este camino solo produce registros de pasajero.
   - Como `_hasCompleteClientPackage` es `false`, `_needsManualClientFields` es `true` ([línea 142-143](lib/presentation/screens/auth/register_profile_screen.dart#L142-L143)) → se muestran los campos manuales: correo, DNI, fecha de nacimiento (validada con `AgeValidation.isAtLeastYearsOld(birthDate, 18)`).
   - Usuario completa el formulario y pulsa "Comenzar" → `_submit()` ([líneas 267-414](lib/presentation/screens/auth/register_profile_screen.dart#L267-L414)) dispara:
     ```dart
     context.read<AuthBloc>().add(RegisterUser(
       phone: widget.phone, fullName:, role: 'client', email:, dni:, birthDate:, ...
     ));
     ```
7. `AuthBloc._onRegisterUser` ([auth_bloc.dart:288-565](lib/presentation/bloc/auth/auth_bloc.dart#L288-L565)):
   - `isDriver = false` → se salta por completo el bloque de subida de documentos (líneas 400-497, exclusivo de `isDriver`).
   - Valida nombre (≥5 caracteres), correo, DNI (8 dígitos), fecha de nacimiento y mayoría de edad ([líneas 364-391](lib/presentation/bloc/auth/auth_bloc.dart#L364-L391)).
   - Emite `AuthLoading` ([línea 499](lib/presentation/bloc/auth/auth_bloc.dart#L499)).
   - Construye `UserModel` con `id: authUid` (del `Supabase.instance.client.auth.currentUser`, ya autenticado desde el paso 4), `role: 'client'`, `isApproved: true` (los clientes no requieren aprobación).
   - `_userRepository.createUserProfile(user)` → `INSERT INTO profiles ...` → `emit(AuthAuthenticated(created))`.
8. **Cómo se guarda la sesión**: no hay ningún `saveUserSession`/`SharedPreferences.setString` explícito en este flujo — la sesión "es" el JWT que Supabase Auth ya persistió internamente desde `verifyOTP()` en el paso 4. La próxima vez que arranque la app, el flujo de la sección 3 la recuperará automáticamente vía `_supabase.auth.currentSession`.
9. El `BlocConsumer` de `RegisterProfileScreen` ([líneas 850-867](lib/presentation/screens/auth/register_profile_screen.dart#L850-L867)) ve `AuthAuthenticated` con `role != 'driver'` → `context.go('/client-dashboard')`.
10. `_authRedirect` reevalúa: usuario autenticado, `shouldUseDriverHome` falso (rol cliente, sin capacidad de alternar) → sin coincidencias en la rama pasajero → `null` → **se queda en `/client-dashboard`**, mismo dashboard e inicialización de `ClientRideBloc` descritos en la sección 3.

---

## 7. Flujo: registro nuevo conductor

Este es el flujo **diseñado y completamente cableado** para conductores nuevos, aunque —según el hallazgo de la sección 6— no se encontró ningún botón en el código que navegue a `/driver-register`; se documenta tal como está implementado, asumiendo llegada por esa ruta (deep link o navegación pendiente de conectar en UI).

### 7.1 Pantallas en orden

1. **`DriverRegisterScreen`** (`/driver-register`) — formulario de **3 pasos** en un mismo `PageView` ([driver_register_screen.dart:475-489](lib/presentation/screens/register/driver_register_screen.dart#L475-L489)):
   - **Paso 1 — personales**: teléfono, nombre, apellidos, correo, DNI.
   - **Paso 2 — vehículo**: marca, modelo, placa, año (≥2005), **+ 2 fotos**: SOAT y tarjeta de propiedad (`_soatFile`, `_propertyCardFile`, obligatorias para avanzar — [línea 287](lib/presentation/screens/register/driver_register_screen.dart#L287)).
   - **Paso 3 — conducir**: categoría de licencia, número de brevete, 3 fechas de vencimiento (SOAT, tarjeta de propiedad, revisión técnica), **+ 4 fotos**: DNI frontal, DNI posterior, licencia, foto de perfil. Checkbox de términos.
2. Al pulsar "Comenzar", `_onComenzar()` ([líneas 323-431](lib/presentation/screens/register/driver_register_screen.dart#L323-L431)):
   - Valida los 3 formularios, categoría de licencia, las 3 fechas, aceptación de términos, y que **las 6 fotos** estén presentes.
   - `PendingDriverDocuments.save({...})` ([líneas 379-386](lib/presentation/screens/register/driver_register_screen.dart#L379-L386)) — guarda las **rutas locales** de las 6 imágenes en `SharedPreferences` (no las sube todavía; esto evita pasar rutas de archivo largas por la URL de navegación).
   - Construye un `Uri` hacia `/sms-verification` con `role=driver` + todos los campos de texto/fecha (sin las fotos) y navega: `context.push(uri.toString())` ([línea 430](lib/presentation/screens/register/driver_register_screen.dart#L430)).
3. **`SmsVerificationScreen`** — mismo flujo OTP que en la sección 6 (`SendOtpRequested` → código → `OtpVerified`), pero además:
   - `initState()` llama `PendingDriverDocuments.load()` de forma asíncrona y guarda el resultado en `_pendingDocPaths` ([líneas 77-84](lib/presentation/screens/sms_verification/sms_verification_screen.dart#L77-L84)); mientras no resuelve, `_awaitingPendingDocs` es `true` y bloquea la verificación con un `SnackBar` ("Cargando documentos, espera un momento") si el usuario intenta verificar antes de tiempo ([líneas 126-135](lib/presentation/screens/sms_verification/sms_verification_screen.dart#L126-L135)).
   - Tras `AuthNeedsRegistration`, `_isDriverFullPackage()` ([líneas 180-198](lib/presentation/screens/sms_verification/sms_verification_screen.dart#L180-L198)) evalúa `true` (todos los query params + `PendingDriverDocuments.isComplete(_pendingDocPaths)`) → navega con un `Map` completo como `extra`, incluyendo `..._pendingDocPaths!` (las 6 rutas locales) ([líneas 229-252](lib/presentation/screens/sms_verification/sms_verification_screen.dart#L229-L252)).
4. **`RegisterProfileScreen`** (`/register`) — esta vez `extra` es un `Map` → se construyen todos los `prefilled*` (incluyendo `prefilledDniFrontLocalPath`, etc., [app_router.dart:222-263](lib/core/routes/app_router.dart#L222-L263)).
   - `_hasCompleteDriverLegalPackage` es `true` (todos los campos + las 6 rutas locales presentes) → `_isDriverFlowLocked = true` → se muestra el banner *"Registro como conductor"* ([líneas 460-464](lib/presentation/screens/auth/register_profile_screen.dart#L460-L464)) y **no** se piden campos manuales adicionales — solo se confirma/edita el nombre completo (precargado) y se pulsa "Comenzar".
   - `_submit()` toma **directamente los valores `prefilled*`** (no hay reingreso de datos) y dispara `RegisterUser(role: 'driver', ...todas las rutas locales...)`.

### 7.2 Subida de documentos: cuántos, en qué orden, cómo se maneja el progreso

`AuthBloc._onRegisterUser`, bloque exclusivo de conductor con rutas locales ([auth_bloc.dart:400-497](lib/presentation/bloc/auth/auth_bloc.dart#L400-L497)):

- **6 documentos**, en este orden fijo (índice → campo destino):
  1. `dni_front` → `dniFrontUrl`
  2. `dni_back` → `dniBackUrl`
  3. `license` → `licenseUrl`
  4. `soat` → `soatUrl`
  5. `property_card` → `propertyCardUrl`
  6. `profile_pic` → `profilePicUrl`
- Para cada uno, **antes** de subir: `emit(AuthUploadingDriverDocs(completed: i, total: 6))` ([línea 435-438](lib/presentation/bloc/auth/auth_bloc.dart#L435-L438)) — la UI (barra de progreso en `RegisterProfileScreen`, [líneas 981-1018](lib/presentation/screens/auth/register_profile_screen.dart#L981-L1018)) muestra "Subiendo documentos i/6…".
- La subida real: `_storageService.uploadImage(file, spec.fileBase)` → `StorageService.uploadImage` ([storage_service.dart:102-180](lib/core/services/storage_service.dart#L102-L180)) sube a Supabase Storage, bucket `driver-documents`, ruta `profiles/{authUid}/{fileBase}.{ext}`.
- Si un archivo no existe en disco o falla la subida (p. ej. RLS), se emite `AuthError` con mensaje específico y **se aborta el registro completo** — no se sube el resto ni se crea el perfil.
- Tras subir las 6, `emit(AuthUploadingDriverDocs(completed: 6, total: 6))` y luego `emit(AuthLoading)` antes de construir el `UserModel` final ([línea 493-499](lib/presentation/bloc/auth/auth_bloc.dart#L493-L499)).
- El nuevo perfil se crea con `isApproved: false` y **los 5 campos de estado de documento en `PENDING`** (`dniFrontStatus`, `dniBackStatus`, `licenseStatus`, `soatStatus`, `propertyCardStatus` — [líneas 538-542](lib/presentation/bloc/auth/auth_bloc.dart#L538-L542)).
- Si la creación tiene éxito: `PendingDriverDocuments.clear()` (limpia `SharedPreferences`) y `emit(AuthAuthenticated(created))`.

### 7.3 Qué pasa según el estado de aprobación

Tras `AuthAuthenticated`, `RegisterProfileScreen` navega a `context.go('/dashboard')` ([listener, rol == 'driver'](lib/presentation/screens/auth/register_profile_screen.dart#L852-L854)), pero el **redirect** (`_authRedirect`, rama conductor) intercepta antes de que se vea el dashboard:

| Condición del perfil | Redirección | Pantalla resultante |
|---|---|---|
| `is_banned = true` | → `/driver_approval?banned=1` | `DriverApprovalScreen(isBanned: true)` — título *"Cuenta suspendida"* ([driver_approval_screen.dart:21-26](lib/presentation/screens/auth/driver_approval_screen.dart#L21-L26)), único botón "Cerrar sesión" (`LogoutRequested` + `go('/login')`). |
| `is_banned = false`, `is_approved = false` (caso normal justo tras registrarse) | → `/driver_approval` | `DriverApprovalScreen(isBanned: false)` — título *"Estamos verificando tus documentos"*, mismo botón de cerrar sesión. Es una pantalla **bloqueante** (`PopScope(canPop: false)`, [línea 28](lib/presentation/screens/auth/driver_approval_screen.dart#L28)) — no se puede retroceder con el botón físico/gesto. |
| `is_approved = true`, sin documentos rechazados | *(ninguna, `return null`)* | `DriverDashboardScreen` normal (sección 4). |
| `is_approved = true` **pero** algún `*_status == 'REJECTED'` | *(el router no lo bloquea; solo `/become-driver` lo chequea explícitamente)* | El conductor **sí llega** a `DriverDashboardScreen`, donde se muestra un banner rojo *"Tienes documentos rechazados. Corrígelos para conectarte."* solo si está `DriverOffline` ([driver_dashboard_screen.dart:566-572](lib/presentation/screens/driver_dashboard/driver_dashboard_screen.dart#L566-L572)), con botón "Revisar" → `context.push('/driver_rejected_documents')`. Además, si intenta pasar a "Disponible" con documentos rechazados, el toggle lo bloquea con un `SnackBar` y lo redirige a esa misma pantalla en vez de despachar `ToggleStatus` ([líneas 1368-1387](lib/presentation/screens/driver_dashboard/driver_dashboard_screen.dart#L1368-L1387)). |

`DriverRejectedDocumentsScreen` permite reemplazar cada documento rechazado individualmente: sube el nuevo archivo, y llama `AuthBloc.add(SubmitDriverApplicationEvent(updated))` con el estado del documento forzado de vuelta a `PENDING` — vuelve a quedar a la espera de revisión, sin afectar los demás documentos ya aprobados.

Cuando el ERP externo (fuera de este repositorio) marca `is_approved = true` en Supabase, el próximo `RefreshProfileEvent` (al reabrir la app, o el disparado automáticamente por `_AuthLifecycleRefresh` al volver a primer plano) actualiza `AuthAuthenticated` con el nuevo valor, y el redirect —al reevaluarse por el cambio de estado— envía al conductor de `/driver_approval` a `/dashboard` automáticamente, sin necesidad de cerrar y volver a abrir sesión.

---

## 8. Diagramas de flujo en texto

### 8.1 Arranque

```
main() [main.dart:19]
  ├→ WidgetsFlutterBinding.ensureInitialized()          [L20]
  ├→ validar SUPABASE_URL / SUPABASE_ANON_KEY            [L26-31]  (StateError si faltan)
  ├→ Android: useAndroidViewSurface = false              [L36-41]
  ├→ Supabase.initialize(url, anonKey)                   [L44-47]
  ├→ await di.initDI()                                   [L49]  → injection_container.dart:23-69
  │     ├ lazy singletons: SupabaseClient, PlacesService, StorageService,
  │     │                  UserRepository, RideRepository, DriverRepository,
  │     │                  PassengerDriverModeCubit
  │     └ factories: AuthBloc, DriverStatusBloc, DriverStatsCubit,
  │                  DriverWalletCubit, ClientRideBloc, RideHistoryCubit
  ├→ SystemChrome.setSystemUIOverlayStyle(dark)           [L52-59]
  └→ runApp(LlevaApp())                                  [L61]
        └→ MultiBlocProvider(AuthBloc, PassengerDriverModeCubit)   [L76-80]
              └→ _AuthLifecycleRefresh (resumed → RefreshProfileEvent)  [L103-135]
                    └→ GoRouter (initialLocation: '/splash')       [L84-87, 165]
```

### 8.2 Primera vez (sin sesión)

```
/splash → SplashScreen.build()                          [splash_screen.dart:21-25]
  └→ AuthBloc.add(CheckAuthStatus)   (NO existe AppStarted; lo dispara la propia pantalla)
        └→ AuthBloc._onCheckAuthStatus                   [auth_bloc.dart:173-202]
              ├→ emit(AuthLoading)
              ├→ currentSession?.user.id == null
              └→ emit(AuthInitial)
                    └→ SplashScreen.BlocListener: context.go('/login')   [L36-37]
                          └→ _authRedirect: '/login' ∈ _isPublicPath → null
                                └→ LoginScreen  ← primera pantalla
```

### 8.3 Sesión existente — cliente

```
/splash → CheckAuthStatus → getUserById(authUid) → user.role == 'client'
  └→ emit(AuthAuthenticated(user))
        └→ shouldUseDriverHome(user, mode) == false
              └→ context.go('/client-dashboard')
                    └→ _authRedirect: sin coincidencias → null (se queda)
                          └→ ClientDashboardScreen.build()             [L78-172]
                                └→ BlocProvider<ClientRideBloc>(
                                     ..add(InitializePickupFromCurrentLocation)
                                     ..add(CheckActiveRide(clientId)))  [L83-86]
                                     ├→ sin viaje activo → ClientRideStatus.initial
                                     └→ viaje activo (<15 min) → estado según status BD
                                          (searching/negotiating → searchingDriver,
                                           accepted → driverAssigned,
                                           arrived → driverArrived,
                                           ongoing → tripOngoing)
```

### 8.4 Sesión existente — conductor

```
/splash → CheckAuthStatus → getUserById(authUid) → user.role == 'driver'
  └→ emit(AuthAuthenticated(user))
        └→ shouldUseDriverHome(user, mode) == true (default para role=driver)
              └→ context.go('/dashboard')
                    └→ _authRedirect (rama conductor)                  [L122-150]
                          ├→ isBanned            → /driver_approval?banned=1
                          ├→ !isApproved         → /driver_approval
                          └→ aprobado & no baneado → null (se queda)
                                └→ GoRoute('/dashboard') MultiBlocProvider   [L276-293]
                                     (DriverStatsCubit, DriverStatusBloc, DriverWalletCubit)
                                     └→ DriverDashboardScreen.initState()   [L66-84]
                                           ├→ RefreshProfileEvent
                                           ├→ DriverStatsCubit.loadTodayStats(uid)
                                           ├→ DriverWalletCubit.loadWallet(uid)
                                           └→ DriverStatusBloc.add(RecoverDriverActiveRide(uid))
                                                 [driver_status_bloc.dart:338-395]
                                                 ├→ oferta pendiente propia → DriverWaitingForPassengerDecision
                                                 ├→ viaje asignado (accepted/arrived/ongoing)
                                                 │     → DriverOnTrip / DriverArrivedAtPickup / DriverTripInProgress
                                                 │       + _startLocationTracking()
                                                 └→ nada → se queda en DriverOffline (estado inicial)
```

### 8.5 Conductor en modo pasajero

```
DriverDashboardScreen → DriverDrawer → "Pedir taxi"          [driver_drawer.dart:245-253]
  └→ PassengerDriverModeCubit.setPassengerMode()
        ├→ SharedPreferences['passenger_driver_ui_mode'] = 'driver'... → 'passenger'
        └→ GoRouterRefreshCombined escucha modeCubit.stream → reevalúa _authRedirect
              └→ shouldUseDriverHome(user, mode) == false ahora
                    └→ '/dashboard' ∈ _isDriverExclusivePath → redirige a '/client-dashboard'
                          └→ ClientDashboardScreen + ClientRideBloc  (mismo flujo que 8.3)

(regreso) ClientDrawer → "Gana dinero conduciendo" → ClientMenuActions.onEarnMoneyDriving
  └→ si userCanTogglePassengerDriver(u): PassengerDriverModeCubit.setDriverMode()
        └→ redirige de vuelta a '/dashboard' + nuevas instancias de
           DriverStatsCubit / DriverStatusBloc / DriverWalletCubit
           (RecoverDriverActiveRide reconstruye lo que pueda desde Supabase)
```

### 8.6 Registro nuevo cliente

```
LoginScreen → _handleContinue()                    [login_screen.dart:35-51]
  └→ push('/sms-verification?phone=X&role=')
        └→ SmsVerificationScreen.initState → AuthBloc.add(SendOtpRequested(phone))
              └→ signInWithOtp → emit(AuthOtpSent)
                    └→ (código 6 dígitos) → AuthBloc.add(OtpVerified(phone, code))
                          └→ verifyOTP → sin perfil por id ni por phone
                                └→ emit(AuthNeedsRegistration(phone))
                                      └→ role vacío → push('/register', extra: phone [String])
                                            └→ RegisterProfileScreen(prefilledRole: null)
                                                  ├→ _selectedRole = 'client'  (sin selector de rol)
                                                  ├→ formulario manual: email, DNI, fecha nacimiento
                                                  └→ _submit() → AuthBloc.add(RegisterUser(role:'client', ...))
                                                        └→ _onRegisterUser: sin subida de docs
                                                              ├→ createUserProfile() (isApproved:true)
                                                              └→ emit(AuthAuthenticated(created))
                                                                    └→ go('/client-dashboard')
                                                                          → ClientDashboardScreen (8.3)
```

### 8.7 Registro nuevo conductor

```
[sin enlace de UI verificado] → /driver-register
  └→ DriverRegisterScreen  (3 pasos: personales → vehículo+SOAT/tarjeta → licencia+DNI+foto+fechas)
        └→ _onComenzar()                              [L323-431]
              ├→ PendingDriverDocuments.save({6 rutas locales})   [L379-386]
              └→ push('/sms-verification?role=driver&...datos...')
                    └→ SmsVerificationScreen
                          ├→ PendingDriverDocuments.load() → _pendingDocPaths
                          ├→ SendOtpRequested → AuthOtpSent → OtpVerified
                          └→ AuthNeedsRegistration
                                └→ _isDriverFullPackage() == true
                                      └→ push('/register', extra: {Map completo + rutas locales})
                                            └→ RegisterProfileScreen(prefilledRole:'driver', ...)
                                                  ├→ _hasCompleteDriverLegalPackage == true
                                                  ├→ banner "Registro como conductor" (solo confirma nombre)
                                                  └→ _submit() → AuthBloc.add(RegisterUser(role:'driver', ...localPaths))
                                                        └→ _onRegisterUser                    [L288-565]
                                                              ├→ sube 6 docs en orden fijo,
                                                              │   emit(AuthUploadingDriverDocs(i,6)) por cada uno
                                                              ├→ createUserProfile()
                                                              │   (isApproved:false, docs=PENDING)
                                                              ├→ PendingDriverDocuments.clear()
                                                              └→ emit(AuthAuthenticated(created))
                                                                    └→ go('/dashboard')
                                                                          └→ _authRedirect: !isApproved
                                                                                └→ DriverApprovalScreen
                                                                                     "Estamos verificando tus documentos"
                                                                                     (PopScope canPop:false)

  [más tarde, ERP aprueba is_approved=true fuera de este repo]
  └→ RefreshProfileEvent (resume o manual) → AuthAuthenticated(isApproved:true)
        └→ _authRedirect reevalúa: '/driver_approval' + aprobado → '/dashboard'
              └→ DriverDashboardScreen (8.4)

  [caso alterno: algún documento REJECTED, is_approved sigue true]
  └→ DriverDashboardScreen se muestra igual, con banner rojo si DriverOffline
        └→ "Revisar" → push('/driver_rejected_documents')
              └→ DriverRejectedDocumentsScreen: reemplaza foto → status vuelve a PENDING
```
