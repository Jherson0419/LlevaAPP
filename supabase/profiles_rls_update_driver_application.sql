-- Ejecutar en Supabase → SQL Editor si al enviar la solicitud de conductor ves
-- PostgrestException / 403 en la tabla profiles (RLS bloquea el UPDATE).
--
-- Contexto: la app puede usar sesión anónima para Storage; auth.uid() no siempre
-- coincide con profiles.id del usuario que ya existía como cliente. El cliente
-- actualiza la fila por profiles.id (ver UserRepositoryImpl.submitDriverApplication).
--
-- ADVERTENCIA: esta política es amplia (cualquier usuario authenticated puede
-- actualizar cualquier fila de profiles). Úsala solo en desarrollo o sustituye
-- por reglas que enlacen auth.users con profiles (p. ej. id = auth.uid()).

DROP POLICY IF EXISTS "profiles_allow_update_authenticated" ON public.profiles;

CREATE POLICY "profiles_allow_update_authenticated"
ON public.profiles
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);
