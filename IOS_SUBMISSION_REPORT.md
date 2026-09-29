# Reporte de preparación para App Store — Lleva

> Generado a partir de una revisión completa de: `ios/Runner.xcodeproj/project.pbxproj`, `ios/Runner/Info.plist`, `ios/Runner/AppDelegate.swift`, `ios/Podfile` (inexistente), `pubspec.yaml`, `android/app/build.gradle.kts`, `lib/core/constants/app_constants.dart`, `lib/main.dart`, `.env` y la carpeta `assets/`.
>
> **Contexto importante:** este proyecto es un proyecto Flutter cuyo `CLAUDE.md` lo describe explícitamente como una app dirigida a **Android (principal)**. La carpeta `ios/` existe con el scaffolding estándar de `flutter create`, pero **nunca ha sido configurada para un build de producción real** — faltan piezas fundamentales (Podfile, equipo de firma, bundle ID final, inicialización nativa de Google Maps). Este reporte documenta el estado actual con precisión, sin asumir que algo funciona porque el archivo existe.

---

## 1. IDENTIDAD DE LA APP

| Campo | Valor encontrado | Coincide con objetivo (`pe.lleva.app` / `XSNN9R56MG`) |
|---|---|---|
| Bundle ID — Debug (`project.pbxproj`, target Runner) | `com.example.lleva` | ❌ |
| Bundle ID — Release (`project.pbxproj`, target Runner) | `com.example.lleva` | ❌ |
| Bundle ID — Profile (`project.pbxproj`, target Runner) | `com.example.lleva` | ❌ |
| Bundle ID — Info.plist (`CFBundleIdentifier`) | `$(PRODUCT_BUNDLE_IDENTIFIER)` → hereda `com.example.lleva` del pbxproj | ❌ |
| `DEVELOPMENT_TEAM` (project.pbxproj, las 6 configuraciones proyecto+target) | **Ausente** — no aparece la clave en ninguna de las 6 configuraciones (Debug/Release/Profile × proyecto/target Runner) | ❌ |
| `applicationId` (`android/app/build.gradle.kts`) | `com.example.lleva` (y también `namespace = "com.example.lleva"`) | ❌ |
| Versión (`CFBundleShortVersionString`) | `$(FLUTTER_BUILD_NAME)` → resuelve a **1.0.0** (de `version: 1.0.0+1` en pubspec.yaml) | — |
| Build (`CFBundleVersion`) | `$(FLUTTER_BUILD_NUMBER)` → resuelve a **1** | — |
| `CFBundleDisplayName` | `Lleva` | ✅ (nombre visible correcto) |
| `CFBundleName` | `lleva` (identificador interno, no visible al usuario) | — |

**⚠️ Nota crítica:** `com.example.*` es un prefijo reservado/genérico. App Store Connect no permite registrar una app nueva con ese Bundle ID — hay que cambiarlo antes de poder crear el App ID en el portal de desarrollador de Apple.

*(El target `RunnerTests` usa `com.example.lleva.RunnerTests` en sus 3 configuraciones — es solo el bundle de pruebas unitarias, no se sube a la tienda, no requiere corrección.)*

---

## 2. CONFIGURACIÓN iOS

| Ítem | Estado |
|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | `13.0` en las 6 configuraciones (proyecto y target Runner, Debug/Release/Profile) — ✅ cumple el mínimo recomendado de iOS 13.0 |
| Orientaciones iPhone (`UISupportedInterfaceOrientations`) | Portrait, LandscapeLeft, LandscapeRight (sin PortraitUpsideDown) |
| Orientaciones iPad (`UISupportedInterfaceOrientations~ipad`) | Portrait, PortraitUpsideDown, LandscapeLeft, LandscapeRight (las 4) |
| `NSCameraUsageDescription` | ✅ Presente: *"Necesitamos acceso a la cámara para fotografiar tus documentos de conductor."* |
| `NSPhotoLibraryUsageDescription` | ✅ Presente: *"Necesitamos acceso a tus fotos para adjuntar documentos de conductor."* |
| `NSLocationWhenInUseUsageDescription` | ❌ **Falta por completo** |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | ❌ Falta (ver análisis en sección 3) |
| `NSMicrophoneUsageDescription` | No se encontró uso de micrófono en `lib/` ni paquete de audio en `pubspec.yaml` — no aplica, no es necesario declararla |
| `CFBundleDisplayName` | ✅ Definido (`Lleva`) |
| `ITSAppUsesNonExemptEncryption` | ❌ **No declarado** |
| `UILaunchStoryboardName` | ✅ Existe: `LaunchScreen` → `ios/Runner/Base.lproj/LaunchScreen.storyboard` existe en disco |

