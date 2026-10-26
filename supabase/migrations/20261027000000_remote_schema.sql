-- ============================================================================
-- Splitly — baseline schema (exported from the live project on 2026-10-27
-- with `supabase db dump --linked`). Tables, constraints, indexes, RPC
-- functions, RLS policies, grants and the realtime publication for `public`.
--
-- FOR A NEW, EMPTY PROJECT ONLY. Never run this on the live project — it
-- already has all of this. On the live project mark it as applied instead:
--   supabase migration repair --status applied 20261027000000
--
-- NOT in this file (they hold the project URL + webhook secret, so they live
-- in supabase/setup/webhooks_and_cron.sql and are run by hand per project):
--   * the 4 Database Webhooks (notify-new-expense / -member / -message /
--     -settlement triggers)
--   * the 2 pg_cron jobs (generate-recurring-expenses, debt-reminders-daily)
-- ============================================================================




SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";






CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";






COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."delete_group_permanently"("p_group_id" "uuid") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_creator uuid;
begin
  select created_by into v_creator from public.groups where id = p_group_id;

  if v_creator is null then
    raise exception 'Group not found';
  end if;

  if v_creator <> auth.uid() then
    raise exception 'Only the group creator can permanently delete this group';
  end if;

  delete from public.chat_read_status where group_id = p_group_id;
  delete from public.typing_status where group_id = p_group_id;
  delete from public.messages where group_id = p_group_id;
  delete from public.settlements where group_id = p_group_id;
  delete from public.expense_splits
    where expense_id in (select id from public.expenses where group_id = p_group_id);
  delete from public.expenses where group_id = p_group_id;
  delete from public.group_members where group_id = p_group_id;
  delete from public.groups where id = p_group_id;
end;
$$;


ALTER FUNCTION "public"."delete_group_permanently"("p_group_id" "uuid") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_own_account"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public', 'auth'
    AS $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Not authenticated';
  end if;

  -- Anonymize the profile — row stays so other members' expense/balance
  -- history with this person remains intact and correct.
  update public.profiles
  set full_name   = 'Deleted User',
      phone       = null,
      fcm_token   = null
  where id = uid;

  -- Scramble login credentials + ban the account so it can never sign in
  -- again. We do NOT delete the auth.users row itself — that would cascade
  -- and delete the profiles row too, which would break the foreign key
  -- constraint on any expenses this user already paid for.
  update auth.users
  set email             = 'deleted-' || uid || '@splitly.deleted',
      phone             = null,
      encrypted_password = '',
      banned_until      = '2999-12-31',
      raw_user_meta_data = '{}'::jsonb
  where id = uid;
end;
$$;


ALTER FUNCTION "public"."delete_own_account"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_recurring_expenses"() RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  rec record;
  new_expense_id uuid;
  interval_step interval;
begin
  for rec in
    select * from public.expenses
    where is_recurring = true
      and next_recur_at is not null
      and next_recur_at <= now()
  loop
    new_expense_id := gen_random_uuid();

    -- interval for this expense's frequency
    interval_step := case rec.recur_every
      when 'daily' then interval '1 day'
      when 'weekly' then interval '7 days'
      when 'monthly' then interval '1 month'
      else interval '1 month'
    end;

    -- Clone the expense as a fresh (non-recurring) entry
    insert into public.expenses (
      id, group_id, paid_by, title, amount, currency, category,
      split_type, notes, is_recurring, recur_every, next_recur_at, created_at
    ) values (
      new_expense_id, rec.group_id, rec.paid_by, rec.title, rec.amount,
      rec.currency, rec.category, rec.split_type, rec.notes,
      false, null, null, now()
    );

    -- Clone its splits
    insert into public.expense_splits (id, expense_id, user_id, amount_owed, is_settled)
    select gen_random_uuid(), new_expense_id, user_id, amount_owed, false
    from public.expense_splits
    where expense_id = rec.id;

    -- Advance the ORIGINAL recurring template to its next due date
    update public.expenses
    set next_recur_at = rec.next_recur_at + interval_step
    where id = rec.id;
  end loop;
