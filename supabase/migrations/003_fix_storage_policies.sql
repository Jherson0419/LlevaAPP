-- 003_fix_storage_policies.sql
-- Reemplaza supabase/storage_driver_documents_policies.sql.
--
-- Problema: la política SELECT del bucket `driver-documents` era pública
-- (TO public USING (bucket_id = 'driver-documents')). Cualquiera con la URL
-- -predecible: profiles/{uid}/dni_front.jpg- podía ver DNI, licencia y SOAT
-- de cualquier conductor sin autenticarse.
--
-- Fix: el bucket pasa a NO público (debe desmarcarse "Public bucket" en el
-- dashboard de Storage si estaba marcado) y la lectura queda restringida a:
--   a) el propio dueño de la carpeta (auth.uid() == carpeta del archivo), y
--   b) service_role (panel ERP, para revisar documentos de cualquier conductor).
-- La app deja de usar getPublicUrl() y pasa a pedir signed URLs de corta
-- duración (ver storage_service.dart::getDocumentSignedUrl).

begin;

-- 1) Asegurar que el bucket no es público (ajusta si usas otro nombre).
update storage.buckets set public = false where id = 'driver-documents';

-- 2) Reemplazar política de lectura pública por una restringida al dueño.
drop policy if exists "driver_documents_select_public" on storage.objects;
drop policy if exists "driver_documents_select_own" on storage.objects;

create policy "driver_documents_select_own"
on storage.objects for select
to authenticated
using (
  bucket_id = 'driver-documents'
  and split_part(name, '/', 1) = 'profiles'
  and split_part(name, '/', 2) = (select auth.uid())::text
);

-- 3) El ERP (service_role) necesita revisar documentos de CUALQUIER conductor.
--    service_role ya ignora RLS por defecto en Supabase, pero dejamos la
--    política explícita documentada por claridad/auditoría.
drop policy if exists "driver_documents_select_service_role" on storage.objects;
create policy "driver_documents_select_service_role"
on storage.objects for select
to service_role
using (bucket_id = 'driver-documents');

-- Las políticas de INSERT/UPDATE/DELETE "own" de
-- storage_driver_documents_policies.sql siguen vigentes sin cambios
-- (ya estaban correctamente acotadas a auth.uid()).

commit;

-- ---------------------------------------------------------------------------
-- Pasos manuales obligatorios (no se pueden hacer por SQL):
-- 1. Supabase Dashboard → Storage → driver-documents → Settings →
--    desactivar "Public bucket" si está activo.
-- 2. Si ya compartiste/cacheaste URLs públicas de documentos existentes,
--    estas seguirán funcionando hasta que el bucket se marque como privado;
--    una vez privado, solo las signed URLs nuevas funcionan.
-- ---------------------------------------------------------------------------