---

## 3. PERMISOS REQUERIDOS POR LLEVA

| Permiso | Estado | Justificación de uso en Lleva |
|---|---|---|
| `NSLocationWhenInUseUsageDescription` | ❌ **Falta** | GPS para mostrar la ubicación del usuario en el mapa (pasajero y conductor) — es el permiso base de toda la app de mapas |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | ❌ Falta | Solo es estrictamente necesario si el tracking del conductor debe seguir en segundo plano. **Dato relevante:** `AndroidManifest.xml` solo declara `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION`, **no** `ACCESS_BACKGROUND_LOCATION` — indicio de que el tracking actual es solo "en uso" (foreground), no en segundo plano real. Confirmar con el equipo de producto antes de agregarla (agregar un permiso "Always" sin usarlo de verdad es motivo típico de rechazo por Apple) |
| `NSCameraUsageDescription` | ✅ Presente con mensaje en español | Fotografiar documentos de conductor (DNI, licencia, SOAT, tarjeta de propiedad, foto de perfil) |
| `NSPhotoLibraryUsageDescription` | ✅ Presente con mensaje en español | Elegir foto de documento desde la galería (vía `image_picker`) |
| `NSPhotoLibraryAddUsageDescription` | ❌ Falta | Solo necesario si la app **guarda** imágenes en la galería del usuario. No se encontró código que escriba en la galería (solo lectura vía `image_picker`) — probablemente no se necesita, pero confírmalo si se agrega una función de "guardar comprobante" a futuro |

---

## 4. ASSETS Y RECURSOS

- **`ios/Runner/Assets.xcassets/AppIcon.appiconset/`**: ✅ Existe. Tamaños presentes (todos con `Contents.json`):
  `20x20@1x`, `20x20@2x`, `20x20@3x`, `29x29@1x`, `29x29@2x`, `29x29@3x`, `40x40@1x`, `40x40@2x`, `40x40@3x`, `60x60@2x`, `60x60@3x`, `76x76@1x`, `76x76@2x`, `83.5x83.5@2x`, `1024x1024@1x` — set estándar completo generado por el template de Flutter.
- **LaunchScreen**: ✅ Existe `ios/Runner/Base.lproj/LaunchScreen.storyboard`, más `Assets.xcassets/LaunchImage.imageset/` con `LaunchImage.png`, `LaunchImage@2x.png`, `LaunchImage@3x.png` (y un `README.md` placeholder del template, sin editar).
- **`assets/map_style.json`**: ✅ Existe (2201 bytes).
- **`assets/sounds/`**: ❌ No existe. No hace falta — el feedback sonoro de la pantalla de onboarding usa `SystemSound.play()` nativo de Flutter, no un archivo de audio embebido.
- **Carpetas de assets declaradas en `pubspec.yaml`**:
  - `assets/images/` → la carpeta **existe pero está vacía** (0 archivos). No rompe el build (Flutter no exige contenido, solo que la carpeta exista), pero no aporta nada tampoco.
  - `assets/icons/` → ✅ existe con 6 archivos: `car.png`, `dest.png`, `origin.png`, `IconoYape.png`, `IconoPlin.png`, `IconoEfectivo.png`.
  - `assets/map_style.json` → ✅ existe (declarado como archivo individual, no carpeta).

