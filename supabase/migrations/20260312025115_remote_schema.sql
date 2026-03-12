
  create table "public"."bank_accounts" (
    "id" uuid not null default gen_random_uuid(),
    "profile_id" uuid not null,
    "bank_name" text not null,
    "account_number" text not null,
    "account_holder" text not null,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."bank_accounts" enable row level security;

alter table "public"."po_periods" add column "month" text;

alter table "public"."po_periods" add column "po_number" integer not null default 1;

CREATE UNIQUE INDEX bank_accounts_pkey ON public.bank_accounts USING btree (id);

alter table "public"."bank_accounts" add constraint "bank_accounts_pkey" PRIMARY KEY using index "bank_accounts_pkey";

alter table "public"."bank_accounts" add constraint "bank_accounts_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES public.profiles(id) ON DELETE CASCADE not valid;

alter table "public"."bank_accounts" validate constraint "bank_accounts_profile_id_fkey";

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.assign_order_number()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_month text;
  v_max_order_number integer;
BEGIN
  -- Get the month from the linked PO period
  IF NEW.po_period_id IS NOT NULL THEN
    SELECT month INTO v_month
    FROM public.po_periods
    WHERE id = NEW.po_period_id;
  END IF;

  -- If no PO period or no month, use current year-month
  IF v_month IS NULL THEN
    v_month := to_char(now(), 'YYYY-MM');
  END IF;

  -- Find the max order_number for orders in the same month
  SELECT COALESCE(MAX(o.order_number), 0) INTO v_max_order_number
  FROM public.orders o
  LEFT JOIN public.po_periods pp ON pp.id = o.po_period_id
  WHERE COALESCE(pp.month, to_char(o.created_at, 'YYYY-MM')) = v_month
    AND o.id != NEW.id;

  NEW.order_number := v_max_order_number + 1;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.auto_manage_po_period()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_max_po_number integer;
BEGIN
  -- Only act when status is 'open'
  IF NEW.status = 'open' THEN
    -- Auto-assign po_number: find max po_number for same month, increment
    SELECT COALESCE(MAX(po_number), 0) INTO v_max_po_number
    FROM public.po_periods
    WHERE month = NEW.month
      AND id != NEW.id;

    NEW.po_number := v_max_po_number + 1;

    -- Auto-archive (close) all PO periods from previous months
    UPDATE public.po_periods
    SET status = 'closed'
    WHERE status = 'open'
      AND id != NEW.id
      AND (month IS NULL OR month < NEW.month);
  END IF;

  RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.calculate_total_price()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_subtotal bigint;
  v_ppn_percentage integer;
  v_ppn_amount bigint;
  v_shipping_cost bigint;
  v_total bigint;
begin
  select coalesce(sum(quantity * price_per_unit), 0) into v_subtotal
  from public.order_items
  where order_id = new.order_id;

  select ppn_percentage, shipping_cost into v_ppn_percentage, v_shipping_cost
  from public.orders
  where id = new.order_id;

  if v_ppn_percentage > 0 then
    v_ppn_amount := v_subtotal * v_ppn_percentage / 100;
  else
    v_ppn_amount := 0;
  end if;

  v_total := v_subtotal + v_ppn_amount + coalesce(v_shipping_cost, 0);

  update public.orders
  set total_price = v_total, ppn_amount = v_ppn_amount
  where id = new.order_id;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.recalc_total_on_ppn_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_subtotal bigint;
  v_ppn_amount bigint;
  v_total bigint;
begin
  select coalesce(sum(quantity * price_per_unit), 0) into v_subtotal
  from public.order_items
  where order_id = new.id;

  if new.ppn_percentage > 0 then
    v_ppn_amount := v_subtotal * new.ppn_percentage / 100;
  else
    v_ppn_amount := 0;
  end if;

  v_total := v_subtotal + v_ppn_amount + coalesce(new.shipping_cost, 0);

  new.total_price := v_total;
  new.ppn_amount := v_ppn_amount;
  return new;
end;
$function$
;

grant delete on table "public"."bank_accounts" to "anon";

grant insert on table "public"."bank_accounts" to "anon";

grant references on table "public"."bank_accounts" to "anon";

grant select on table "public"."bank_accounts" to "anon";

grant trigger on table "public"."bank_accounts" to "anon";

grant truncate on table "public"."bank_accounts" to "anon";

grant update on table "public"."bank_accounts" to "anon";

grant delete on table "public"."bank_accounts" to "authenticated";

grant insert on table "public"."bank_accounts" to "authenticated";

grant references on table "public"."bank_accounts" to "authenticated";

grant select on table "public"."bank_accounts" to "authenticated";

grant trigger on table "public"."bank_accounts" to "authenticated";

grant truncate on table "public"."bank_accounts" to "authenticated";

grant update on table "public"."bank_accounts" to "authenticated";

grant delete on table "public"."bank_accounts" to "service_role";

grant insert on table "public"."bank_accounts" to "service_role";

grant references on table "public"."bank_accounts" to "service_role";

grant select on table "public"."bank_accounts" to "service_role";

grant trigger on table "public"."bank_accounts" to "service_role";

grant truncate on table "public"."bank_accounts" to "service_role";

grant update on table "public"."bank_accounts" to "service_role";


  create policy "Users can manage own bank accounts"
  on "public"."bank_accounts"
  as permissive
  for all
  to public
using ((profile_id = auth.uid()))
with check ((profile_id = auth.uid()));



  create policy "Users can view own bank accounts"
  on "public"."bank_accounts"
  as permissive
  for select
  to public
using (((profile_id = auth.uid()) OR public.is_admin()));


CREATE TRIGGER trg_assign_order_number BEFORE INSERT ON public.orders FOR EACH ROW EXECUTE FUNCTION public.assign_order_number();

CREATE TRIGGER trg_auto_manage_po_period BEFORE INSERT OR UPDATE ON public.po_periods FOR EACH ROW EXECUTE FUNCTION public.auto_manage_po_period();


