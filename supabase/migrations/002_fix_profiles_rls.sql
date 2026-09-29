-- 002_fix_profiles_rls.sql
-- Reemplaza la política insegura de supabase/profiles_rls_update_driver_application.sql
-- (USING (true) / WITH CHECK (true): cualquier sesión "authenticated" -incluida una
-- sesión anónima creada con signInAnonymously()- podía actualizar CUALQUIER fila de
-- `profiles`, incluyendo is_approved, is_banned y los *_status de documentos).
--
-- IMPORTANTE — por qué esto no se arregla solo con "id = auth.uid()":
-- Acotar la política a la propia fila (id = auth.uid()) es necesario pero NO suficiente.
-- Sin protección adicional, un conductor postulante seguiría pudiendo hacer:
--   UPDATE profiles SET is_approved = true WHERE id = auth.uid();
-- ...porque esa fila SÍ es la suya. Por eso esta migración combina:
--   1) Política de fila: cada usuario solo toca su propia fila.
--   2) Trigger BEFORE INSERT/UPDATE: bloquea a nivel de COLUMNA que el propio
--      usuario cambie is_approved / is_banned / *_status, sin importar qué
--      fila esté editando. Esas columnas solo cambian si la conexión usa la
--      service_role key (el backend ERP), que en Supabase ignora RLS pero
--      sigue pasando por este trigger (se detecta con auth.role() = 'service_role').
--
-- Requisito para que "id = auth.uid()" tenga sentido: las filas de `profiles` deben
-- compartir id con el usuario de Supabase Auth (auth.users.id). Antes de esta migración
-- la app no usaba Supabase Auth para el login (ver BLOQUE 1.3 / docs/setup_phone_auth.md),
-- así que las filas creadas previamente NO van a coincidir con ningún auth.uid() hasta que
-- ese usuario vuelva a iniciar sesión con el nuevo flujo OTP (que migra el id, ver
-- UserRepositoryImpl.migrateProfileId). Hasta entonces, esos usuarios legacy no podrán
-- actualizar su propia fila por teléfono/sesión anónima -es la consecuencia esperada de
-- cerrar el hueco, no un bug de esta migración-.

begin;

-- 1) Política de fila: reemplaza la política amplia anterior.
drop policy if exists "profiles_allow_update_authenticated" on public.profiles;
drop policy if exists "profiles_update_own_row" on public.profiles;

create policy "profiles_update_own_row"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

-- (Opcional pero recomendado) política de lectura: cada usuario lee su propia fila.
-- Si la app necesita leer perfiles de OTRO usuario (p. ej. nombre/foto del conductor
-- asignado dentro de un viaje), eso debe pasar por una vista/RPC acotada
-- (ver BLOQUE 3.3 / 005_ride_enriched_view.sql) y no por SELECT directo a `profiles`.
drop policy if exists "profiles_select_own_row" on public.profiles;
create policy "profiles_select_own_row"
on public.profiles
for select
to authenticated
using (id = auth.uid());

-- 2) Protección a nivel de columna: ni siquiera en su propia fila el usuario puede
--    tocar estos campos. Solo el backend ERP (service_role) puede.
create or replace function public.protect_profile_admin_fields()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- service_role (ERP) bypassa RLS y este trigger: tiene control total.
  --
  -- Dos formas de detectarlo porque el ERP (carpeta erp/ en este repo, Spring +
  -- JPA/JpaRepository — ver erp/src/main/java/com/lleva/erp/repository/ProfileRepository.java)
  -- todavía no tiene datasource configurado (no hay application.properties ni
  -- pom.xml/build.gradle en erp/): no sabemos aún si conectará vía PostgREST con la
  -- service role key (auth.role() = 'service_role') o vía JDBC directo autenticado
  -- como el rol de Postgres `service_role` que Supabase aprovisiona en todo proyecto
  -- (current_user/session_user = 'service_role'). Cubrimos ambos casos; si el ERP
  -- termina usando un rol de Postgres distinto, hay que añadirlo aquí explícitamente.
  if auth.role() = 'service_role'
     or current_user = 'service_role'
     or session_user = 'service_role' then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- Un registro nuevo siempre nace sin aprobar y sin banear, y con documentos
    -- en PENDING, sin importar qué haya enviado el cliente en el INSERT.
    -- (clients/drivers se autoaprueban más abajo por rol; nunca via payload).
    new.is_banned := false;
    new.is_approved := coalesce(new.role = 'client', false);
    new.dni_front_status := 'PENDING';
    new.dni_back_status := 'PENDING';
    new.license_status := 'PENDING';
    new.soat_status := 'PENDING';
    new.property_card_status := 'PENDING';
    return new;
  end if;

  if tg_op = 'UPDATE' then
    -- is_approved / is_banned: nunca los cambia el propio usuario, en ninguna dirección.
    new.is_approved := old.is_approved;
    new.is_banned := old.is_banned;

    -- Los *_status de documentos: el cliente puede (re)enviar documentos, lo que
    -- legítimamente mueve el estado a PENDING (become-driver / resubida tras rechazo).
    -- Lo que NO puede hacer el cliente es moverlos a APPROVED/REJECTED -eso es
    -- exclusivo del ERP tras revisión humana-.
    if new.dni_front_status is distinct from old.dni_front_status
       and upper(coalesce(new.dni_front_status, '')) <> 'PENDING' then
      new.dni_front_status := old.dni_front_status;
    end if;
    if new.dni_back_status is distinct from old.dni_back_status
       and upper(coalesce(new.dni_back_status, '')) <> 'PENDING' then
      new.dni_back_status := old.dni_back_status;
    end if;
    if new.license_status is distinct from old.license_status
       and upper(coalesce(new.license_status, '')) <> 'PENDING' then
      new.license_status := old.license_status;
    end if;
    if new.soat_status is distinct from old.soat_status
       and upper(coalesce(new.soat_status, '')) <> 'PENDING' then
      new.soat_status := old.soat_status;
    end if;
    if new.property_card_status is distinct from old.property_card_status
       and upper(coalesce(new.property_card_status, '')) <> 'PENDING' then
      new.property_card_status := old.property_card_status;
    end if;

    return new;
  end if;

  return new;
end;
$$;

drop trigger if exists protect_profile_admin_fields_trg on public.profiles;
create trigger protect_profile_admin_fields_trg
before insert or update on public.profiles
for each row
execute function public.protect_profile_admin_fields();

commit;

-- ---------------------------------------------------------------------------
-- Verificación manual sugerida después de aplicar (reemplaza los uuid):
--
--   -- Como usuario autenticado normal (no service_role), debe NO tener efecto:
--   update profiles set is_approved = true where id = auth.uid();
--   select is_approved from profiles where id = auth.uid(); -- sigue en false
--
--   -- Como service_role (panel ERP), sí debe poder aprobar:
--   update profiles set is_approved = true where id = '<uuid-del-conductor>';
-- ---------------------------------------------------------------------------