---

## 5. DEPENDENCIAS iOS (Podfile)

**🔴 `ios/Podfile` NO EXISTE.** No hay ningún archivo `Podfile`/`Podfile.lock` en `ios/`. Esto es un bloqueante total: sin Podfile no hay `pod install`, y sin `pod install` no hay build de iOS posible (ni local, ni en Codemagic). En un proyecto Flutter estándar este archivo lo genera `flutter create` y normalmente se versiona — aquí falta por completo.

Como no existe, no puedo listar los pods que *ya* están instalados (no hay ninguno). Cuando se cree el Podfile (con `platform :ios, '13.0'` como mínimo, para igualar `IPHONEOS_DEPLOYMENT_TARGET`), CocoaPods instalará automáticamente los pods nativos correspondientes a los plugins Flutter con código iOS de este proyecto:

| Paquete Flutter | Compatible con iOS | Notas |
|---|---|---|
| `google_maps_flutter` ^2.5.0 | ✅ Sí | Instala el pod `GoogleMaps` — requiere además inicializar la API key nativamente en `AppDelegate.swift` (ver sección 8: **no está hecho**) |
| `geolocator` ^10.1.0 | ✅ Sí | Vía `geolocator_apple` — depende de que `NSLocationWhenInUseUsageDescription` exista (falta, ver sección 3); sin esa clave la app **crashea** al pedir permiso de ubicación en iOS |
| `google_sign_in` ^6.2.1 | ✅ Sí | Requiere `CFBundleURLTypes` con el `REVERSED_CLIENT_ID` en Info.plist (falta, ver sección 8) |
| `supabase_flutter` ^2.5.0 | ✅ Sí | Dart puro sobre `http`/websockets, sin pods nativos propios problemáticos |
| `image_picker` ^1.1.2 | ✅ Sí | Vía `image_picker_ios`; depende de las claves de cámara/fotos (ya presentes) |
| `shared_preferences` ^2.5.4 | ✅ Sí | Vía `shared_preferences_foundation` |
| `flutter_polyline_points`, `rxdart`, `equatable`, `get_it`, `intl`, `http` | ✅ Sí | Paquetes Dart puro, sin código nativo iOS |
| `google_maps_flutter_android` / `google_maps_flutter_platform_interface` | ✅ N/A para iOS | Son la implementación específica de Android y la interfaz compartida respectivamente; no afectan negativamente al build de iOS |
| `vibration` | — | **No está en `pubspec.yaml`** — no se llegó a agregar en el proyecto; el feedback háptico del onboarding usa `HapticFeedback`/`SystemSound` nativos de Flutter, que no requieren este paquete |

---

## 6. CREDENCIALES Y SEGURIDAD

- **¿API keys hardcodeadas fuera de `.env`?** ❌ No se encontraron. Se buscó en todo `lib/` por patrones de API key de Google (`AIza...`), JWT de Supabase (`eyJhbGci...`), URLs `*.supabase.co` y client IDs `*.apps.googleusercontent.com` — cero coincidencias. Todas las credenciales pasan por `String.fromEnvironment(...)` en `app_constants.dart`, alimentadas por `--dart-define-from-file=.env`, tal como documenta `CLAUDE.md`.
- **¿`DEV_MODE` (bypass con código `000000`) desactivado por defecto?** ✅ Sí. `lib/presentation/bloc/auth/auth_bloc.dart:30`:
  ```dart
  const bool kDevMode = bool.fromEnvironment('DEV_MODE', defaultValue: false);
  ```
  Solo se activa pasando explícitamente `--dart-define=DEV_MODE=true`. **Confirma que el pipeline de Codemagic para App Store NO incluya ese flag.**