end;
$$;


ALTER FUNCTION "public"."generate_recurring_expenses"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_group_preview_by_invite_code"("p_invite_code" "text") RETURNS TABLE("id" "uuid", "name" "text", "description" "text", "currency" "text", "category" "text", "photo_url" "text")
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select id, name, description, currency, category, photo_url
  from groups
  where invite_code = p_invite_code
    and is_archived = false;
$$;


ALTER FUNCTION "public"."get_group_preview_by_invite_code"("p_invite_code" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_my_group_ids"() RETURNS SETOF "uuid"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select group_id from group_members where user_id = auth.uid();
$$;


ALTER FUNCTION "public"."get_my_group_ids"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_unread_counts"() RETURNS TABLE("group_id" "uuid", "unread_count" bigint)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select m.group_id, count(*) as unread_count
  from messages m
  join group_members gm
    on gm.group_id = m.group_id and gm.user_id = auth.uid()
  left join chat_read_status crs
    on crs.group_id = m.group_id and crs.user_id = auth.uid()
  where m.sender_id <> auth.uid()
    and m.created_at > coalesce(crs.last_read_at, 'epoch'::timestamptz)
  group by m.group_id;
$$;


ALTER FUNCTION "public"."get_unread_counts"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_authenticated"() RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select auth.uid() is not null;
$$;


ALTER FUNCTION "public"."is_authenticated"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_group_creator"("gid" "uuid") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists(select 1 from groups where id = gid and created_by = auth.uid());
$$;


ALTER FUNCTION "public"."is_group_creator"("gid" "uuid") OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."chat_read_status" (
    "group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "last_read_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."chat_read_status" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."debt_reminders_sent" (
    "group_id" "uuid" NOT NULL,
    "debtor_id" "uuid" NOT NULL,
    "creditor_id" "uuid" NOT NULL,
    "last_reminded_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."debt_reminders_sent" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expense_splits" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "expense_id" "uuid",
    "user_id" "uuid",
    "amount_owed" numeric(12,2) NOT NULL,
    "is_settled" boolean DEFAULT false,
    "settled_at" timestamp with time zone
);


ALTER TABLE "public"."expense_splits" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."expenses" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid",
    "paid_by" "uuid",
    "title" "text" NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "currency" "text" DEFAULT 'PKR'::"text",
    "category" "text" DEFAULT 'other'::"text",
    "split_type" "text" DEFAULT 'equal'::"text",
    "receipt_url" "text",
    "notes" "text",
    "is_recurring" boolean DEFAULT false,
    "recur_every" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "next_recur_at" timestamp with time zone
);


ALTER TABLE "public"."expenses" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."group_members" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid",
    "user_id" "uuid",
    "role" "text" DEFAULT 'member'::"text",
    "joined_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."group_members" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "description" "text",
    "currency" "text" DEFAULT 'PKR'::"text",
    "created_by" "uuid",
    "invite_code" "text" DEFAULT "substr"("md5"(("random"())::"text"), 0, 9),
    "is_archived" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "category" "text" DEFAULT 'Other'::"text",
    "photo_url" "text"
);


ALTER TABLE "public"."groups" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid",
    "sender_id" "uuid",
    "content" "text" NOT NULL,
    "expense_ref" "uuid",
    "is_read" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "attachment_url" "text",
    "attachment_type" "text",
    "audio_duration" integer,
    "reply_to_id" "uuid"
);


ALTER TABLE "public"."messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."notifications" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "body" "text" NOT NULL,
    "group_id" "uuid",
    "read_at" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "entity_id" "uuid"
);


ALTER TABLE "public"."notifications" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."profiles" (
    "id" "uuid" NOT NULL,
    "full_name" "text" NOT NULL,
    "avatar_color" "text" DEFAULT '#0F766E'::"text",
    "phone" "text",
    "fcm_token" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "avatar_url" "text",
    "notify_messages" boolean DEFAULT true NOT NULL,
    "notify_expenses" boolean DEFAULT true NOT NULL,
    "notify_settlements" boolean DEFAULT true NOT NULL,
    "notify_members" boolean DEFAULT true NOT NULL,
    "notify_debt_reminders" boolean DEFAULT true NOT NULL
);


