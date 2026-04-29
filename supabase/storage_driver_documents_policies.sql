-- IMPORTANTE: En Supabase → SQL → New query, pega SOLO el texto SQL de abajo.
-- NO pegues la ruta del archivo (p. ej. supabase/storage_...sql); eso provoca error de sintaxis.
--
-- Ejecutar en Supabase → SQL Editor (una sola vez por proyecto).
-- Corrige: StorageException 403 "new row violates row-level security policy" al subir fotos.
--
-- Requisitos:
--   1) Bucket llamado exactamente: driver-documents (Storage → Create bucket si no existe).
--   2) La app sube a: profiles/{auth.uid()}/archivo.ext (ver StorageService en Flutter).
--   3) Tras iniciar sesión anónima u otro login, auth.uid() coincide con esa carpeta.
--
-- Si ya existen políticas conflictivas en este bucket, elimínalas antes o ajusta los nombres.

-- Lectura pública de objetos (URLs públicas del bucket). Opcional si el bucket es "public".
DROP POLICY IF EXISTS "driver_documents_select_public" ON storage.objects;
CREATE POLICY "driver_documents_select_public"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'driver-documents');

-- Subida solo en la carpeta propia: profiles/<mi uid>/...
DROP POLICY IF EXISTS "driver_documents_insert_own" ON storage.objects;
CREATE POLICY "driver_documents_insert_own"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'driver-documents'
  AND split_part(name, '/', 1) = 'profiles'
  AND split_part(name, '/', 2) = (SELECT auth.uid())::text
);

-- upsert: true en el cliente puede requerir actualizar/sobrescribir
DROP POLICY IF EXISTS "driver_documents_update_own" ON storage.objects;
CREATE POLICY "driver_documents_update_own"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'driver-documents'
  AND split_part(name, '/', 1) = 'profiles'
  AND split_part(name, '/', 2) = (SELECT auth.uid())::text
)
WITH CHECK (
  bucket_id = 'driver-documents'
  AND split_part(name, '/', 1) = 'profiles'
  AND split_part(name, '/', 2) = (SELECT auth.uid())::text
);

DROP POLICY IF EXISTS "driver_documents_delete_own" ON storage.objects;
CREATE POLICY "driver_documents_delete_own"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'driver-documents'
  AND split_part(name, '/', 1) = 'profiles'
  AND split_part(name, '/', 2) = (SELECT auth.uid())::text
);
