# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Lleva** is a Flutter taxi app for Trujillo, Peru. It targets Android (primary) with a dark-only UI. Two roles exist: `client` (passenger) and `driver`. A driver can switch to passenger mode via a toggle cubit.

## Environment setup

Copy .env.example to .env and fill in the real Supabase credentials before running.
The app will freeze on the Flutter logo if .env is missing or if flutter run is called without --dart-define-from-file=.env.

## Common Commands

```bash
# Install dependencies
flutter pub get

# Run (Android device/emulator)
flutter run --dart-define-from-file=.env

# Run with ERP backend configured
flutter run --dart-define=ERP_API_BASE_URL=https://your-erp-host.com

# Analyze
flutter analyze

# Clean build
flutter clean && flutter pub get && flutter run
```

There is no test suite. `flutter analyze` is the primary lint check (config in `analysis_options.yaml`).

## Architecture

Clean Architecture with BLoC state management, divided into four layers:

```
lib/
├── core/          # DI, routing, theme, constants, enums, services, utils
├── data/          # Models (JSON ↔ entities), repository implementations
├── domain/        # Pure Dart entities, repository interfaces
└── presentation/  # BLoCs/Cubits, screens, widgets
```

**Dependency injection** (`lib/core/di/injection_container.dart`): Uses `get_it`. All BLoCs/Cubits registered as factory (new instance per route), core services as lazy singletons. Always register new services here before injecting them.

**Navigation** (`lib/core/routes/app_router.dart`): GoRouter with a redirect function that enforces role-based access. Key rule: `shouldUseDriverHome()` determines if a logged-in user sees `/dashboard` (driver UI) or `/client-dashboard` (passenger UI). Add all new routes to `AppRouter.createRouter`.

**Supabase backend**: The only database tables are `profiles` (users) and `rides`. Driver documents are stored in Supabase Storage via `StorageService`. See `ERP_DB_SPEC.md` for full schema.

**ERP backend**: A separate Java/Spring server handles ride acceptance at `POST {ERP_API_BASE_URL}/api/rides/{rideId}/accept`. Configured via `--dart-define=ERP_API_BASE_URL=...`; empty string in `AppConstants.erpApiBaseUrl` means no ERP is configured.

## Key BLoCs and Their Responsibilities

| BLoC / Cubit | Purpose |
|---|---|
| `AuthBloc` | Phone login, registration (client & driver), document uploads to Supabase Storage, session persistence, driver application |
| `ClientRideBloc` | Full passenger ride lifecycle: location search → route calculation → price negotiation → active trip tracking |
| `DriverStatusBloc` | Driver online/offline toggle, nearby ride stream (5 km radius), negotiation offer submission/expiry (10s timer), GPS location tracking during trip |
| `PassengerDriverModeCubit` | Singleton — tracks whether a driver is currently using the app as a passenger |
| `DriverStatsCubit` | Today's earnings and trip count |
| `DriverWalletCubit` | Cumulative balance (earnings minus 10% commission) |
| `RideHistoryCubit` | Ride history list for both roles |

## Ride Lifecycle

**Database statuses** (stored in `rides.status`):
`searching` → `accepted` → `arrived` → `ongoing` → `finished`

The `negotiating` status exists for legacy data; current flow keeps rides in `searching` while driver counter-offers are stored in the `ride_offers` table.

**Client UI states** (`ClientRideStatus` enum):
`initial` → `readyToRequest` → `requesting` → `searchingDriver` → `driverAssigned` → `driverArrived` → `tripOngoing` → `tripFinished`

**Negotiation flow**: Driver submits an offer to `ride_offers` table. `ClientRideBloc` polls this table every 2 seconds (plus a Supabase Realtime stream). Client accepts via `accept_ride_offer` Supabase RPC (falls back to sequential updates if RPC fails).

## Google Maps Configuration

The Maps API key is stored in two places and must match:
- `lib/core/constants/app_constants.dart` → `AppConstants.googleMapsApiKey` (used by `PlacesService` for Directions/Places REST API calls)
- `android/app/src/main/AndroidManifest.xml` → `com.google.android.geo.API_KEY` metadata (used by the Maps SDK)

The custom dark map style is in `assets/map_style.json`.

**Android rendering note**: `main.dart` sets `useAndroidViewSurface = false` for Android. If panels appear behind the map, try `true`; if the map turns black, revert to `false`.

## Pricing Logic

`lib/core/utils/client_ride_pricing.dart`:
- Base fare: **S/ 3.00 + S/ 1.80/km**
- Vehicle category extras: Comfort +10% of base, XL +22% of base
- Options extras: >4 passengers +S/2, baby seat +S/1.50, pet +S/1.50
- Maximum discount below suggested: S/ 2.00
- Driver commission: 10% (calculated client-side in `DriverRepositoryImpl`, not a DB column)

## Auth & Session

Authentication is phone-number based (no Supabase Auth — only Supabase database). Sessions are stored via `SharedPreferences` as the phone number. On app resume, `AuthBloc` refreshes the profile from Supabase to pick up ERP-driven approval changes.

Driver registration uploads 6 documents (DNI front/back, license, SOAT, property card, profile photo) to Supabase Storage sequentially, emitting `AuthUploadingDriverDocs` with progress. GoRouter explicitly ignores redirects while this state is active.

## Adding New Features

1. **New screen**: Add entity/model/repository if needed → register in DI → add GoRoute in `AppRouter.createRouter`.
2. **New BLoC**: Define events, states, and bloc files → register as factory in `injection_container.dart` → provide via `BlocProvider` in the relevant route builder.
3. **New Supabase table**: Document columns following the pattern in `ERP_DB_SPEC.md` → add a model with `fromJson`/`toJson` → add a repository interface in `domain/repositories/` and implementation in `data/repositories/`.
