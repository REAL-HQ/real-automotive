
-- Add columns to sites
ALTER TABLE public.sites
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'coming_soon',
  ADD COLUMN IF NOT EXISTS show_on_homepage boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS sort_order int NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS hero_image_url text;

-- Waitlist table
CREATE TABLE IF NOT EXISTS public.waitlist (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  market_id uuid REFERENCES public.markets(id) ON DELETE SET NULL,
  full_name text NOT NULL,
  email text NOT NULL,
  phone text,
  driver_status text,
  source text NOT NULL DEFAULT 'homepage_waitlist',
  utm_source text,
  utm_medium text,
  utm_campaign text,
  utm_term text,
  utm_content text,
  gclid text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT INSERT ON public.waitlist TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.waitlist TO authenticated;
GRANT ALL ON public.waitlist TO service_role;

ALTER TABLE public.waitlist ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can join waitlist" ON public.waitlist
  FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "Admins/team can view waitlist" ON public.waitlist
  FOR SELECT TO authenticated
  USING (public.has_role(auth.uid(), 'admin') OR public.has_role(auth.uid(), 'team'));

CREATE POLICY "Admins manage waitlist" ON public.waitlist
  FOR ALL TO authenticated
  USING (public.has_role(auth.uid(), 'admin'))
  WITH CHECK (public.has_role(auth.uid(), 'admin'));

-- Seed missing markets
INSERT INTO public.markets (slug, name, state)
VALUES
  ('orlando', 'Orlando', 'FL'),
  ('dallas', 'Dallas', 'TX'),
  ('las-vegas', 'Las Vegas', 'NV')
ON CONFLICT (slug) DO NOTHING;

-- Ensure sites exist for each market (use existing where present)
INSERT INTO public.sites (slug, title, market_id, is_published)
SELECT m.slug, m.name, m.id, false
FROM public.markets m
WHERE m.slug IN ('orlando','las-vegas') AND NOT EXISTS (SELECT 1 FROM public.sites s WHERE s.slug = m.slug);

-- Link any sites missing market_id (by slug)
UPDATE public.sites s SET market_id = m.id
FROM public.markets m
WHERE s.market_id IS NULL AND s.slug = m.slug;

-- Configure homepage display
UPDATE public.sites SET status='live', show_on_homepage=true, sort_order=1 WHERE slug='tampa';
UPDATE public.sites SET status='coming_soon', show_on_homepage=true, sort_order=2 WHERE slug='orlando';
UPDATE public.sites SET status='coming_soon', show_on_homepage=true, sort_order=3 WHERE slug='miami';
UPDATE public.sites SET status='coming_soon', show_on_homepage=true, sort_order=4 WHERE slug='atlanta';
UPDATE public.sites SET status='coming_soon', show_on_homepage=true, sort_order=5 WHERE slug='dallas';
UPDATE public.sites SET status='coming_soon', show_on_homepage=true, sort_order=6 WHERE slug='houston';
UPDATE public.sites SET status='coming_soon', show_on_homepage=true, sort_order=7 WHERE slug='las-vegas';
UPDATE public.sites SET show_on_homepage=false WHERE slug='phoenix';

-- Default hero images (Unsplash city photos)
UPDATE public.sites SET hero_image_url = COALESCE(hero_image_url, 'https://images.unsplash.com/photo-1605723517503-3a73d4e4c5fa?w=600&q=80') WHERE slug='tampa';
UPDATE public.sites SET hero_image_url = COALESCE(hero_image_url, 'https://images.unsplash.com/photo-1597466599360-3b9775841aec?w=600&q=80') WHERE slug='orlando';
UPDATE public.sites SET hero_image_url = COALESCE(hero_image_url, 'https://images.unsplash.com/photo-1535498730771-e735b998cd64?w=600&q=80') WHERE slug='miami';
UPDATE public.sites SET hero_image_url = COALESCE(hero_image_url, 'https://images.unsplash.com/photo-1575917649705-5b59aaa12e6b?w=600&q=80') WHERE slug='atlanta';
UPDATE public.sites SET hero_image_url = COALESCE(hero_image_url, 'https://images.unsplash.com/photo-1545194445-dddb8f4487c6?w=600&q=80') WHERE slug='dallas';
UPDATE public.sites SET hero_image_url = COALESCE(hero_image_url, 'https://images.unsplash.com/photo-1571687949921-1306bfb24b72?w=600&q=80') WHERE slug='houston';
UPDATE public.sites SET hero_image_url = COALESCE(hero_image_url, 'https://images.unsplash.com/photo-1605833556294-ea5c7a74f57d?w=600&q=80') WHERE slug='las-vegas';