- **¿La Google Maps API Key está restringida?** ⚠️ No se puede determinar desde el repositorio — la restricción (por Bundle ID iOS / SHA-1 de Android / referer) se configura en Google Cloud Console, no en el código. La misma key del `.env` (`GOOGLE_MAPS_KEY`) se usa tanto para el SDK nativo de Android como para las llamadas REST de Directions/Places. Si no está restringida por plataforma en la consola, cualquiera que extraiga la key de un build público podría reutilizarla. **Recomendación: verificar/restringir en Google Cloud Console antes de publicar.**
- **¿Hay `http://` hardcodeado que requiera `NSAppTransportSecurity`?** ❌ No. La única coincidencia de `"http://"` en `lib/` es un chequeo de prefijo genérico en `storage_service.dart` (`path.startsWith('http://')`) para detectar si una URL ya es absoluta — no es un endpoint fijo. Todas las URLs reales (Supabase, ERP) usan `https://`. No se necesita agregar excepciones ATS.

---

## 7. CODEMAGIC — REQUISITOS

- **`codemagic.yaml`**: ❌ No existe en la raíz del proyecto.
- **`Gemfile` / `Fastfile`**: ❌ Ninguno existe — no hay Fastlane configurado en el repo.
- **Variables `--dart-define` necesarias** (extraídas de `.env`):
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `GOOGLE_MAPS_KEY`
  - `GOOGLE_WEB_CLIENT_ID`
  - `SUPABASE_REDIRECT_URL`

  Como `.env` está en `.gitignore` (no viaja en el repo), Codemagic necesita estas 5 variables cargadas como *environment variables* seguras y un paso de build que las vuelque a un `.env` temporal (o las pase directo como `--dart-define=KEY=value` por cada una) antes de `flutter build ios`.
  **Nota adicional:** `GOOGLE_MAPS_KEY` también debe estar disponible como variable de entorno del sistema (no solo `--dart-define`) porque `android/app/build.gradle.kts` la lee vía `System.getenv("GOOGLE_MAPS_KEY")` para inyectarla en el manifest nativo de Android. En iOS, la key para el SDK nativo de Maps se configuraría aparte en `AppDelegate.swift` — que **actualmente no la usa en absoluto** (ver sección 8).
- **Scripts de build personalizados en `ios/`**: ❌ Ninguno más allá de los que genera el propio template de Flutter/Xcode (`Run Script` / `Thin Binary` en `project.pbxproj`, y `ios/Flutter/flutter_export_environment.sh`, que es autogenerado por `flutter build`, no un script manual del equipo).

---

## 8. APP STORE CONTENT REQUIREMENTS

| Requisito | Estado |
|---|---|
| **Privacy policy URL** | ❌ No se encontró ninguna referencia (ni pantalla in-app, ni configuración) en todo el proyecto. Esto se configura en App Store Connect, no en el repo, pero **es obligatorio** dado que Lleva recopila ubicación, fotos de documentos y datos de cuenta — sin URL de política de privacidad, Apple rechaza el submit directamente. |
| **Age rating** | No se detectó contenido para adultos (alcohol, apuestas, contenido explícito) en el código — **4+** es razonable. Se configura en App Store Connect, no en el repo. |
| **In-app purchases** | ❌ No implementadas — no hay paquete `in_app_purchase` en `pubspec.yaml` ni lógica de compras en `lib/`. El modelo de comisión (10% al conductor) se resuelve fuera de la app vía backend ERP, lo cual es válido siempre que la app no procese pagos dentro de sí misma. |
| **Google Sign-In — URL schemes declarados** | ❌ **No.** `Info.plist` no tiene ninguna clave `CFBundleURLTypes`. Sin el `REVERSED_CLIENT_ID` de Google registrado como URL scheme, el flujo de Google Sign-In en iOS **no puede completar el redirect** — esto no es solo un tema de revisión de Apple, es una falla funcional en runtime. |
| **Maps SDK — ¿requiere configuración especial en iOS?** | Sí, dos cosas ausentes hoy: (1) inicializar la API key nativa en `AppDelegate.swift` con `GMSServices.provideAPIKey("...")` **antes** de `GeneratedPluginRegistrant.register(with: self)` — el archivo actual solo registra plugins, no llama a `GMSServices` en ningún lado; y (2) el pod `GoogleMaps` instalado, lo cual es imposible mientras no exista el Podfile (sección 5). |

