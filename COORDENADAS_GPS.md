# Guía para Obtener Coordenadas GPS Exactas

## Método 1: Google Maps (Web) - RECOMENDADO

### Pasos:
1. Abre [Google Maps](https://www.google.com/maps) en tu navegador
2. Busca el lugar exacto (ej: "UPAO Trujillo" o "Real Plaza Trujillo")
3. Haz **click derecho** en el punto exacto donde quieres la coordenada
4. Selecciona **"¿Qué hay aquí?"** o **"What's here?"**
5. En la parte inferior aparecerá un cuadro con las coordenadas
6. Copia las coordenadas (formato: `-8.1116, -79.0288`)
   - El **primer número** es la **LATITUD** (latitude)
   - El **segundo número** es la **LONGITUD** (longitude)

### Ejemplo:
```
Coordenadas mostradas: -8.1116, -79.0288
En código Dart: LatLng(-8.1116, -79.0288)
```

---

## Método 2: Google Maps (Móvil)

### Pasos:
1. Abre la app de Google Maps en tu teléfono
2. Busca el lugar exacto
3. Mantén presionado el punto exacto en el mapa
4. Se mostrará un marcador rojo y las coordenadas aparecerán en la barra de búsqueda
5. Copia las coordenadas

---

## Método 3: Usar la URL de Google Maps

### Pasos:
1. Abre Google Maps y busca el lugar
2. Haz click derecho en el punto exacto → "¿Qué hay aquí?"
3. Las coordenadas aparecen en la URL del navegador:
   ```
   https://www.google.com/maps/@-8.1116,-79.0288,15z
   ```
   - Los números después de `@` son: `latitud,longitud,zoom`

---

## Método 4: Usar Google Earth (Más Preciso)

### Pasos:
1. Descarga e instala [Google Earth](https://www.google.com/earth/)
2. Busca el lugar exacto
3. Haz click derecho en el punto → "Copiar coordenadas"
4. Selecciona el formato: **Grados decimales** (Decimal Degrees)

---

## Verificación de Coordenadas

### Formato Correcto:
- **Latitud**: Entre `-90` y `90` (negativo = Sur del ecuador)
- **Longitud**: Entre `-180` y `180` (negativo = Oeste del meridiano de Greenwich)
- **Para Trujillo, Perú**:
  - Latitud: aproximadamente `-8.0` a `-8.2`
  - Longitud: aproximadamente `-79.0` a `-79.1`

### Verificar en el Código:
```dart
// Formato correcto: LatLng(latitude, longitude)
const LatLng(-8.1116, -79.0288)  // ✓ Correcto

// Formato incorrecto (invertido):
const LatLng(-79.0288, -8.1116)  // ✗ Incorrecto
```

---

## Lugares Comunes en Trujillo

### Coordenadas que necesitas obtener:

1. **UPAO** (Universidad Privada Antenor Orrego)
   - Buscar: "UPAO Trujillo" o "Universidad Privada Antenor Orrego"
   - Dirección aproximada: Av. América Norte

2. **Real Plaza Trujillo**
   - Buscar: "Real Plaza Trujillo"
   - Dirección aproximada: Av. España

3. **Plaza de Armas Trujillo**
   - Buscar: "Plaza de Armas Trujillo"
   - Centro histórico de la ciudad

4. **Mall Aventura Plaza**
   - Buscar: "Mall Aventura Plaza Trujillo"
   - Dirección aproximada: Av. América Norte

5. **UNT** (Universidad Nacional de Trujillo)
   - Buscar: "UNT Trujillo" o "Universidad Nacional de Trujillo"
   - Dirección aproximada: Av. Juan Pablo II

6. **Aeropuerto Carlos Martínez de Pinillos**
   - Buscar: "Aeropuerto Trujillo" o "Aeropuerto Carlos Martínez"
   - Ubicado en Huanchaco

7. **Terminal Terrestre Trujillo**
   - Buscar: "Terminal Terrestre Trujillo"
   - Terminal de buses

8. **Hospital Regional de Trujillo**
   - Buscar: "Hospital Regional Trujillo"
   - Hospital principal

9. **Mercado Central Trujillo**
   - Buscar: "Mercado Central Trujillo"
   - Centro histórico

10. **Playa Huanchaco**
    - Buscar: "Playa Huanchaco Trujillo"
    - Playa turística

---

## Cómo Actualizar las Coordenadas en el Código

### Archivo: `lib/presentation/screens/driver_dashboard/driver_dashboard_screen.dart`

### Busca el método `_getMockRequests()` y actualiza:

```dart
{
  'origin': 'UPAO',
  // Reemplaza estas coordenadas con las exactas de Google Maps
  'originLatLng': const LatLng(-8.1116, -79.0288),  // ← Actualiza aquí
  'destination': 'Real Plaza',
  'destinationLatLng': const LatLng(-8.1206, -79.0315),  // ← Actualiza aquí
  'offer': 8.00,
},
```

### Importante:
- Actualiza las coordenadas en **AMBOS** métodos `_getMockRequests()`:
  1. En `_DriverDashboardScreenState` (línea ~940)
  2. En `_RideRequestItem` (línea ~987)

---

## Verificación en la App

### Logs de Depuración:
Cuando ejecutes la app, verás en la consola:
```
📍 Origen: Lat=-8.1116, Lng=-79.0288
📍 Destino: Lat=-8.1206, Lng=-79.0315
```

### Verificación Visual:
1. Ejecuta la app
2. Selecciona una solicitud del feed
3. Verifica que los marcadores aparezcan en las ubicaciones correctas en el mapa
4. Si aparecen en lugares incorrectos:
   - Las coordenadas están mal
   - O están invertidas (latitud/longitud intercambiadas)

---

## Herramientas Adicionales

### 1. Google Maps Platform - Geocoding API
- Convierte direcciones en coordenadas
- Más preciso para direcciones específicas
- Requiere API Key

### 2. OpenStreetMap Nominatim
- Alternativa gratuita a Google Maps
- URL: `https://nominatim.openstreetmap.org/`
- Busca por dirección y obtiene coordenadas

### 3. GPS Coordinates App (Móvil)
- Apps móviles que muestran tu ubicación actual
- Útil para verificar coordenadas en tiempo real

---

## Tips Finales

1. **Usa coordenadas de puntos de referencia conocidos**:
   - Entradas principales de edificios
   - Esquinas de edificios importantes
   - Señalización visible en el mapa

2. **Verifica múltiples veces**:
   - Compara coordenadas de diferentes fuentes
   - Usa Google Maps y Google Earth para confirmar

3. **Prueba en la app**:
   - Después de actualizar coordenadas, prueba la app
   - Verifica que los marcadores aparezcan en los lugares correctos

4. **Mantén consistencia**:
   - Usa el mismo formato para todas las coordenadas
   - Actualiza ambas instancias del método `_getMockRequests()`
