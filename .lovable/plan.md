## Section 1 — Partner Portal (`/partner`)

Build a real partner-facing portal so a logged-in partner sees only their own data. This turn = Section 1 only; Sections 2–4 (Maintenance DB, role views, AI notifications) follow in subsequent turns.

### 1. Migration (one file)

- Extend `app_role` enum: add `'partner'` (alongside existing `admin`).
- `partners`: add `user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL` so a partner row can be linked to a login. Add `revenue_split_pct numeric DEFAULT 50`.
- `vehicles`: add `partner_id uuid REFERENCES public.partners(id) ON DELETE SET NULL` so we know which partner owns each car.
- `applications` (drivers) — confirm `background_check_status`, `mvr_status` exist (they do per plan.md); add `rideshare_history_status text`, `earnings_verified_status text` (`pending|passed|failed` each).
- New `documents` table:
  - `id, driver_id (→applications), partner_id (→partners), vehicle_id (→vehicles), kind text` (`drivers_license | rental_agreement`), `storage_bucket text, storage_path text, visibility text[] default '{partner,admin}'`, timestamps.
  - RLS: admin all; partner SELECT where `partner_id` matches their partner row AND `'partner' = ANY(visibility)`.
  - GRANTs: `SELECT, INSERT, UPDATE, DELETE` to `authenticated`; `ALL` to `service_role`.
- RLS policy updates:
  - `partners`: partner can SELECT their own row (`user_id = auth.uid()`).
  - `vehicles`: partner can SELECT vehicles where `partner_id` matches their partner row.
  - `applications`: partner can SELECT only the driver currently assigned to one of their vehicles (join via `vehicle_id`), and only the vetting columns + name fields — enforced by a SECURITY DEFINER view `public.partner_driver_view` exposing just `id, full_name, vehicle_id, background_check_status, mvr_status, rideshare_history_status, earnings_verified_status`.
  - `payments`: partner can SELECT payments where vehicle belongs to their partner row.

### 2. Auth wiring

- Admin grants partner login via existing `user_roles` flow (`role='partner'`) and sets `partners.user_id` to the matched auth user. Add a small "Link Login" action in admin's `PartnersPanel` (input email → look up auth user via server fn → set user_id + insert user_roles row).
- New route `/partner` — top-level, with its own `beforeLoad` redirect: if not signed in → `/admin` (reuse SignIn), if signed in but no `partner` role → "No partner access" screen.

### 3. Partner Dashboard UI (`/partner`)

Single page, dark sidebar branding consistent with admin. Panels in this order:

1. **My Vehicles** (top): for each vehicle owned by partner, a card with photo, year/make/model, VIN, current renter name + vetting badges (Background ✓, Rideshare History ✓, Earnings Verified ✓ — green when `passed`, neutral "Pending" otherwise).
2. **Renter Documents** (per vehicle, expandable): "License" and "Rental Agreement" buttons (Lucide `IdCard`, `FileSignature`). Click → server fn returns signed URL from storage bucket, opens in new tab. No other PII shown.
3. **Pickup & Roles status note** — static info card with the exact PDF copy.
4. **How Your Split Works** — info panel with 50/50 explainer, $350 → $175 example, routine-vs-major maintenance language.
5. **Earnings Breakdown** (per vehicle): table with columns Gross Rent Collected → Your Rent Share (50%) → Maint. Share (50%) → Net. Period selector: This Week / This Month. Computed via a server fn that sums `payments` for the partner's vehicles. Maintenance share shows $0 with a "Coming with Maintenance system" hint (lands in Section 2).

### 4. Server functions (`src/lib/partner.functions.ts`)

All use `requireSupabaseAuth` + check partner role + scope by `partners.user_id = auth.uid()`:
- `getMyPartner()` → partner row + vehicles + current renter per vehicle (with vetting fields).
- `getRenterDocumentUrl({ documentId })` → signed URL (60s) from storage; verifies partner_id match before signing.
- `getMyEarnings({ period: 'week'|'month' })` → per-vehicle aggregates.
- `linkPartnerLogin({ partnerId, email })` (admin-only) → looks up auth user by email via admin client, sets `partners.user_id`, upserts `user_roles` row with `partner`.

### 5. Out of scope this turn
- Maintenance tables, shops, notifications (Sections 2–4).
- Document upload UI (admin uploads via storage console for now; we just read).
- Major-repair line-items in Earnings (added in Section 2 when `maintenance_records` exists).

### Technical notes
- Storage: reuse existing `license-uploads` bucket for licenses; new `rental-agreements` bucket (private) created in the migration via storage API call (or admin manually — confirm in migration).
- All new tables get standard GRANTs + RLS as per Lovable rules.
- White dropdowns rule preserved.
- No edge functions, no Twilio, no AI calls this turn.

### Build order in this turn
1. Migration (you approve, I wait for green light).
2. Server fns + types regenerated.
3. `/partner` route + panels.
4. Admin "Link Login" action.
