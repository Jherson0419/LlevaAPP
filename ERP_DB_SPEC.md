# Especificación de base de datos Lleva (ERP Java / Supabase PostgreSQL)

Documento generado a partir del análisis del código Flutter en `lib/`, con foco en `domain/entities`, `data/models` y `data/repositories`. **No se modificó código fuente.**

**Alcance:** Las únicas tablas referenciadas explícitamente vía Supabase en el repositorio son **`rides`** y **`profiles`**. No aparecen otras tablas (p. ej. vehículos, pagos desacoplados) en las consultas `.from(...)`.

**Referencias principales:** `lib/data/models/ride_model.dart`, `lib/data/models/user_model.dart`, `lib/data/repositories/ride_repository_impl.dart`, `lib/data/repositories/user_repository_impl.dart`, `lib/data/repositories/driver_repository_impl.dart`, BLoCs de viaje y conductor.

---

## 1. Diccionario de datos (tablas y columnas)

### 1.1 Tabla `rides`

Representa una solicitud/viaje. Clave primaria usada en streams Supabase: `id` (ver `RideRepositoryImpl.subscribeToRide` / `getNearbyRideRequests` con `primaryKey: ['id']`).

| Columna (PostgreSQL) | Tipo inferido | Nullable | PK/FK / Notas |
|----------------------|---------------|----------|----------------|
| `id` | `UUID` (o `TEXT` si no es UUID nativo) | NOT NULL | **PK**. En inserción puede omitirse si el cliente envía `id = 'temporal'`; entonces la BD genera el valor. |
| `client_id` | `UUID` o `TEXT` | NOT NULL | **FK lógica** → `profiles.id` (usuario que solicita el viaje). |
| `driver_id` | `UUID` o `TEXT` | Sí | **FK lógica** → `profiles.id` (conductor asignado). Puede ponerse explícitamente a `NULL` junto con `final_price` al “limpiar” conductor (`clearDriver: true`). |
| `origin_lat` | `DOUBLE PRECISION` | NOT NULL | Latitud origen. |
| `origin_lng` | `DOUBLE PRECISION` | NOT NULL | Longitud origen. |
| `dest_lat` | `DOUBLE PRECISION` | NOT NULL | Latitud destino. |
| `dest_lng` | `DOUBLE PRECISION` | NOT NULL | Longitud destino. |
| `origin_name` | `TEXT` o `VARCHAR` | NOT NULL | Nombre legible del origen. |
| `dest_name` | `TEXT` o `VARCHAR` | NOT NULL | Nombre legible del destino. |
| `status` | `VARCHAR` / `TEXT` | NOT NULL | Estado del ciclo de vida del viaje (valores en sección 3). |
| `offered_price` | `NUMERIC` o `DOUBLE PRECISION` | NOT NULL | Tarifa ofrecida por el cliente (modelo usa `double`). |
| `final_price` | `NUMERIC` o `DOUBLE PRECISION` | Sí | Precio acordado (negociación / aceptación). |
| `created_at` | `TIMESTAMP WITH TIME ZONE` | NOT NULL | Creado al insertar; en JSON se envía como ISO8601. |
| `payment_method` | `VARCHAR` | NOT NULL (default app: `efectivo`) | Método de pago (sección 3). |
| `driver_lat` | `DOUBLE PRECISION` | Sí | Última posición reportada del conductor en el viaje. |
| `driver_lng` | `DOUBLE PRECISION` | Sí | Ídem. |

**Índices / consultas frecuentes (deducidas del código):**

- Filtro `status = 'searching'` (viajes cercanos para conductores).
- Filtro `driver_id = ?` y `status = 'finished'` (estadísticas de hoy, cartera).
- Filtro `client_id = ?` o `driver_id = ?` con `ORDER BY created_at DESC` (historial).
- `gte('created_at', ...)` para ingresos del día.

---

### 1.2 Tabla `profiles`

Perfiles de aplicación (cliente o conductor). Comentarios en código: corresponde a `UserEntity` / `UserModel`.

