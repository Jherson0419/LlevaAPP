# Variables de entorno / secretos

Hasta el BLOQUE 1.4 de la auditoría, la URL y anon key de Supabase
([lib/main.dart](../lib/main.dart)) y la API key de Google Maps
([lib/core/constants/app_constants.dart](../lib/core/constants/app_constants.dart),
[lib/core/services/places_service.dart](../lib/core/services/places_service.dart),
[android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml))
estaban escritas literalmente en el código fuente — y por lo tanto en el
historial de git desde el commit `45cae88`. Ahora se pasan por variables de
entorno / `--dart-define`.

## ⚠️ Antes de seguir: rotar las credenciales expuestas

Mover el valor de sitio NO invalida lo que ya quedó en el historial de git
(`git log` lo sigue mostrando aunque se borre del archivo actual). Hay que
**regenerar** ambas credenciales:

1. **Supabase anon key:** Dashboard → Settings → API → "Reset" en la sección
   `anon` `public`. Actualiza el valor nuevo donde corresponda (paso 2 abajo).
2. **Google Maps API key:** Google Cloud Console → Credentials → la key
   actual → "Regenerate key" (o crea una nueva y borra la vieja). Aprovecha
   para restringirla (ver más abajo).

## 1. Correr la app localmente

1. Copia `.env.example` a `.env` en la raíz del repo y completa los valores
   reales (Supabase URL/anon key, Google Maps key, y opcionalmente
   `ERP_API_BASE_URL`).
2. `.env` está en `.gitignore` — nunca se commitea.
3. Ejecuta:
   ```bash
   flutter pub get
   flutter run --dart-define-from-file=.env
   ```
   `--dart-define-from-file` (disponible desde Flutter 3.7+; este repo usa
   3.41.9) lee el `.env` y lo aplica como si cada línea fuera
   `--dart-define=KEY=VALUE`.
4. La key de Google Maps para el **SDK nativo de Android**
   (`com.google.android.geo.API_KEY` en AndroidManifest.xml) no puede venir de
   `--dart-define` (Dart todavía no arrancó cuando Android lee el manifest).
   `android/app/build.gradle.kts` resuelve `GOOGLE_MAPS_KEY` leyendo, en este
   orden: variable de entorno `GOOGLE_MAPS_KEY`, o el mismo archivo `.env` de
   la raíz del repo. No hace falta ningún paso adicional si ya completaste el
   `.env` del punto 1 — Gradle lo lee directamente.

## 2. Restringir la Google Maps key

Una sola key sin restricciones, embebida en un APK público, es indistinguible
de publicarla. En Google Cloud Console → Credentials → tu key:
- **Restricción de aplicación:** "Android apps" con el SHA-1 del certificado
  de firma (debug y release son distintos — agrega ambos mientras desarrollas)
  y el `applicationId` (`com.example.lleva` en
  [build.gradle.kts](../android/app/build.gradle.kts) — cámbialo a tu id real
  antes de publicar, sigue con el placeholder de la plantilla de Flutter).
- **Restricción de API:** solo Maps SDK for Android.
- Las llamadas REST de `PlacesService` (Directions/Places/Geocoding) usan la
  **misma** key pero se restringen por "Android apps" igual que el SDK,
  porque se originan desde el propio dispositivo Android. Si en el futuro se
  mueven a un backend propio (recomendado — ver auditoría, sección
  Rendimiento), esa llamada server-side necesitaría una key separada con
  restricción por IP, no por app Android.

## 3. GitHub Actions / CI

El workflow ([.github/workflows/ci.yml](../.github/workflows/ci.yml)) corre
`flutter analyze` y `flutter test`, que no necesitan secretos reales. Si más
adelante se agrega un job que compile un APK real:

1. Repo → Settings → Secrets and variables → Actions → New repository secret:
   `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_MAPS_KEY`, `ERP_API_BASE_URL`.
2. En el step de build:
   ```yaml
   - name: Build APK
     run: |
       cat > .env <<EOF
       SUPABASE_URL=${{ secrets.SUPABASE_URL }}
       SUPABASE_ANON_KEY=${{ secrets.SUPABASE_ANON_KEY }}
       GOOGLE_MAPS_KEY=${{ secrets.GOOGLE_MAPS_KEY }}
       ERP_API_BASE_URL=${{ secrets.ERP_API_BASE_URL }}
       EOF
       flutter build apk --dart-define-from-file=.env
   ```
   El mismo `.env` generado en el runner alimenta tanto el lado Dart como
   `build.gradle.kts` (que también puede leer `GOOGLE_MAPS_KEY` directo de
   `System.getenv` si el secret se exporta como env var del job en vez de
   escribirse a archivo).
