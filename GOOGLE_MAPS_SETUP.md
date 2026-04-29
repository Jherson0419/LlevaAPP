# Configuración de Google Maps para Lleva

## Problema
El mapa no se muestra porque falta configurar la API key de Google Maps.

## Solución: Obtener y Configurar la API Key

### Paso 1: Obtener una API Key de Google Maps

1. **Ve a Google Cloud Console**
   - Abre: https://console.cloud.google.com/
   - Inicia sesión con tu cuenta de Google

2. **Crea un nuevo proyecto (o selecciona uno existente)**
   - Haz clic en el selector de proyectos en la parte superior
   - Haz clic en "Nuevo proyecto"
   - Nombre: "Lleva App" (o el que prefieras)
   - Haz clic en "Crear"

3. **Habilita la API de Maps SDK for Android**
   - En el menú lateral, ve a "APIs y servicios" > "Biblioteca"
   - Busca "Maps SDK for Android"
   - Haz clic en "Maps SDK for Android"
   - Haz clic en "Habilitar"

4. **Crea una credencial (API Key)**
   - Ve a "APIs y servicios" > "Credenciales"
   - Haz clic en "Crear credenciales" > "Clave de API"
   - Se generará una API key
   - **IMPORTANTE**: Haz clic en "Restringir clave" para seguridad
   - En "Restricciones de aplicación":
     - Selecciona "Aplicaciones Android"
     - Agrega el nombre del paquete: `com.example.lleva`
     - Agrega la huella SHA-1 de tu certificado de depuración (ver abajo)

5. **Obtén tu SHA-1 (para desarrollo)**
   ```bash
   # En Windows PowerShell:
   cd android
   .\gradlew signingReport
   ```
   Busca la línea que dice "SHA1:" en la sección "Variant: debug" y copia el valor.

### Paso 2: Configurar la API Key en el Proyecto

1. **Abre el archivo AndroidManifest.xml**
   - Ruta: `android/app/src/main/AndroidManifest.xml`

2. **Reemplaza la API Key**
   - Busca esta línea:
     ```xml
     <meta-data
         android:name="com.google.android.geo.API_KEY"
         android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
     ```
   - Reemplaza `YOUR_GOOGLE_MAPS_API_KEY` con tu API key real:
     ```xml
     <meta-data
         android:name="com.google.android.geo.API_KEY"
         android:value="TU_API_KEY_AQUI"/>
     ```

### Paso 3: Verificar la Configuración

1. **Limpia y reconstruye el proyecto**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Verifica que el mapa se muestre**
   - Deberías ver el mapa de Trujillo centrado
   - El mapa debería tener estilo oscuro

## Notas Importantes

- **Seguridad**: Nunca subas tu API key a repositorios públicos
- **Límites**: Google Maps tiene límites de uso gratuitos (muy generosos para desarrollo)
- **Producción**: Para producción, asegúrate de restringir la API key correctamente

## Solución Rápida (Solo para Pruebas)

Si solo quieres probar rápidamente sin restricciones (NO recomendado para producción):

1. Crea la API key sin restricciones
2. Configúrala en el AndroidManifest.xml
3. **Recuerda restringirla después**

## Problemas Comunes

### "Mapa no disponible" o pantalla en blanco
- Verifica que la API key esté correctamente configurada
- Verifica que "Maps SDK for Android" esté habilitada
- Verifica que el SHA-1 esté agregado en las restricciones (si aplica)

### Error de permisos
- Asegúrate de que los permisos de ubicación estén en el AndroidManifest.xml (ya están configurados)

## Más Información

- Documentación oficial: https://developers.google.com/maps/documentation/android-sdk/get-api-key
- Guía de Flutter: https://pub.dev/packages/google_maps_flutter