| Columna (PostgreSQL) | Tipo inferido | Nullable | PK/FK / Notas |
|----------------------|---------------|----------|----------------|
| `id` | `UUID` o `TEXT` | NOT NULL | **PK**. En inserción puede omitirse si `id = 'temporal'` (generación en BD). En entornos Supabase suele alinearse con `auth.users.id` si existe trigger/política; el cliente Flutter no documenta ese detalle en código. |
| `phone` | `VARCHAR` o `TEXT` | NOT NULL | Búsqueda por `.eq('phone', phone)`. Convendría índice único en teléfono si la regla de negocio es un perfil por número. |
| `role` | `VARCHAR` | NOT NULL | Valores: `client` \| `driver` (sección 3). |
| `full_name` | `TEXT` o `VARCHAR` | NOT NULL | Nombre completo (`full_name` en JSON). |
| `driver_rating` | `DOUBLE PRECISION` o `NUMERIC` | Sí | **Solo lectura** en app: `DriverRepositoryImpl.getDriverRating` selecciona esta columna. No aparece en `UserModel.toJson()` de creación. |

**Campos de formulario no mapeados a BD en el código:** Las pantallas `client_register_screen.dart` y `driver_register_screen.dart` recogen datos adicionales (p. ej. email, licencia, placa, modelo de vehículo) pero **no** se envían a Supabase en los modelos actuales; el ERP no debe asumir columnas por esos formularios salvo que existan en el esquema real de Supabase fuera de este repositorio.

---

## 2. Mapeo a entidades Java (JPA)

Convención: nombres de atributos en **camelCase**; `@Column(name = "snake_case")` para coincidir con PostgreSQL/Supabase.

### 2.1 Entidad `Ride` → tabla `rides`

```java
import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "rides")
public class Ride {

    @Id
    @Column(name = "id", columnDefinition = "uuid")
    private UUID id; // o String si la columna es TEXT

    @Column(name = "client_id", nullable = false, columnDefinition = "uuid")
    private UUID clientId;

    @Column(name = "driver_id", columnDefinition = "uuid")
    private UUID driverId;

    @Column(name = "origin_lat", nullable = false)
    private Double originLat;

    @Column(name = "origin_lng", nullable = false)
    private Double originLng;

    @Column(name = "dest_lat", nullable = false)
    private Double destLat;

    @Column(name = "dest_lng", nullable = false)
    private Double destLng;

    @Column(name = "origin_name", nullable = false, columnDefinition = "text")
    private String originName;

    @Column(name = "dest_name", nullable = false, columnDefinition = "text")
    private String destName;

    @Column(name = "status", nullable = false, length = 64)
    private String status;

    @Column(name = "offered_price", nullable = false, precision = 12, scale = 2)
    private BigDecimal offeredPrice;

    @Column(name = "final_price", precision = 12, scale = 2)
    private BigDecimal finalPrice;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt;

    @Column(name = "payment_method", nullable = false, length = 32)
    private String paymentMethod;

    @Column(name = "driver_lat")
    private Double driverLat;

    @Column(name = "driver_lng")
    private Double driverLng;

    // getters/setters, equals/hashCode
}
```

**Relaciones opcionales (si se modela `Profile` y FKs reales en BD):**

```java
@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "client_id", insertable = false, updatable = false)
private Profile client;

@ManyToOne(fetch = FetchType.LAZY)
@JoinColumn(name = "driver_id", insertable = false, updatable = false)
private Profile driver;
```

*(Ajustar `insertable/updatable` según si el ERP escribe por relación o por columnas planas.)*

---

### 2.2 Entidad `Profile` → tabla `profiles`

```java
import jakarta.persistence.*;
import java.math.BigDecimal;
import java.util.UUID;

@Entity
@Table(name = "profiles")
public class Profile {

    @Id
    @Column(name = "id", columnDefinition = "uuid")
    private UUID id;

    @Column(name = "phone", nullable = false, length = 32)
    private String phone;

    @Column(name = "role", nullable = false, length = 32)
    private String role;

    @Column(name = "full_name", nullable = false, columnDefinition = "text")
    private String fullName;

    @Column(name = "driver_rating", precision = 3, scale = 2)
    private BigDecimal driverRating;

    // getters/setters
}
```

---

## 3. Reglas de negocio y estados

### 3.1 Valores de `rides.status` (persistidos en base de datos)

Estos valores aparecen en **actualizaciones o lecturas** frente a Supabase (no son solo etiquetas de UI):

