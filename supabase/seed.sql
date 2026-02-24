-- 1. Insert Users ke Auth (Password: 'password123')
-- Kita buat satu Admin dan satu Sales
INSERT INTO
    auth.users (
        id,
        email,
        encrypted_password,
        raw_user_meta_data,
        email_confirmed_at,
        role
    )
VALUES (
        '00000000-0000-0000-0000-000000000001',
        'admin@konveksi.com',
        crypt (
            'password123',
            gen_salt ('bf')
        ),
        '{"full_name": "Owner Konveksi"}',
        now(),
        'admin'
    ),
    (
        '00000000-0000-0000-0000-000000000002',
        'sales1@konveksi.com',
        crypt (
            'password123',
            gen_salt ('bf')
        ),
        '{"full_name": "Budi Sales"}',
        now(),
        'sales'
    );

-- 2. Update Role Admin (karena trigger defaultnya adalah 'sales')
UPDATE public.profiles
SET role = 'admin'
WHERE
    id = '00000000-0000-0000-0000-000000000001';

-- 3. Insert Pelanggan (Customers)
INSERT INTO
    public.customers (
        id,
        sales_id,
        name,
        phone,
        address
    )
VALUES (
        gen_random_uuid (),
        '00000000-0000-0000-0000-000000000002',
        'Toko Taktikal Jaya',
        '08123456789',
        'Bandung, Jawa Barat'
    ),
    (
        gen_random_uuid (),
        '00000000-0000-0000-0000-000000000002',
        'Koperasi Brimob',
        '08998877665',
        'Depok, Jawa Barat'
    );

-- 4. Insert Orders (Header)
-- Kita gunakan variabel agar ID order bisa dipakai di child table
DO $$
DECLARE
    v_customer_id uuid;
    v_sales_id uuid := '00000000-0000-0000-0000-000000000002';
    v_order_id uuid;
BEGIN
    SELECT id INTO v_customer_id FROM public.customers LIMIT 1;

    -- Buat Order Baru
    INSERT INTO public.orders (sales_id, customer_id, status)
    VALUES (v_sales_id, v_customer_id, 'pending')
    RETURNING id INTO v_order_id;

    -- 5. Insert Order Items (Detail)
    -- Trigger 'update_total_price_after_change' akan otomatis menghitung total_price di tabel orders
    INSERT INTO public.order_items (order_id, product_name, quantity, price_per_unit)
    VALUES 
      (v_order_id, 'Kemeja Taktikal 5.11 - Hitam', 50, 150000),
      (v_order_id, 'Celana Cargo PDL - Khaki', 20, 175000);

    -- 6. Insert Payments
    -- Trigger 'tr_update_payment_status' akan otomatis update amount_paid dan payment_status di tabel orders
    INSERT INTO public.payments (order_id, amount, payment_method, notes)
    VALUES (v_order_id, 5000000, 'transfer', 'DP Produksi Tahap 1');

END $$;