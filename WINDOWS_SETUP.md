# Configuración de Windows para Flutter

## Habilitar Modo de Desarrollador

Flutter requiere el **Modo de Desarrollador** en Windows para poder crear symlinks (enlaces simbólicos) necesarios para los plugins nativos.

### Pasos para Habilitar el Modo de Desarrollador:

1. **Abre la configuración de Windows**
   - Presiona `Windows + I` o haz clic en el menú Inicio y selecciona "Configuración"
   - O ejecuta: `start ms-settings:developers`

2. **Ve a "Para desarrolladores"**
   - En la barra lateral izquierda, haz clic en "Para desarrolladores" o "Privacy & security" > "For developers"

3. **Habilita el Modo de Desarrollador**
   - Encuentra la sección "Modo de desarrollador"
   - Activa el interruptor para habilitarlo
   - Windows puede pedirte confirmación - haz clic en "Sí"

4. **Reinicia tu terminal/IDE**
   - Cierra y vuelve a abrir tu terminal de PowerShell
   - O reinicia Android Studio/VS Code si los estás usando

5. **Vuelve a ejecutar Flutter**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

## ¿Por qué es necesario?

Los plugins nativos de Flutter (como `google_maps_flutter`, `geolocator`, etc.) necesitan crear enlaces simbólicos en Windows para funcionar correctamente. El Modo de Desarrollador otorga los permisos necesarios para esto.

## Alternativa (No recomendada)

Si no puedes habilitar el Modo de Desarrollador, puedes ejecutar PowerShell como Administrador, pero esto es menos seguro y no es la solución recomendada.

## Verificar que está habilitado

Después de habilitarlo, ejecuta:
```bash
flutter doctor -v
```

Deberías ver que todo está correctamente configurado sin advertencias sobre symlinks.