ALTER TABLE "public"."profiles" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."settlements" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "group_id" "uuid",
    "paid_by" "uuid",
    "paid_to" "uuid",
    "amount" numeric(12,2) NOT NULL,
    "currency" "text" DEFAULT 'PKR'::"text",
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."settlements" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."typing_status" (
    "group_id" "uuid" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "user_name" "text",
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."typing_status" OWNER TO "postgres";


ALTER TABLE ONLY "public"."chat_read_status"
    ADD CONSTRAINT "chat_read_status_pkey" PRIMARY KEY ("group_id", "user_id");



ALTER TABLE ONLY "public"."debt_reminders_sent"
    ADD CONSTRAINT "debt_reminders_sent_pkey" PRIMARY KEY ("group_id", "debtor_id", "creditor_id");



ALTER TABLE ONLY "public"."expense_splits"
    ADD CONSTRAINT "expense_splits_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_group_id_user_id_key" UNIQUE ("group_id", "user_id");



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_invite_code_key" UNIQUE ("invite_code");



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."settlements"
    ADD CONSTRAINT "settlements_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."typing_status"
    ADD CONSTRAINT "typing_status_pkey" PRIMARY KEY ("group_id", "user_id");



CREATE INDEX "idx_expense_splits_expense_id" ON "public"."expense_splits" USING "btree" ("expense_id");



CREATE INDEX "idx_expense_splits_user_id" ON "public"."expense_splits" USING "btree" ("user_id");



CREATE INDEX "idx_expenses_group_id" ON "public"."expenses" USING "btree" ("group_id");



CREATE INDEX "notifications_user_id_created_at_idx" ON "public"."notifications" USING "btree" ("user_id", "created_at" DESC);















ALTER TABLE ONLY "public"."chat_read_status"
    ADD CONSTRAINT "chat_read_status_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."chat_read_status"
    ADD CONSTRAINT "chat_read_status_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expense_splits"
    ADD CONSTRAINT "expense_splits_expense_id_fkey" FOREIGN KEY ("expense_id") REFERENCES "public"."expenses"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expense_splits"
    ADD CONSTRAINT "expense_splits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."expenses"
    ADD CONSTRAINT "expenses_paid_by_fkey" FOREIGN KEY ("paid_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."group_members"
    ADD CONSTRAINT "group_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."groups"
    ADD CONSTRAINT "groups_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_expense_ref_fkey" FOREIGN KEY ("expense_ref") REFERENCES "public"."expenses"("id");



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_reply_to_id_fkey" FOREIGN KEY ("reply_to_id") REFERENCES "public"."messages"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."messages"
    ADD CONSTRAINT "messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."notifications"
    ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."profiles"
    ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY ("id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."settlements"
    ADD CONSTRAINT "settlements_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."settlements"
    ADD CONSTRAINT "settlements_paid_by_fkey" FOREIGN KEY ("paid_by") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."settlements"
    ADD CONSTRAINT "settlements_paid_to_fkey" FOREIGN KEY ("paid_to") REFERENCES "public"."profiles"("id");



ALTER TABLE ONLY "public"."typing_status"
    ADD CONSTRAINT "typing_status_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "public"."groups"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."typing_status"
    ADD CONSTRAINT "typing_status_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."profiles"("id") ON DELETE CASCADE;



CREATE POLICY "Admins can remove members" ON "public"."group_members" FOR DELETE USING (("public"."is_group_creator"("group_id") OR (EXISTS ( SELECT 1
   FROM "public"."group_members" "gm"
  WHERE (("gm"."group_id" = "group_members"."group_id") AND ("gm"."user_id" = "auth"."uid"()) AND ("gm"."role" = 'admin'::"text"))))));



CREATE POLICY "Admins can update groups" ON "public"."groups" FOR UPDATE USING (("auth"."uid"() = "created_by"));



CREATE POLICY "Admins can update member roles" ON "public"."group_members" FOR UPDATE USING (("public"."is_group_creator"("group_id") OR (EXISTS ( SELECT 1
   FROM "public"."group_members" "gm"
  WHERE (("gm"."group_id" = "group_members"."group_id") AND ("gm"."user_id" = "auth"."uid"()) AND ("gm"."role" = 'admin'::"text"))))));



CREATE POLICY "Group members can read all members of their groups" ON "public"."group_members" FOR SELECT USING (("group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")));



CREATE POLICY "Members can delete own expenses" ON "public"."expenses" FOR DELETE USING (("paid_by" = "auth"."uid"()));



CREATE POLICY "Members can delete their typing status" ON "public"."typing_status" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Members can insert expenses" ON "public"."expenses" FOR INSERT WITH CHECK (("group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")));



CREATE POLICY "Members can insert settlements" ON "public"."settlements" FOR INSERT WITH CHECK (("group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")));



CREATE POLICY "Members can insert splits" ON "public"."expense_splits" FOR INSERT WITH CHECK (("expense_id" IN ( SELECT "expenses"."id"
   FROM "public"."expenses"
  WHERE ("expenses"."group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")))));



