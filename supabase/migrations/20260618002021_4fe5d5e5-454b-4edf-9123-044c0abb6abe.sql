
INSERT INTO public.markets (name, slug, state, is_active)
VALUES ('Tampa', 'tampa', 'FL', true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.sites (slug, title, market_id, is_published)
SELECT 'tampa', 'Tampa', id, true FROM public.markets WHERE slug='tampa'
ON CONFLICT (slug) DO NOTHING;
