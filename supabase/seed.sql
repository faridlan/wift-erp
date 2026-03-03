-- 0. Setup Extensions and Path
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

SET search_path TO public, auth, extensions;

-- 0. Seed Roles
INSERT INTO
    public.roles (code, name)
VALUES ('superadmin', 'Super Admin'),
    ('admin', 'Admin'),
    ('sales', 'Sales')
ON CONFLICT (code) DO NOTHING;

-- 1. Insert Users into Auth
-- Note: 'aud' and 'role' in auth.users should usually be 'authenticated'
-- for the Supabase Auth system to let them in.
INSERT INTO
    auth.users (
        id,
        instance_id,
        email,
        encrypted_password,
        raw_user_meta_data,
        raw_app_meta_data,
        email_confirmed_at,
        aud,
        role
    )
VALUES (
        '00000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000000',
        'admin@konveksi.com',
        extensions.crypt (
            'password123',
            extensions.gen_salt ('bf')
        ),
        '{"full_name": "Owner Konveksi"}',
        '{"provider":"email","providers":["email"]}',
        now(),
        'authenticated',
        'authenticated'
    ),
    (
        '00000000-0000-0000-0000-000000000002',
        '00000000-0000-0000-0000-000000000000',
        'sales1@konveksi.com',
        extensions.crypt (
            'password123',
            extensions.gen_salt ('bf')
        ),
        '{"full_name": "Budi Sales"}',
        '{"provider":"email","providers":["email"]}',
        now(),
        'authenticated',
        'authenticated'
    )
ON CONFLICT (id) DO NOTHING;

-- 2. Update Profiles (Assuming a trigger creates profiles, we update the role)
-- If your profiles aren't created by trigger, use INSERT ... ON CONFLICT
UPDATE public.profiles
SET role = 'superadmin'
WHERE
    id = '00000000-0000-0000-0000-000000000001';

UPDATE public.profiles
SET role = 'sales'
WHERE
    id = '00000000-0000-0000-0000-000000000002';

-- 3. Insert Customers
INSERT INTO
    public.customers (
        id,
        sales_id,
        name,
        phone,
        address
    )
VALUES (
        extensions.gen_random_uuid (),
        '00000000-0000-0000-0000-000000000002',
        'Toko Taktikal Jaya',
        '08123456789',
        'Bandung, Jawa Barat'
    ),
    (
        extensions.gen_random_uuid (),
        '00000000-0000-0000-0000-000000000002',
        'Koperasi Brimob',
        '08998877665',
        'Depok, Jawa Barat'
    )
ON CONFLICT DO NOTHING;

-- 4. Insert Orders (Header) & Items via PL/pgSQL
DO $$
DECLARE
    v_customer_id uuid;
    v_sales_id uuid := '00000000-0000-0000-0000-000000000002';
    v_order_id uuid;
BEGIN
    -- Get the first customer we just created
    SELECT id INTO v_customer_id FROM public.customers LIMIT 1;

    IF v_customer_id IS NOT NULL THEN
        -- Create Order
        INSERT INTO public.orders (sales_id, customer_id, status)
        VALUES (v_sales_id, v_customer_id, 'pending')
        RETURNING id INTO v_order_id;

        -- 5. Insert Order Items
        INSERT INTO public.order_items (order_id, product_name, quantity, price_per_unit)
        VALUES 
          (v_order_id, 'Kemeja Taktikal 5.11 - Hitam', 50, 150000),
          (v_order_id, 'Celana Cargo PDL - Khaki', 20, 175000);

        -- 6. Insert Payments
        INSERT INTO public.payments (order_id, amount, payment_method, notes)
        VALUES (v_order_id, 5000000, 'transfer', 'DP Produksi Tahap 1');
    END IF;
END $$;