CREATE POLICY "Members can read group expenses" ON "public"."expenses" FOR SELECT USING (("group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")));



CREATE POLICY "Members can read group settlements" ON "public"."settlements" FOR SELECT USING (("group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")));



CREATE POLICY "Members can read messages" ON "public"."messages" FOR SELECT USING (("group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")));



CREATE POLICY "Members can read splits" ON "public"."expense_splits" FOR SELECT USING (("expense_id" IN ( SELECT "expenses"."id"
   FROM "public"."expenses"
  WHERE ("expenses"."group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")))));



CREATE POLICY "Members can read their groups" ON "public"."groups" FOR SELECT USING (("id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")));



CREATE POLICY "Members can read typing status" ON "public"."typing_status" FOR SELECT USING (("group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")));



CREATE POLICY "Members can send messages" ON "public"."messages" FOR INSERT WITH CHECK ((("auth"."uid"() = "sender_id") AND ("group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids"))));



CREATE POLICY "Members can update own expenses" ON "public"."expenses" FOR UPDATE USING (("paid_by" = "auth"."uid"()));



CREATE POLICY "Members can update splits in their groups" ON "public"."expense_splits" FOR UPDATE USING (("expense_id" IN ( SELECT "expenses"."id"
   FROM "public"."expenses"
  WHERE ("expenses"."group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids"))))) WITH CHECK (("expense_id" IN ( SELECT "expenses"."id"
   FROM "public"."expenses"
  WHERE ("expenses"."group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids")))));



CREATE POLICY "Members can update their typing status" ON "public"."typing_status" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Members can upsert their typing status" ON "public"."typing_status" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can create groups" ON "public"."groups" FOR INSERT WITH CHECK (("auth"."uid"() = "created_by"));



CREATE POLICY "Users can delete their own messages" ON "public"."messages" FOR DELETE USING (("auth"."uid"() = "sender_id"));



CREATE POLICY "Users can insert into group_members" ON "public"."group_members" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can insert own profile" ON "public"."profiles" FOR INSERT WITH CHECK (("auth"."uid"() = "id"));



CREATE POLICY "Users can leave groups" ON "public"."group_members" FOR DELETE USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can manage their own read status" ON "public"."chat_read_status" USING (("auth"."uid"() = "user_id")) WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read own notifications" ON "public"."notifications" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can read own or group-mates' profiles" ON "public"."profiles" FOR SELECT USING ((("auth"."uid"() = "id") OR ("id" IN ( SELECT "gm"."user_id"
   FROM "public"."group_members" "gm"
  WHERE ("gm"."group_id" IN ( SELECT "public"."get_my_group_ids"() AS "get_my_group_ids"))))));



CREATE POLICY "Users can update own notifications" ON "public"."notifications" FOR UPDATE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can update own profile" ON "public"."profiles" FOR UPDATE USING (("auth"."uid"() = "id"));



