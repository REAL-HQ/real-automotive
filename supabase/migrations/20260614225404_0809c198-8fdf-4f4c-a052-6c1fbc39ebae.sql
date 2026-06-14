
-- 1. Extend app_role enum with 'partner'
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'partner';

-- 2. partners: link to auth user, add split
ALTER TABLE public.partners
  ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS revenue_split_pct numeric NOT NULL DEFAULT 50;
CREATE UNIQUE INDEX IF NOT EXISTS partners_user_id_unique ON public.partners(user_id) WHERE user_id IS NOT NULL;

-- 3. vehicles: link to a partner
ALTER TABLE public.vehicles
  ADD COLUMN IF NOT EXISTS partner_id uuid REFERENCES public.partners(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS vehicles_partner_id_idx ON public.vehicles(partner_id);

-- 4. applications: add vetting statuses
ALTER TABLE public.applications
  ADD COLUMN IF NOT EXISTS rideshare_history_status text NOT NULL DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS earnings_verified_status text NOT NULL DEFAULT 'pending';

-- 5. helper: is the current user the linked partner for a partner_id?
CREATE OR REPLACE FUNCTION public.is_partner_owner(_partner_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.partners
    WHERE id = _partner_id AND user_id = auth.uid()
  )
$$;

-- helper: does the current user own (via partner) the given vehicle?
CREATE OR REPLACE FUNCTION public.partner_owns_vehicle(_vehicle_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.vehicles v
    JOIN public.partners p ON p.id = v.partner_id
    WHERE v.id = _vehicle_id AND p.user_id = auth.uid()
  )
$$;

-- 6. RLS additions

-- partners: partner can SELECT own row
DROP POLICY IF EXISTS "Partners can view their own row" ON public.partners;
CREATE POLICY "Partners can view their own row" ON public.partners
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- vehicles: partner can SELECT their vehicles
DROP POLICY IF EXISTS "Partners can view their vehicles" ON public.vehicles;
CREATE POLICY "Partners can view their vehicles" ON public.vehicles
  FOR SELECT TO authenticated
  USING (partner_id IS NOT NULL AND public.is_partner_owner(partner_id));

-- applications: partner can SELECT drivers assigned to their vehicles
DROP POLICY IF EXISTS "Partners can view their assigned drivers" ON public.applications;
CREATE POLICY "Partners can view their assigned drivers" ON public.applications
  FOR SELECT TO authenticated
  USING (vehicle_id IS NOT NULL AND public.partner_owns_vehicle(vehicle_id));

-- payments: partner can SELECT payments on their vehicles
DROP POLICY IF EXISTS "Partners can view their payments" ON public.payments;
CREATE POLICY "Partners can view their payments" ON public.payments
  FOR SELECT TO authenticated
  USING (vehicle_id IS NOT NULL AND public.partner_owns_vehicle(vehicle_id));

-- 7. documents table
CREATE TABLE IF NOT EXISTS public.documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid REFERENCES public.applications(id) ON DELETE CASCADE,
  partner_id uuid REFERENCES public.partners(id) ON DELETE SET NULL,
  vehicle_id uuid REFERENCES public.vehicles(id) ON DELETE SET NULL,
  kind text NOT NULL,
  storage_bucket text NOT NULL,
  storage_path text NOT NULL,
  visibility text[] NOT NULL DEFAULT ARRAY['partner','admin']::text[],
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.documents TO authenticated;
GRANT ALL ON public.documents TO service_role;

ALTER TABLE public.documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins manage all documents" ON public.documents
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(),'admin'))
  WITH CHECK (public.has_role(auth.uid(),'admin'));

CREATE POLICY "Partners view their visible documents" ON public.documents
  FOR SELECT TO authenticated
  USING (
    'partner' = ANY(visibility)
    AND partner_id IS NOT NULL
    AND public.is_partner_owner(partner_id)
  );

CREATE INDEX IF NOT EXISTS documents_partner_idx ON public.documents(partner_id);
CREATE INDEX IF NOT EXISTS documents_driver_idx ON public.documents(driver_id);

CREATE TRIGGER documents_set_updated_at
  BEFORE UPDATE ON public.documents
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- 8. Storage RLS on rental-agreements + license-uploads for partner reads
-- (bucket itself is created via the storage tool separately)
DROP POLICY IF EXISTS "Partners read their driver documents" ON storage.objects;
CREATE POLICY "Partners read their driver documents" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id IN ('rental-agreements','license-uploads')
    AND EXISTS (
      SELECT 1 FROM public.documents d
      WHERE d.storage_bucket = storage.objects.bucket_id
        AND d.storage_path = storage.objects.name
        AND 'partner' = ANY(d.visibility)
        AND d.partner_id IS NOT NULL
        AND public.is_partner_owner(d.partner_id)
    )
  );
