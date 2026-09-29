-- Ejecutar en Supabase SQL Editor o como migración.
-- Ajusta referencias si `profiles` / `rides` usan otros esquemas.

create table if not exists public.ride_offers (
  id uuid primary key default gen_random_uuid(),
  ride_id uuid not null references public.rides (id) on delete cascade,
  driver_id uuid not null references public.profiles (id) on delete cascade,
  offered_price numeric not null check (offered_price >= 0),
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'withdrawn')),
  created_at timestamptz not null default now(),
  unique (ride_id, driver_id)
);

create index if not exists ride_offers_ride_id_idx on public.ride_offers (ride_id);
create index if not exists ride_offers_driver_id_idx on public.ride_offers (driver_id);

-- Transacción atómica: aceptar una oferta, rechazar el resto, asignar viaje.
create or replace function public.accept_ride_offer(
  p_offer_id uuid,
  p_ride_id uuid,
  p_driver_id uuid,
  p_final_price double precision
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.ride_offers
     set status = 'accepted'
   where id = p_offer_id
     and ride_id = p_ride_id
     and driver_id = p_driver_id
     and status = 'pending';
  if not found then
    raise exception 'INVALID_OFFER' using errcode = 'P0001';
  end if;

  update public.ride_offers
     set status = 'rejected'
   where ride_id = p_ride_id
     and id <> p_offer_id
     and status = 'pending';

  update public.rides
     set driver_id = p_driver_id,
         final_price = p_final_price,
         status = 'accepted'
   where id = p_ride_id
     and status = 'searching';
  if not found then
    raise exception 'RIDE_NOT_SEARCHING' using errcode = 'P0001';
  end if;
end;
$$;

-- Permisos (ajusta según tu modelo de RLS).
grant execute on function public.accept_ride_offer(uuid, uuid, uuid, double precision) to authenticated;
grant select, insert, update on public.ride_offers to authenticated;

-- Habilitar Realtime para la tabla (Dashboard → Replication).
-- alter publication supabase_realtime add table public.ride_offers;