ALTER TABLE "public"."chat_read_status" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."debt_reminders_sent" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."expense_splits" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."expenses" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."group_members" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."groups" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."messages" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."notifications" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."profiles" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."settlements" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."typing_status" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."expense_splits";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."expenses";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."messages";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."settlements";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."typing_status";









GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";














































































































































































GRANT ALL ON FUNCTION "public"."delete_group_permanently"("p_group_id" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_group_permanently"("p_group_id" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_group_permanently"("p_group_id" "uuid") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_own_account"() TO "anon";
GRANT ALL ON FUNCTION "public"."delete_own_account"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_own_account"() TO "service_role";



GRANT ALL ON FUNCTION "public"."generate_recurring_expenses"() TO "anon";
GRANT ALL ON FUNCTION "public"."generate_recurring_expenses"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."generate_recurring_expenses"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_group_preview_by_invite_code"("p_invite_code" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_group_preview_by_invite_code"("p_invite_code" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_group_preview_by_invite_code"("p_invite_code" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_my_group_ids"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_my_group_ids"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_my_group_ids"() TO "service_role";



GRANT ALL ON FUNCTION "public"."get_unread_counts"() TO "anon";
GRANT ALL ON FUNCTION "public"."get_unread_counts"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_unread_counts"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_authenticated"() TO "anon";
GRANT ALL ON FUNCTION "public"."is_authenticated"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_authenticated"() TO "service_role";



GRANT ALL ON FUNCTION "public"."is_group_creator"("gid" "uuid") TO "anon";
GRANT ALL ON FUNCTION "public"."is_group_creator"("gid" "uuid") TO "authenticated";
GRANT ALL ON FUNCTION "public"."is_group_creator"("gid" "uuid") TO "service_role";
























GRANT ALL ON TABLE "public"."chat_read_status" TO "anon";
GRANT ALL ON TABLE "public"."chat_read_status" TO "authenticated";
GRANT ALL ON TABLE "public"."chat_read_status" TO "service_role";



GRANT ALL ON TABLE "public"."debt_reminders_sent" TO "anon";
GRANT ALL ON TABLE "public"."debt_reminders_sent" TO "authenticated";
GRANT ALL ON TABLE "public"."debt_reminders_sent" TO "service_role";



GRANT ALL ON TABLE "public"."expense_splits" TO "anon";
GRANT ALL ON TABLE "public"."expense_splits" TO "authenticated";
GRANT ALL ON TABLE "public"."expense_splits" TO "service_role";



GRANT ALL ON TABLE "public"."expenses" TO "anon";
GRANT ALL ON TABLE "public"."expenses" TO "authenticated";
GRANT ALL ON TABLE "public"."expenses" TO "service_role";



GRANT ALL ON TABLE "public"."group_members" TO "anon";
GRANT ALL ON TABLE "public"."group_members" TO "authenticated";
GRANT ALL ON TABLE "public"."group_members" TO "service_role";



GRANT ALL ON TABLE "public"."groups" TO "anon";
GRANT ALL ON TABLE "public"."groups" TO "authenticated";
GRANT ALL ON TABLE "public"."groups" TO "service_role";



GRANT ALL ON TABLE "public"."messages" TO "anon";
GRANT ALL ON TABLE "public"."messages" TO "authenticated";
GRANT ALL ON TABLE "public"."messages" TO "service_role";



GRANT ALL ON TABLE "public"."notifications" TO "anon";
GRANT ALL ON TABLE "public"."notifications" TO "authenticated";
GRANT ALL ON TABLE "public"."notifications" TO "service_role";



GRANT ALL ON TABLE "public"."profiles" TO "anon";
GRANT ALL ON TABLE "public"."profiles" TO "authenticated";
GRANT ALL ON TABLE "public"."profiles" TO "service_role";



GRANT ALL ON TABLE "public"."settlements" TO "anon";
GRANT ALL ON TABLE "public"."settlements" TO "authenticated";
GRANT ALL ON TABLE "public"."settlements" TO "service_role";



GRANT ALL ON TABLE "public"."typing_status" TO "anon";
GRANT ALL ON TABLE "public"."typing_status" TO "authenticated";
GRANT ALL ON TABLE "public"."typing_status" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