---

## 9. LISTA DE TAREAS PENDIENTES

### 🔴 BLOQUEANTE — sin esto no se puede compilar ni subir

1. **Crear `ios/Podfile`** (no existe) — sin él no hay `pod install` ni build de iOS posible en absoluto.
2. **Cambiar el Bundle ID** de `com.example.lleva` a `pe.lleva.app` en las 3 configuraciones (Debug/Release/Profile) del target **Runner** en `project.pbxproj` — `com.example.*` es un prefijo que Apple no permite registrar en App Store Connect.
3. **Configurar `DEVELOPMENT_TEAM = XSNN9R56MG`** en `project.pbxproj` (o vía firma automática en Xcode / variable de signing en Codemagic) — sin equipo de desarrollo no se puede archivar ni subir el build.
4. **Agregar `NSLocationWhenInUseUsageDescription` a `Info.plist`** — sin esta clave, cualquier llamada de `geolocator` pidiendo ubicación **crashea la app de inmediato en iOS** (no es un tema de revisión, es un crash garantizado en runtime).
5. **Inicializar Google Maps en `AppDelegate.swift`** con `GMSServices.provideAPIKey(...)` — sin esto el mapa simplemente no cargará en iOS aunque el build compile y se apruebe.
6. **Agregar `CFBundleURLTypes` con el `REVERSED_CLIENT_ID`** de Google Sign-In a `Info.plist` — sin esto el login con Google no puede completar su flujo en iOS.
7. **Decidir y alinear el `applicationId`/`namespace` de Android** (`android/app/build.gradle.kts`, hoy también `com.example.lleva`) — confirmar si debe pasar a `pe.lleva.app` igual que iOS, para consistencia entre plataformas.

### 🟡 IMPORTANTE — causaría rechazo en revisión de Apple

8. **Declarar `ITSAppUsesNonExemptEncryption`** en `Info.plist` (normalmente `false`, ya que la app solo usa TLS estándar de HTTPS) — si falta, Apple pregunta esto manualmente en cada build subido.
9. **Publicar una URL de política de privacidad** y configurarla en App Store Connect — obligatorio porque la app recopila ubicación, fotos y datos de cuenta.
10. **Verificar/restringir la Google Maps API Key** en Google Cloud Console (por Bundle ID iOS / SHA-1 de Android) — no se puede confirmar desde el repositorio si ya está restringida.
11. **Confirmar si se necesita `NSLocationAlwaysAndWhenInUseUsageDescription`** — depende de si el tracking del conductor debe funcionar con la app en segundo plano; Android tampoco declara `ACCESS_BACKGROUND_LOCATION` hoy, así que probablemente no aplica todavía, pero conviene confirmarlo con producto antes de decidir.
12. **Confirmar si se necesita `NSPhotoLibraryAddUsageDescription`** — solo si en algún flujo la app llega a guardar imágenes en la galería del usuario (no se encontró ese caso hoy).

### 🟢 RECOMENDADO — buenas prácticas

13. **Crear `codemagic.yaml`** para automatizar build/firma/subida (hoy no existe ningún pipeline de CI para iOS).
14. **Agregar contenido a `assets/images/`** o quitar la entrada de `pubspec.yaml` si no se va a usar — hoy la carpeta existe pero está vacía.
15. **Agregar `Gemfile`/`Fastfile`** si se planea usar Fastlane dentro de Codemagic para gestión de certificados y subida a TestFlight/App Store Connect.
16. **Confirmar que la ausencia de `PortraitUpsideDown` en iPhone es intencional** (es lo esperado para una app de mapas/conducción, pero conviene dejarlo documentado como decisión consciente).
17. Completar `ORGANIZATIONNAME` (vacío hoy) en `project.pbxproj` — cosmético, no bloqueante.
