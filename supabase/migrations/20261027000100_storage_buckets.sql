-- ============================================================================
-- Splitly — storage buckets + storage.objects policies (exported from the
-- live project on 2026-10-27). This is an exact copy of what is live today;
-- the security problems in it (public buckets, no owner checks) are fixed in
-- a later migration, not here.
--
-- Safe to run more than once and on a project that already has data:
--   * buckets are inserted with ON CONFLICT DO NOTHING (existing buckets and
--     their files are not touched)
--   * each policy is dropped-if-exists and re-created with the same rule
-- ============================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES
  ('chat-attachments', 'chat-attachments', true),
  ('group-photos',     'group-photos',     true),
  ('avatars',          'avatars',          true)
ON CONFLICT (id) DO NOTHING;

-- ── avatars ─────────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Anyone can view avatars" ON storage.objects;
CREATE POLICY "Anyone can view avatars" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload own avatar" ON storage.objects;
CREATE POLICY "Users can upload own avatar" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can update own avatar" ON storage.objects;
CREATE POLICY "Users can update own avatar" ON storage.objects
  FOR UPDATE USING (bucket_id = 'avatars');

-- ── group-photos ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Anyone can view group photos" ON storage.objects;
CREATE POLICY "Anyone can view group photos" ON storage.objects
  FOR SELECT USING (bucket_id = 'group-photos');

DROP POLICY IF EXISTS "Members can upload group photo" ON storage.objects;
CREATE POLICY "Members can upload group photo" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'group-photos' AND auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Members can update group photo" ON storage.objects;
CREATE POLICY "Members can update group photo" ON storage.objects
  FOR UPDATE USING (bucket_id = 'group-photos' AND auth.role() = 'authenticated');

-- ── chat-attachments ────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Anyone can view chat attachments" ON storage.objects;
CREATE POLICY "Anyone can view chat attachments" ON storage.objects
  FOR SELECT USING (bucket_id = 'chat-attachments');

DROP POLICY IF EXISTS "Authenticated users can upload chat attachments" ON storage.objects;
CREATE POLICY "Authenticated users can upload chat attachments" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'chat-attachments' AND auth.role() = 'authenticated');
