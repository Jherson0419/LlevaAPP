# Informe Técnico del Proyecto Lleva

*Generado a partir de la lectura completa de los 104 archivos `.dart` en `lib/` (≈26 000 líneas), `pubspec.yaml`, `ERP_DB_SPEC.md`, `README.md`, `docs/`, las migraciones SQL de `supabase/`, y la salida de `flutter analyze`.*

---

## 1. Resumen ejecutivo

**Lleva** es una aplicación móvil de taxi para Trujillo, Perú, construida en Flutter con arquitectura limpia (Clean Architecture) y gestión de estado con BLoC. Soporta dos roles — **pasajero** (`client`) y **conductor** (`driver`) — con la particularidad de que un conductor aprobado puede alternar a modo pasajero mediante `PassengerDriverModeCubit` ([lib/presentation/cubit/passenger_driver_mode_cubit.dart](lib/presentation/cubit/passenger_driver_mode_cubit.dart)).

**Plataforma objetivo:** Android (principal); no hay evidencia de configuración iOS activa en el código revisado. UI en modo oscuro forzado ([lib/main.dart:51-59](lib/main.dart#L51-L59)).

**Stack tecnológico** (`pubspec.yaml`):
- Flutter/Dart SDK `>=3.0.0 <4.0.0`
- Estado: `flutter_bloc ^8.1.3` + `equatable ^2.0.5`
- Navegación: `go_router ^13.0.0`
- Mapas/geolocalización: `google_maps_flutter ^2.5.0`, `google_maps_flutter_android ^2.14.0`, `geolocator ^10.1.0`, `flutter_polyline_points ^3.1.0`
- DI: `get_it ^8.0.3`
- Backend: `supabase_flutter ^2.5.0` (Postgres + Storage + Auth por OTP)
- Otros: `http`, `shared_preferences`, `image_picker`, `rxdart`, `intl`

**Backend dual:**
1. **Supabase** — única base de datos de la app (tablas `profiles`, `rides`, `ride_offers`), Storage privado para documentos de conductor, y Auth por teléfono (OTP real vía `signInWithOtp`/`verifyOTP`).
2. **ERP externo** (Java/Spring, fuera de este repo) — solo interviene en la aceptación de un viaje: `POST {ERP_API_BASE_URL}/api/rides/{rideId}/accept` ([lib/data/repositories/ride_repository_impl.dart:326-375](lib/data/repositories/ride_repository_impl.dart#L326-L375)). Si `ERP_API_BASE_URL` está vacío, `acceptRide` lanza una excepción controlada.

No existe suite de pruebas (confirmado en `CLAUDE.md` y en la ausencia de carpeta `test/` con contenido relevante).

---

## 2. Arquitectura actual

### 2.1 Estructura de capas

```
lib/
├── core/          # DI, rutas, tema, constantes, enums, servicios, utilidades
├── data/          # Modelos (JSON↔entidad), implementaciones de repositorio
├── domain/        # Entidades puras, contratos de repositorio
└── presentation/  # BLoCs/Cubits, screens, widgets
```

La separación se respeta de forma consistente: los `data/models/*` extienden las entidades de `domain/entities/*` y añaden `fromJson`/`toJson`; los repositorios en `data/repositories/*` implementan interfaces abstractas de `domain/repositories/*`.

### 2.2 Patrón BLoC — inventario completo

| BLoC / Cubit | Archivo | Responsabilidad |
|---|---|---|
| `AuthBloc` | [auth_bloc.dart](lib/presentation/bloc/auth/auth_bloc.dart) | Login por OTP real (Supabase Auth), registro cliente/conductor, subida secuencial de 6 documentos con progreso (`AuthUploadingDriverDocs`), migración de perfiles legacy (`migrateProfileId`), refresco de perfil, logout, envío de solicitud de conductor. |
| `ClientRideBloc` | [client_ride_bloc.dart](lib/presentation/bloc/client_ride/client_ride_bloc.dart) (1061 líneas, el BLoC más grande del proyecto) | Ciclo de vida completo del pasajero: autocompletado de direcciones (debounce 500 ms), cálculo de ruta y tarifa, preferencias de viaje, envío de solicitud, suscripción en tiempo real al viaje, escucha + *polling* de ofertas de conductores, aceptar/rechazar oferta, recuperar viaje activo al reabrir la app. |
| `DriverStatusBloc` | [driver_status_bloc.dart](lib/presentation/bloc/driver_status/driver_status_bloc.dart) | Máquina de estados del conductor: online/offline, negociación, envío de contraoferta con temporizador de 10 s, seguimiento GPS durante el viaje (`Geolocator.getPositionStream`, filtro de 8 m), transición arribo→en curso→finalizado, recuperación de sesión (`RecoverDriverActiveRide`). |
| `DriverStatsCubit` | [driver_stats_cubit.dart](lib/presentation/bloc/driver_stats/driver_stats_cubit.dart) | Ganancias y viajes de hoy + rating (`getTodayDriverStats` + `getDriverRating`). |
| `DriverWalletCubit` | [driver_wallet_cubit.dart](lib/presentation/bloc/driver_wallet/driver_wallet_cubit.dart) | Saldo adeudado = 10 % de la suma de `final_price` de viajes `finished`. |
| `RideHistoryCubit` | [ride_history_cubit.dart](lib/presentation/bloc/ride_history/ride_history_cubit.dart) | Historial de viajes por `userId`/`role`. |
| `PassengerDriverModeCubit` | [passenger_driver_mode_cubit.dart](lib/presentation/cubit/passenger_driver_mode_cubit.dart) | Singleton que persiste (SharedPreferences) si un conductor está usando la interfaz de pasajero; expone `shouldUseDriverHome()` y `userCanTogglePassengerDriver()`, usadas también por `AppRouter` y `SplashScreen`. |

### 2.3 Navegación (`lib/core/routes/app_router.dart`)

`AppRouter.createRouter` construye un `GoRouter` con `initialLocation: '/splash'` y un único `redirect` centralizado (`_authRedirect`, [líneas 86-157](lib/core/routes/app_router.dart#L86-L157)) que implementa el *guard* por rol:

- Estados `AuthLoading`, `AuthUploadingDriverDocs` y `AuthError` no fuerzan redirección (evita que la UI "reinicie" a mitad de un flujo).
- Rutas públicas: `/splash`, `/login`, `/driver-register`, `/client-register`, `/register`, `/sms-verification*`.
- Si `shouldUseDriverHome(user, mode)` es verdadero: banear → `/driver_approval?banned=1`; no aprobado → `/driver_approval`; si intenta entrar a rutas `/client*` se le regresa a `/dashboard`.
- Si es interfaz pasajero: cualquier ruta exclusiva de conductor (`_isDriverExclusivePath`) o `/driver_approval` redirige a `/client-dashboard`.

`GoRouterRefreshCombined` ([go_router_refresh.dart](lib/core/routes/go_router_refresh.dart)) combina `AuthBloc.stream` + `PassengerDriverModeCubit.stream` como `Listenable` para que el router reaccione a ambos cambios.

**Rutas registradas** (25): `/splash`, `/login`, `/driver-register`, `/client-register`, `/sms-verification`, `/register`, `/driver_approval`, `/dashboard`, `/driver_profile`, `/client-dashboard`, `/become-driver`, `/driver_rejected_documents`, `/client-profile`, `/client-wallet`, `/client-trips`, `/client-favorites`, `/client-settings`, `/client-help`, `/client-support`, `/history`, `/city_requests`, `/driver_wallet`, `/driver_support`, `/driver_help`, `/driver_settings`.

### 2.4 Inyección de dependencias (`lib/core/di/injection_container.dart`)

**Singletons perezosos:** `SupabaseClient` (instancia global de Supabase), `PlacesService`, `StorageService(SupabaseClient)`, `UserRepository`→`UserRepositoryImpl`, `RideRepository`→`RideRepositoryImpl`, `DriverRepository`→`DriverRepositoryImpl`, `PassengerDriverModeCubit`.

**Factories** (nueva instancia por ruta): `AuthBloc`, `DriverStatusBloc`, `DriverStatsCubit`, `DriverWalletCubit`, `ClientRideBloc`, `RideHistoryCubit`.

⚠️ Inconsistencia menor: `DriverRepositoryImpl` recibe `SupabaseClient` opcional por constructor, pero `RideRepositoryImpl` y `UserRepositoryImpl` obtienen `Supabase.instance.client` directamente dentro de la clase, sin pasar por DI — ver sección 6.

---

## 3. Base de datos (Supabase)

### 3.1 Tablas confirmadas

**`rides`** (columnas escritas/leídas por el código, ver [ride_model.dart](lib/data/models/ride_model.dart)):
`id`, `client_id`, `driver_id`, `origin_lat`, `origin_lng`, `dest_lat`, `dest_lng`, `origin_name`, `dest_name`, `status`, `offered_price`, `final_price`, `created_at`, `payment_method`, `driver_lat`, `driver_lng`.

Los campos `client_first_name`, `client_completed_trips`, `passenger_rating`, `client_profile_pic_url`, `driver_full_name`, `driver_profile_pic_url`, `driver_rating`, `driver_completed_trips`, `driver_car_model/brand/plate` **no son columnas propias de `rides`**: se calculan del lado del cliente Flutter con consultas adicionales a `profiles` y a `rides` (conteo de viajes finalizados) dentro de `_enrichRideWithDriverProfile`/`_enrichRideWithClientProfile`/`_enrichNearbyRidesForDriver` ([ride_repository_impl.dart:100-278](lib/data/repositories/ride_repository_impl.dart#L100-L278)).

**`profiles`** (ver [user_model.dart](lib/data/models/user_model.dart)):
`id`, `phone`, `role`, `is_driver_applicant`, `full_name`, `email`, `dni`, `car_plate`, `car_brand`, `car_model`, `is_approved`, `is_banned`, `car_year`, `car_color`, `soat_expiration`, `property_card_expiration`, `technical_review_expiration`, `license_category`, `license_number`, `birth_date`, `dni_front_url`, `dni_back_url`, `license_url`, `soat_url`, `property_card_url`, `profile_pic_url`, `dni_front_status`, `dni_back_status`, `license_status`, `soat_status`, `property_card_status`. Además, solo lectura: `driver_rating` ([driver_repository_impl.dart:41-59](lib/data/repositories/driver_repository_impl.dart#L41-L59)) y `passenger_rating` (opcional, con manejo de error si la columna no existe).

**`ride_offers`** (creada en [supabase/migrations/ride_offers.sql](supabase/migrations/ride_offers.sql)):
`id` (PK, `uuid`), `ride_id` (FK→`rides.id`, `on delete cascade`), `driver_id` (FK→`profiles.id`, `on delete cascade`), `offered_price` (`numeric`, `check >= 0`), `status` (`text`, `check in ('pending','accepted','rejected','withdrawn')`), `created_at`. Restricción `unique (ride_id, driver_id)` — un conductor solo puede tener una oferta activa por viaje (el código usa `upsert(... onConflict: 'ride_id,driver_id')`).

### 3.2 RPC / funciones

- **`accept_ride_offer(p_offer_id, p_ride_id, p_driver_id, p_final_price)`** — función `plpgsql security definer` en la misma migración: marca la oferta como `accepted`, rechaza el resto de ofertas `pending` del viaje, y actualiza `rides` (`driver_id`, `final_price`, `status='accepted'`) solo si el viaje seguía `searching`, todo en una transacción atómica. Se invoca desde `RideRepositoryImpl.acceptRideOffer` ([ride_repository_impl.dart:962-1001](lib/data/repositories/ride_repository_impl.dart#L962-L1001)) con **fallback secuencial** (`_acceptRideOfferSequential`) si el RPC falla — 3 `update` separados sin garantía transaccional real desde el cliente.

### 3.3 Políticas RLS mencionadas en el código

- `002_fix_profiles_rls.sql` — política `id = auth.uid()` en `profiles` (comentada extensamente en [user_repository_impl.dart:14-19](lib/data/repositories/user_repository_impl.dart#L14-L19) y en `AuthBloc`), lo que motiva el mecanismo de `migrateProfileId` para filas creadas antes del login OTP real.
- `003_fix_storage_policies.sql` — privatiza el bucket `driver-documents` (antes público), forzando el uso de `getSignedUrl` en vez de URLs públicas persistidas ([storage_service.dart:89-153](lib/core/services/storage_service.dart#L89-L153)).
- `supabase/storage_driver_documents_policies.sql` y `supabase/profiles_rls_update_driver_application.sql` — políticas adicionales referenciadas en mensajes de error (`StorageService.uploadImage`) cuando la subida falla por RLS.

### 3.4 Canales Realtime

| Canal | BLoC/Repositorio | Notas |
|---|---|---|
| `rides` (stream por `id`) | `RideRepositoryImpl.subscribeToRide` — usado por `ClientRideBloc` y `DriverStatusBloc` | Emite el registro base y luego una versión "enriquecida" con datos de `profiles`. |
| `rides` (stream filtrado `status='searching'`) | `RideRepositoryImpl.getNearbyRideRequests` — usado por `DriverStatusBloc` | Filtra por radio (Haversine) del lado del cliente tras recibir el stream completo. |
| `ride_offers` (stream por `ride_id`) | `RideRepositoryImpl.listenToRideOffers` — usado por `ClientRideBloc` y `DriverStatusBloc` | **Ver hallazgo en sección 6**: la migración deja comentada la línea `alter publication supabase_realtime add table public.ride_offers;`, por lo que el Realtime de esta tabla podría no estar habilitado en producción. El propio código lo compensa con *polling* cada 2 s (`_startListeningToRideOffers` en `client_ride_bloc.dart:382-429`). |

`ERP_DB_SPEC.md` está **desactualizado**: solo documenta `rides` y `profiles` con un subconjunto mínimo de columnas y no menciona `ride_offers` en absoluto — ver sección 6.

---

## 4. Flujos principales implementados

### 4.1 Autenticación

1. `LoginScreen` ([login_screen.dart](lib/presentation/screens/login/login_screen.dart)) — captura teléfono local de 9 dígitos, navega a `/sms-verification?phone=...&role=`.
2. `SmsVerificationScreen` — al montar, dispara `SendOtpRequested` (Supabase `signInWithOtp`, formateado a E.164 con `+51`). El usuario ingresa 6 dígitos → `OtpVerified` → `AuthBloc._onOtpVerified` busca el perfil por `auth.uid()`; si no existe, busca por teléfono (compatibilidad legacy) y migra el `id` con `migrateProfileId`; si sigue sin existir, emite `AuthNeedsRegistration`.
3. Según el rol y si viene de un flujo "completo" (p. ej. `DriverRegisterScreen` de 3 pasos), navega a `/register` (`RegisterProfileScreen`) con datos precargados, o pide datos manualmente.
4. **Registro conductor**: `DriverRegisterScreen` (3 pasos: personales → vehículo+SOAT/tarjeta → licencia+DNI+foto+fechas) guarda las rutas locales de imágenes con `PendingDriverDocuments` (SharedPreferences) para no pasarlas por la URL de navegación. Al confirmar (`RegisterUser`), `AuthBloc` sube secuencialmente 6 documentos a Supabase Storage (bucket `driver-documents`, ruta `profiles/{uid}/{archivo}`) emitiendo `AuthUploadingDriverDocs(completed, total)` para la barra de progreso.
5. `createUserProfile` inserta en `profiles` con `is_approved: false` para conductores, `dni_front_status`..`property_card_status` = `PENDING`.
6. Post-login: `AppRouter` redirige a `/driver_approval` mientras `is_approved=false`, o a `/driver_approval?banned=1` si `is_banned=true`.

### 4.2 Flujo de viaje del pasajero (estado → widget)

| `ClientRideStatus` | Widget/panel |
|---|---|
| `initial` | `SearchLocationPanel` — búsqueda de origen/destino con autocompletado |
| `readyToRequest` | `ReadyToRequestLayer` (`RidePriceSection` + `VehicleCategorySection` + `ReadyToRequestBottomBar`) — tarifa editable, categoría de vehículo, botón "Pedir Lleva" |
| `requesting` / `searchingDriver` (sin ofertas) | `SearchingDriverPanel` — precio actual, cronómetro de 15 min con auto-cancelación, botón "Aumentar oferta" |
| `searchingDriver` (con `pendingRideOffers`) | `NegotiatingPanel` — lista de ofertas de conductores con nombre, rating, vehículo, aceptar/descartar |
| `driverAssigned` | `DriverAssignedPanel` |
| `driverArrived` | `DriverArrivedPanel` |
| `tripOngoing` | `TripOngoingPanel` (mapa muestra ruta activa) |
| `tripFinished` | `TripFinishedPanel` |
| `error` | mensaje inline dentro del panel activo (`state.errorMessage`) |

El mapa (`ClientMapLayer`, 1800+ líneas) es el componente más complejo del proyecto: sincroniza cámara automática vs. manual, dibuja marcadores personalizados (círculo verde origen "A", cuadrado cian destino "B" con badges de distancia/tiempo generados con `Canvas`), anima el trazado de ruta, gestiona un "pulso" visual sobre el origen mientras se busca conductor, y permite reposicionar origen/destino arrastrando un pin central.

### 4.3 Flujo de viaje del conductor (estado → widget)

| `DriverStatusState` | Widget/panel |
|---|---|
| `DriverOffline` | Toggle "No Disponible" |
| `DriverOnline` | Lista de solicitudes cercanas (`_buildRequestsView`), radio 5 km |
| `DriverNegotiating` | `DriverNegotiatingCard(isWaitingOnPassenger: false)` — aceptar exacto, +S/1/+S/2/+S/3, oferta manual, ignorar |
| `DriverWaitingForPassengerDecision` | `DriverNegotiatingCard(isWaitingOnPassenger: true)` — barra de progreso regresiva de 10 s |
| `DriverOnTrip` | Panel "Camino al punto de recojo" → botón "¡Ya llegué!" (`NotifyArrival`) |
| `DriverArrivedAtPickup` | Panel "Pasajero en el punto de recojo" → botón "Iniciar Viaje" (`StartTrip`) |
| `DriverTripInProgress` | Panel "Viaje en curso" → botón "Finalizar Viaje" (`FinishTrip`) |

Durante `DriverOnTrip`/`DriverArrivedAtPickup`/`DriverTripInProgress`, `DriverStatusBloc._startLocationTracking` reporta la posición GPS cada 8 m a `rides.driver_lat/driver_lng` vía `Geolocator.getPositionStream`.

### 4.4 Flujo de negociación de tarifa

1. El pasajero crea el viaje con `offered_price` y `status='searching'`.
2. Cada conductor que abre la solicitud puede **aceptar el precio exacto** o **contraofertar**; ambas acciones llaman a `submitNegotiationOffer` (`upsert` en `ride_offers`, conflicto en `(ride_id, driver_id)`), y el viaje **permanece en `searching`** (el estado legado `negotiating` ya no se escribe activamente, solo se lee por compatibilidad con datos antiguos).
3. El conductor entra a `DriverWaitingForPassengerDecision` con un temporizador de 10 s; si nadie responde, se llama `withdrawRideOffer` (estado `withdrawn`) y vuelve a `DriverOnline`.
4. El pasajero ve todas las ofertas `pending` en `NegotiatingPanel` (vía Realtime + *polling* de 2 s) y puede `AcceptDriverOffer` (→ RPC `accept_ride_offer`) o `RejectRideOffer` (estado `rejected`).
5. El pasajero también puede subir su propia oferta sin esperar contraofertas (`BoostOfferedPrice` → `updateOfferedPrice` en `rides.offered_price`), visible en tiempo real para los conductores.

---

## 5. Estado actual por módulo

| Módulo | Estado | Notas |
|---|---|---|
| Autenticación y sesión | ✅ Completo | OTP real vía Supabase Auth, migración de perfiles legacy, subida de documentos con progreso, refresco automático al volver a foreground (`_AuthLifecycleRefresh` en `main.dart`). |
| Mapa y ubicación (pasajero) | ✅ Completo | `ClientMapLayer` es robusto: marcadores personalizados, animaciones, arrastre de pines, seguimiento de ubicación propia. |
| Solicitud de viaje | ✅ Completo | Cálculo de ruta real (Directions API con fallback a polyline recta), precio sugerido por categoría/extras, validaciones. |
| Negociación de tarifa | ✅ Completo | Ofertas concurrentes, contraofertas, temporizador de expiración, RPC atómico con fallback. |
| Tracking en tiempo real | ✅ Completo | Posición del conductor actualizada cada 8 m y reflejada en el mapa del pasajero. |
| Panel del conductor | ⚠️ Parcial | El flujo de viaje está completo, pero las pestañas **"Zonas Calientes"** y **"Desempeño"** son placeholders (ver sección 7). |
| Historial de viajes | ✅ Completo | `RideHistoryScreen`/`RideHistoryCubit` con datos reales de Supabase, accesible desde ambos drawers. |
| Wallet del conductor | ⚠️ Parcial | Saldo adeudado (10 % comisión) es real (`DriverWalletCubit`); "Movimientos recientes" en `DriverWalletScreen` está **hardcodeado** y el botón "Recargar saldo" solo muestra un `SnackBar`. |
| Perfil de usuario | ❌ Faltante | `ClientProfileScreen` y `DriverProfileScreen` muestran **datos totalmente falsos** ("Juan Pérez", teléfono ajeno, "Chevrolet Onix RS 2025") sin conexión a `AuthBloc` (salvo el nombre en el AppBar de `DriverProfileScreen`). Botón "Editar Perfil" solo muestra un `SnackBar`. |
| Configuración y preferencias | ⚠️ Parcial | `ClientSettingsScreen`/`DriverSettingsScreen` son UI estática; el switch de notificaciones del conductor está deshabilitado (`onChanged: null`); "Términos y Condiciones" solo abre un `SnackBar`. |
| Pantallas de ayuda y soporte | ❌ Placeholder | Las 4 pantallas (`client_help`, `client_support`, `driver_help`, `driver_support`) son listas de `ListTile` con `onTap: () {}` vacío; el botón de WhatsApp muestra "Enlace a WhatsApp próximamente". |
| ERP / panel administrativo | ⚠️ Parcial (fuera de este repo) | Este repositorio solo consume `POST /api/rides/{id}/accept` del ERP. No hay panel administrativo aquí; aprobación/rechazo de documentos y baneo se asumen gestionados por el ERP externo, aunque `DocumentReviewStatus`/`is_approved`/`is_banned` sí se leen y respetan en el router. |

---

## 6. Problemas y deuda técnica detectada

### 6.1 Código legacy o sin usar

Verificado por búsqueda de referencias cruzadas: los siguientes archivos **no son importados por ningún otro archivo** salvo por sí mismos (el dashboard actual usa `widgets/client/panels/*`, no estos):

- [lib/presentation/widgets/client/client_ride_active_view.dart](lib/presentation/widgets/client/client_ride_active_view.dart)
- [lib/presentation/widgets/client/client_ride_initial_view.dart](lib/presentation/widgets/client/client_ride_initial_view.dart)
- [lib/presentation/widgets/client/client_ride_requesting_view.dart](lib/presentation/widgets/client/client_ride_requesting_view.dart)
- [lib/presentation/widgets/client/client_ride_route_calculated_view.dart](lib/presentation/widgets/client/client_ride_route_calculated_view.dart)
- [lib/presentation/widgets/client/client_ride_searching_view.dart](lib/presentation/widgets/client/client_ride_searching_view.dart)
- [lib/presentation/widgets/driver/driver_menu_bottom_sheet.dart](lib/presentation/widgets/driver/driver_menu_bottom_sheet.dart) (el conductor usa `DriverDrawer`, no este *bottom sheet*)

Consecuentemente, los eventos `StartSearch`, `CalculateRoute` y `SubmitOffer` en [client_ride_event.dart](lib/presentation/bloc/client_ride/client_ride_event.dart#L157-L185) (marcados en el propio código como *"Eventos usados por widgets legacy"*) solo los disparan estos widgets muertos; su handler `_onCalculateRoute` en el BLoC es literalmente un no-op con comentario `// Flujo principal: usar el panel del dashboard con Places.`

### 6.2 TODOs en el código

7 TODOs, todos en pantallas/widgets ya señalados como placeholder o muertos:
- `driver_menu_bottom_sheet.dart:125,142` (archivo sin uso)
- `client_settings_screen.dart:66` (toggle notificaciones)
- `client_profile_screen.dart:119` (edición de perfil)
- `client_favorites_screen.dart:179` (navegar a detalle)
- `login_screen.dart:218,226` (login Google/Apple)

No hay FIXME ni XXX en el código.

### 6.3 Inconsistencias entre modelos/entidades y documentación

- `RideEntity.status` documenta en comentario los valores `'searching', 'negotiating', 'accepted', 'completed', 'cancelled'` ([ride_entity.dart:17-18](lib/domain/entities/ride_entity.dart#L17-L18)), pero el código real nunca escribe `'completed'` — usa `'finished'` (confirmado también por `ERP_DB_SPEC.md` sección 3.1, que señala esta discrepancia como legado).
- **`ERP_DB_SPEC.md` está desactualizado**: documenta solo `rides` (14 columnas, faltan `driver_lat`/`driver_lng` no, sí están, pero faltan los campos enriquecidos aclarados) y `profiles` con **solo 5 columnas** (`id`, `phone`, `role`, `full_name`, `driver_rating`), cuando el modelo real (`UserModel`) tiene **~30 columnas** (documentos, vehículo, fechas de vencimiento, estados de revisión, etc.). La tabla `ride_offers` **no aparece mencionada en absoluto**. Cualquier equipo ERP que use este documento como fuente de verdad tendría un esquema incompleto.
- **`README.md` describe una fase del proyecto muy anterior**: dice *"Fase Actual: Interfaz Visual (UI/UX)"* con backend "próxima fase" y Supabase como "próxima fase", cuando en realidad el proyecto ya tiene autenticación real, negociación de tarifas, tracking GPS y un ERP externo integrado. Es engañoso para onboarding.

### 6.4 Realtime posiblemente no habilitado en `ride_offers`

La migración [ride_offers.sql](supabase/migrations/ride_offers.sql#L62-L63) deja **comentada** la línea `alter publication supabase_realtime add table public.ride_offers;`. El código en `ClientRideBloc._startListeningToRideOffers` ([client_ride_bloc.dart:382-429](lib/presentation/bloc/client_ride/client_ride_bloc.dart#L382-L429)) se apoya en un stream de Supabase **y además** hace *polling* manual cada 2 segundos como red de seguridad — un indicio fuerte de que el Realtime de esta tabla podría no estar activo en el proyecto Supabase real, lo que añade latencia y carga innecesaria si nunca se habilitó.

### 6.5 Cálculo de distancia Haversine duplicado 4 veces

Implementaciones independientes y casi idénticas de la fórmula de Haversine en:
- [lib/core/utils/geo_distance.dart](lib/core/utils/geo_distance.dart) (`haversineKm`) — la única pensada como utilidad reusable
- [lib/core/services/places_service.dart:349-364](lib/core/services/places_service.dart#L349-L364) (`_distanceKm`)
- [lib/data/repositories/ride_repository_impl.dart:644-668](lib/data/repositories/ride_repository_impl.dart#L644-L668) (`_approxDistanceInKm`)
- [lib/presentation/bloc/client_ride/client_ride_bloc.dart:1030-1050](lib/presentation/bloc/client_ride/client_ride_bloc.dart#L1030-L1050) (`_approxDistanceInKm`)

Ninguna reutiliza `geo_distance.dart`.

### 6.6 Warnings de `flutter analyze`

129 issues totales (0 errores). Los de severidad `warning`:
- `unused_import` — `go_router` en `driver_rejected_documents_screen.dart:3`
- `unnecessary_cast` (×2) — `driver_dashboard_screen.dart:131,639`
- `unused_element` — `_goToCurrentLocation` en `client_map_layer.dart:540` (método muerto, probablemente reemplazado por otra función pero no eliminado)

El resto son `info` de estilo: `deprecated_member_use` (uso extendido de `withOpacity` en vez de `withValues`, y `setMapStyle`/`zIndex` deprecados de `google_maps_flutter`), `prefer_const_constructors`, `require_trailing_commas`. Corregibles en su mayoría con `dart fix --apply`.

### 6.7 Uso de `print()` en vez de logging estructurado

El proyecto usa consistentemente `developer.log(...)` con `name:` para depuración (patrón visible en casi todos los repositorios y BLoCs), excepto en dos puntos que usan `print()` directamente, señalados por el linter (`avoid_print`):
- [client_ride_bloc.dart:655,657](lib/presentation/bloc/client_ride/client_ride_bloc.dart#L655-L657)
- [driver_dashboard_screen.dart:377](lib/presentation/screens/driver_dashboard/driver_dashboard_screen.dart#L377)

### 6.8 Patrón de DI inconsistente para `SupabaseClient`

`DriverRepositoryImpl` acepta `SupabaseClient` opcional por constructor ([driver_repository_impl.dart:6-9](lib/data/repositories/driver_repository_impl.dart#L6-L9)), pero `RideRepositoryImpl` y `UserRepositoryImpl` acceden directamente a `Supabase.instance.client` como campo final sin inyección — dificulta *mockear* estos repositorios en pruebas unitarias.

### 6.9 Credenciales históricamente expuestas (ya mitigado, pendiente de verificación)

`docs/setup_env.md` documenta que la URL/anon key de Supabase y la API key de Google Maps estuvieron hardcodeadas en el código fuente desde el commit `45cae88`, y por tanto **siguen visibles en el historial de git** aunque ya no estén en el archivo actual. El documento pide explícitamente rotar ambas credenciales — vale la pena confirmar que esa rotación ya se ejecutó.

---

## 7. Lo que falta por implementar

- **Perfil de usuario real** (cliente y conductor): actualmente 100 % simulado con datos de otra persona.
- **Favoritos del pasajero**: UI presente (`ClientFavoritesScreen`) pero sin persistencia — el diálogo "Guardar" solo muestra un `SnackBar`.
- **Historial "Mis Viajes" del pasajero duplicado y contradictorio**: `ClientTripsScreen` (accesible desde "Entregas"/"Viajes" del drawer) usa una lista de 3 viajes hardcodeados, mientras que `RideHistoryScreen` (accesible desde "Historial de solicitudes") sí trae datos reales de Supabase. Son dos pantallas distintas para un concepto similar — una funcional, otra falsa.
- **Wallet real del pasajero**: `ClientWalletScreen` muestra saldo fijo `S/ 150.00` y métodos de pago "Conectado" sin ninguna integración real con Yape/Plin.
- **Recarga de saldo del conductor** (Yape/Plin) y **movimientos reales** en `DriverWalletScreen` — hoy son datos de ejemplo.
- **Notificaciones push**: no hay ninguna dependencia de mensajería (`firebase_messaging` o similar) en `pubspec.yaml`; el switch "Sonido de nueva solicitud" en configuración del conductor está deshabilitado (`onChanged: null`), sugiriendo que la funcionalidad no existe aún.
- **Login social** (Google/Apple): botones visibles en `LoginScreen`, `onTap` vacío.
- **"Zonas Calientes"** (mapa de calor de demanda) para el conductor: texto estático "Actualizando zonas de alta demanda...".
- **Pestaña "Desempeño"** del conductor: solo repite ganancias/viajes de hoy, sin analítica adicional.
- **Ruta `/city_requests`** ("Ciudad, solicitudes"): `DriverRoutePlaceholderScreen` muestra literalmente "Próximamente".
- **Flujo de calificación post-viaje**: el rating de conductor/pasajero se lee en varias pantallas, pero no existe ninguna pantalla en este repo donde un usuario pueda *enviar* una calificación tras finalizar un viaje.
- **Contenido legal real**: los diálogos de "Legal" y "Términos y condiciones" son texto de relleno explícito ("estarán disponibles aquí").
- **Soporte multi-ciudad**: `AppConstants.trujilloLatitude/Longitude` y el filtro `cityHint` en `ClientRideBloc._cityHintFromState` están hardcodeados a `'trujillo'`.
- **Panel administrativo / ERP**: no existe en este repositorio; se asume una aplicación Java/Spring separada.

---

## 8. Recomendaciones de mejora

### Prioridad Alta (bloquea producción)

1. **Reemplazar los perfiles falsos** (`ClientProfileScreen`, `DriverProfileScreen`) por datos reales de `AuthBloc` antes de cualquier lanzamiento — mostrar el teléfono/nombre de una persona distinta a la que inició sesión es un problema serio de confianza y posible filtración de datos de prueba.
2. **Confirmar si Realtime está habilitado en `ride_offers`** en el proyecto Supabase de producción (la migración lo deja comentado); si no lo está, decidir conscientemente si el *polling* de 2 s es el diseño definitivo y documentarlo, o habilitar Realtime y simplificar el código.
3. **Resolver la duplicidad `ClientTripsScreen` vs `RideHistoryScreen`**: son dos pantallas de "mis viajes", una con datos falsos y otra real, accesibles desde el mismo drawer — genera confusión y riesgo de que el usuario vea datos de ejemplo como reales.
4. **Cambiar el `applicationId` de Android** desde el placeholder (`com.example.lleva`, según `docs/setup_env.md`) y **verificar la rotación** de las credenciales de Supabase/Google Maps expuestas en el historial de git antes de publicar.
5. **Agregar una suite de pruebas mínima** (`bloc_test`) para los flujos críticos con dinero real involucrado: negociación de tarifa, aceptación de oferta (incluyendo el *fallback* no atómico de `acceptRideOffer`), y cancelación.

### Prioridad Media (afecta experiencia)

6. Implementar edición de perfil, favoritos persistentes y wallet de pasajero reales, o retirar temporalmente esas entradas del menú hasta que existan.
7. Definir e implementar notificaciones push — crítico para que un conductor reciba solicitudes con la app en segundo plano.
8. Unificar el cálculo de distancia Haversine en `geo_distance.dart` y eliminar las 3 reimplementaciones restantes.
9. Sustituir los 2 usos de `print()` por `developer.log(...)`, coherente con el resto del código.
10. Regenerar `ERP_DB_SPEC.md` incluyendo `ride_offers` y las columnas reales de `profiles`, para que el equipo ERP trabaje con el esquema correcto.

### Prioridad Baja (deuda técnica / calidad)

11. Eliminar los 6 archivos de widgets sin uso y los 3 eventos de `ClientRideBloc` que solo ellos disparan (`StartSearch`, `CalculateRoute`, `SubmitOffer`).
12. Ejecutar `dart fix --apply` y revisar manualmente los 129 hallazgos de `flutter analyze` (mayoritariamente `withOpacity`→`withValues`, `const` faltante, comas finales).
13. Actualizar `README.md`, que describe una fase del proyecto muy anterior a la actual (sin backend).
14. Unificar el patrón de inyección de `SupabaseClient` en todos los repositorios vía constructor, para facilitar pruebas.

---

## 9. Guía de onboarding para nuevo desarrollador

### Configurar el entorno

```bash
git clone <repo>
flutter pub get
cp .env.example .env   # completar SUPABASE_URL, SUPABASE_ANON_KEY, GOOGLE_MAPS_KEY, ERP_API_BASE_URL
flutter run --dart-define-from-file=.env
```

`.env` está en `.gitignore`. La API key de Google Maps para el **SDK nativo de Android** la resuelve `android/app/build.gradle.kts` leyendo la variable de entorno `GOOGLE_MAPS_KEY` o el mismo `.env` de la raíz — no requiere pasos adicionales si `.env` ya está completo (ver `docs/setup_env.md`).

### Variables de entorno / dart-defines necesarios

| Variable | Uso |
|---|---|
| `SUPABASE_URL` / `SUPABASE_ANON_KEY` | Inicialización de Supabase en `main.dart`; la app **falla explícitamente al arrancar** si faltan. |
| `GOOGLE_MAPS_KEY` | `PlacesService` (Directions/Places/Geocoding REST) y el SDK nativo de Maps vía Gradle. |
| `ERP_API_BASE_URL` | Opcional — si está vacío, `acceptRide` lanza `RideAcceptanceException` en vez de intentar la llamada HTTP. |

### Cómo agregar una nueva pantalla

1. Crear el archivo en `lib/presentation/screens/<área>/<nombre>_screen.dart`.
2. Si necesita datos de dominio, crear/reusar entidad en `domain/entities/`, repositorio en `domain/repositories/` + `data/repositories/`.
3. Registrar la ruta con `GoRoute` dentro de `AppRouter.createRouter` ([app_router.dart](lib/core/routes/app_router.dart)); si es exclusiva de un rol, añadirla a `_isDriverExclusivePath` o al chequeo equivalente en `_authRedirect`.

### Cómo agregar un nuevo BLoC

1. Crear `<nombre>_event.dart`, `<nombre>_state.dart` y `<nombre>_bloc.dart` (o usar `part of` como hace `ClientRideBloc` si el BLoC es grande y cohesivo).
2. Registrar como `factory` en `lib/core/di/injection_container.dart`.
3. Proveerlo con `BlocProvider` (o `MultiBlocProvider`) en el builder de la ruta correspondiente — ver el patrón en `AppRouter` para `/dashboard`.

### Convenciones de nombres usadas en el proyecto

- Archivos: `snake_case.dart`; clases: `PascalCase`.
- Pantallas: sufijo `_screen.dart`; BLoCs: `_bloc.dart` + `_event.dart` + `_state.dart`; Cubits: `_cubit.dart` + `_state.dart`.
- Widgets de dominio agrupados por carpeta: `widgets/client/`, `widgets/client/panels/` (hojas inferiores del flujo de pasajero), `widgets/client/map/`, `widgets/driver/`, `widgets/common/`.
- Comentarios `///` de documentación consistentes en clases y métodos públicos, en español, a menudo explicando el *porqué* de una decisión (patrón muy usado en este repo — revisar antes de "limpiar" comentarios que parezcan redundantes).

### Archivos críticos que leer primero

1. [CLAUDE.md](CLAUDE.md) — resumen de arquitectura y convenciones ya validado por el equipo.
2. [lib/core/di/injection_container.dart](lib/core/di/injection_container.dart) — mapa completo de dependencias.
3. [lib/core/routes/app_router.dart](lib/core/routes/app_router.dart) — reglas de acceso por rol, punto de entrada de casi toda la navegación.
4. [lib/presentation/bloc/client_ride/client_ride_bloc.dart](lib/presentation/bloc/client_ride/client_ride_bloc.dart) — el BLoC más grande y representativo del patrón del proyecto.
5. [lib/data/repositories/ride_repository_impl.dart](lib/data/repositories/ride_repository_impl.dart) — toda la interacción con Supabase para viajes y ofertas.
6. `docs/setup_env.md` y `docs/setup_phone_auth.md` — contexto de seguridad y decisiones sobre autenticación por teléfono.
7. `ERP_DB_SPEC.md` — útil como punto de partida para entender el esquema, **pero leer con la advertencia de la sección 6.3**: está incompleto respecto al código actual.
