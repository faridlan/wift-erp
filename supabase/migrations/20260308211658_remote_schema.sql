alter table "public"."categories" add column "size_chart_url" text;

alter table "public"."order_items" add column "work_type" text not null default 'wift'::text;

alter table "public"."orders" add column "expedition_name" text;

alter table "public"."orders" add column "shipping_cost" bigint not null default 0;

alter table "public"."orders" add column "shipping_type" text not null default 'cod'::text;

alter table "public"."orders" add column "weight_kg" numeric;

alter table "public"."profiles" add column "email" text;

alter table "public"."profiles" add column "password_changed" boolean not null default false;

set check_function_bodies = off;

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


