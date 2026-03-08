
  create table "public"."product_images" (
    "id" uuid not null default gen_random_uuid(),
    "product_id" uuid not null,
    "image_url" text not null,
    "sort_order" integer not null default 0,
    "created_at" timestamp with time zone default now()
      );


alter table "public"."product_images" enable row level security;

alter table "public"."products" add column "description" text;

alter table "public"."products" add column "size_chart_url" text;

alter table "public"."profiles" add column "slug" text;

CREATE UNIQUE INDEX product_images_pkey ON public.product_images USING btree (id);

CREATE UNIQUE INDEX profiles_slug_key ON public.profiles USING btree (slug);

alter table "public"."product_images" add constraint "product_images_pkey" PRIMARY KEY using index "product_images_pkey";

alter table "public"."product_images" add constraint "product_images_product_id_fkey" FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE CASCADE not valid;

alter table "public"."product_images" validate constraint "product_images_product_id_fkey";

alter table "public"."profiles" add constraint "profiles_slug_key" UNIQUE using index "profiles_slug_key";

grant delete on table "public"."product_images" to "anon";

grant insert on table "public"."product_images" to "anon";

grant references on table "public"."product_images" to "anon";

grant select on table "public"."product_images" to "anon";

grant trigger on table "public"."product_images" to "anon";

grant truncate on table "public"."product_images" to "anon";

grant update on table "public"."product_images" to "anon";

grant delete on table "public"."product_images" to "authenticated";

grant insert on table "public"."product_images" to "authenticated";

grant references on table "public"."product_images" to "authenticated";

grant select on table "public"."product_images" to "authenticated";

grant trigger on table "public"."product_images" to "authenticated";

grant truncate on table "public"."product_images" to "authenticated";

grant update on table "public"."product_images" to "authenticated";

grant delete on table "public"."product_images" to "service_role";

grant insert on table "public"."product_images" to "service_role";

grant references on table "public"."product_images" to "service_role";

grant select on table "public"."product_images" to "service_role";

grant trigger on table "public"."product_images" to "service_role";

grant truncate on table "public"."product_images" to "service_role";

grant update on table "public"."product_images" to "service_role";


  create policy "Product images: admin can manage"
  on "public"."product_images"
  as permissive
  for all
  to public
using (public.is_admin())
with check (public.is_admin());



  create policy "Product images: public can read"
  on "public"."product_images"
  as permissive
  for select
  to public
using (true);



  create policy "Public can view sales profiles by slug"
  on "public"."profiles"
  as permissive
  for select
  to anon, authenticated
using (((role = 'sales'::text) AND (slug IS NOT NULL)));



