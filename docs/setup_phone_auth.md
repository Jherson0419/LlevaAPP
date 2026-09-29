# Configurar Supabase Phone Auth (OTP real)

Este documento acompaña al cambio del BLOQUE 1.3 de la auditoría: el login
dejó de "autenticar" solo con el número de teléfono (sin verificar nada) y
ahora usa Supabase Auth con un código SMS real (`signInWithOtp` /
`verifyOTP`). El código Flutter ya está implementado en
[lib/presentation/bloc/auth/auth_bloc.dart](../lib/presentation/bloc/auth/auth_bloc.dart);
esta guía cubre lo que **solo se puede hacer desde el dashboard de Supabase**
y no desde el repositorio.

## 1. Activar un proveedor SMS

Supabase no envía SMS por sí mismo — necesita un proveedor externo:

1. Supabase Dashboard → tu proyecto → **Authentication → Providers → Phone**.
2. Activa "Enable Phone provider".
3. Configura uno de los proveedores soportados (recomendado para Perú: **Twilio**
   o **Twilio Verify**; alternativas: MessageBird, Vonage):
   - Crea una cuenta en el proveedor elegido y un número/servicio capaz de
     enviar SMS a números peruanos (+51).
   - Pega el Account SID / Auth Token / Messaging Service SID (o equivalente)
     en los campos que pide Supabase.
4. Guarda. Supabase mostrará un aviso si la configuración no es válida.

**Costo:** cada SMS enviado por el proveedor tiene costo (Twilio cobra por
mensaje). Antes de salir a producción, define límites de envío (ver punto 3).

## 2. Confirmar el formato de número

La app envía el número en formato E.164 con código de país fijo `+51`
(Perú) — ver `AuthBloc._toE164` en
[auth_bloc.dart](../lib/presentation/bloc/auth/auth_bloc.dart). Si la base de
usuarios target cambia de país, ese prefijo debe parametrizarse.

## 3. Limitar abuso (rate limiting)

Supabase Dashboard → **Authentication → Rate Limits**:
- `sms.max_frequency` (cooldown entre envíos al mismo número) — alinear con
  `AppConstants.smsResendCooldown` (60s) en
  [app_constants.dart](../lib/core/constants/app_constants.dart) para que el
  cooldown de la UI y el del backend no se contradigan.
- Límite de envíos por IP/hora si el proveedor lo soporta, para evitar que
  alguien use el login como vector de spam de SMS hacia números arbitrarios
  (cada `SendOtpRequested` dispara un SMS real con costo).

## 4. Migración de cuentas existentes (importante, manual)

Antes de este cambio, `profiles.id` se generaba en la base de datos sin
relación con ningún usuario de Supabase Auth (no existía login real). La
nueva política RLS (`supabase/migrations/002_fix_profiles_rls.sql`) exige
`profiles.id = auth.uid()`.

El código ya migra esto automáticamente **la primera vez que cada usuario
existente inicia sesión con el nuevo flujo OTP**
(`UserRepositoryImpl.migrateProfileId`, invocado desde
`AuthBloc._onOtpVerified`): si encuentra el perfil por teléfono y su `id` no
coincide con el `auth.uid()` recién verificado, actualiza `profiles.id` al
nuevo valor.

**Punto a verificar antes de ejecutar esto en producción:** si `rides.client_id`
y `rides.driver_id` son foreign keys hacia `profiles.id` (ver
[ERP_DB_SPEC.md](../ERP_DB_SPEC.md), que indica que el repositorio "asume
integridad lógica" pero no confirma si la FK existe realmente en la base
real), ese `UPDATE profiles SET id = ...` puede:
- Fallar con un error de violación de FK si no hay `ON UPDATE CASCADE`, o
- Dejar huérfanas las filas de `rides` antiguas de ese usuario si la FK no
  existe en absoluto (no hay error, pero el historial deja de enlazar).

Antes de desplegar este cambio a usuarios reales:
```sql
-- Ejecutar en el SQL Editor de Supabase para confirmar el estado real:
select conname, confupdtype
from pg_constraint
where conrelid = 'public.rides'::regclass
  and contype = 'f';
-- confupdtype = 'c' significa ON UPDATE CASCADE (ideal).
-- Si no existe ninguna fila para client_id/driver_id, no hay FK declarada
-- y conviene agregarla con ON UPDATE CASCADE antes de migrar usuarios reales:
alter table public.rides
  add constraint rides_client_id_fkey
  foreign key (client_id) references public.profiles(id) on update cascade,
  add constraint rides_driver_id_fkey
  foreign key (driver_id) references public.profiles(id) on update cascade;
```
Si el proyecto ya tiene datos reales de producción, planifica esto como una
ventana de mantenimiento, no como un cambio silencioso.

## 5. Rotar credenciales expuestas (independiente de Phone Auth, pero urgente)

La URL y anon key de Supabase actuales están en el historial de git desde el
commit `45cae88`. Al activar este flujo de Auth real es buen momento para:
1. Supabase Dashboard → **Settings → API** → regenerar la `anon` key.
2. Actualizar el valor en el pipeline de build (ver
   [docs/setup_env.md](setup_env.md)) — ya no debe quedar hardcodeada en el
   código fuente.

## 6. Probar el flujo de punta a punta

1. Con un número de prueba real (o el modo de prueba del proveedor SMS si lo
   ofrece), entra a `/login`, ingresa el número, confirma que llega el SMS.
2. Ingresa el código → debe autenticar (usuario existente) o llevar a
   `/register` (usuario nuevo).
3. Verifica en la tabla `profiles` que la fila tiene `id` igual al `auth.uid()`
   visible en **Authentication → Users** del dashboard.
4. Repite con un número que ya existía en `profiles` *antes* de este cambio
   para confirmar que `migrateProfileId` actualizó su `id` correctamente y
   que sigue viendo su historial de viajes después.
