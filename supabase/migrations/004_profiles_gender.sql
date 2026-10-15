-- Género declarado en el onboarding: 'male' | 'female' | 'other'.
alter table public.profiles
  add column if not exists gender text;