| Valor | Uso en código |
|-------|----------------|
| `searching` | Solicitud creada (`ClientRideBloc`), búsqueda de conductores cercanos (`getNearbyRideRequests`), vuelta a búsqueda tras expirar contraoferta o rechazo del cliente (`updateRideStatus` con `clearDriver`). |
| `negotiating` | Contraoferta del conductor (`DriverStatusBloc._onCounterOfferRide`). |
| `accepted` | Conductor acepta (`AcceptRide`) o cliente acepta oferta (`AcceptDriverOffer`). |
| `arrived` | Conductor indica llegada al punto de recojo (`NotifyArrival`). |
| `ongoing` | Viaje en curso (`StartTrip`). |
| `finished` | Viaje terminado (`FinishTrip`); también usado en agregaciones (`getTodayDriverStats`, cartera del conductor). |

**Inconsistencia en comentarios:** `RideEntity` documenta entre otros `'completed'`, pero el flujo real y las consultas usan **`finished`** para el viaje completado. Tratar `completed` como obsoleto o dato legado si aparece en filas antiguas.

**Valores solo en UI / historial (no verificados como escritura en repositorio):**

- `cancelled`: manejado en `ride_history_screen.dart` para etiquetar; **no** hay `updateRideStatus(..., 'cancelled')` en los repositorios analizados. Puede existir en BD por otros medios (SQL directo, futuras features o datos importados).
- `unknown`: fallback en `RideModel.fromJsonForHistory` si falta estado.

### 3.2 Estados de la UI del cliente (`ClientRideState.status`)

No son columnas de BD; sirven para mapear mentalmente UX ↔ `rides.status`:

| UI (cliente) | Correlación típica con BD |
|----------------|---------------------------|
| `searching_driver` | Viaje activo con `rides.status` en `searching` (u otros según flujo). |
| `negotiating` | `negotiating`. |
| `driver_assigned` | `accepted`. |
| `driver_arrived` | `arrived`. |
| `trip_ongoing` | `ongoing`. |
| `trip_finished` | `finished`. |

(Otros: `initial`, `loading_route`, `ready_to_request`, `requesting`, `error` — solo cliente.)

### 3.3 Rol de usuario (`profiles.role`)

| Valor | Significado |
|-------|-------------|
| `client` | Pasajero. |
| `driver` | Conductor. |

Usado en `getRideHistory` para filtrar por `client_id` o `driver_id`.

### 3.4 Método de pago (`rides.payment_method`)

| Valor | Origen |
|-------|--------|
| `efectivo` | Por defecto en entidad y parsing si null/vacío (`RideModel._parsePaymentMethod`). |
| `yape` | Selección explícita en UI (`PaymentMethodChanged('yape')`); comparación case-insensitive en widgets (`paymentMethod.toLowerCase() == 'yape'`). |

El comentario en `RideEntity` indica que **otros valores pueden venir de Supabase**; el ERP debe tratar el campo como **texto abierto** o normalizar según política de producto.

### 3.5 Lógica financiera fuera de columnas

- **Comisión 10 %:** Constante `_commissionRate = 0.10` en `DriverRepositoryImpl.getWalletBalance`; se calcula en memoria sobre la suma de `final_price` con `status = 'finished'`, no como columna en `rides` o `profiles`.

---

## 4. Notas para el equipo Java / ERP

1. **Tipos UUID:** Confirmar en el esquema real de Supabase si `id`, `client_id` y `driver_id` son `uuid` o `text`; el cliente Dart los trata como `String`.
2. **FKs:** Definir restricciones `REFERENCES profiles(id)` si la BD aún no las tiene; el código asume integridad lógica.
3. **Timestamps:** Preferir `OffsetDateTime` / `TIMESTAMPTZ` para alinear con ISO8601 y zonas horarias.
4. **Montos:** Para ERP contable, valorar `NUMERIC`/`BigDecimal` frente a `double` en PostgreSQL.
5. **Seguridad:** Las políticas RLS de Supabase no están en este repositorio; el ERP con conexión directa debe aplicar autorización en aplicación o usar un rol de base de datos acotado.

---

*Fin del documento `ERP_DB_SPEC.md`.*
