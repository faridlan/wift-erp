INSERT INTO
    storage.buckets (id, name, public)
VALUES ('profiles', 'profiles', true),
    ('products', 'products', true)
ON CONFLICT (id) DO NOTHING;

-- 1. Siapa saja boleh melihat foto profil (Public Read)
CREATE POLICY "Public profiles are viewable by everyone" ON storage.objects FOR
SELECT USING (bucket_id = 'profiles');

-- 2. User hanya bisa upload/update foto profil mereka sendiri
CREATE POLICY "Users can upload their own profile" ON storage.objects FOR INSERT
WITH
    CHECK (
        bucket_id = 'profiles'
        AND auth.uid ()::text = (storage.foldername (name)) [1]
    );

-- 1. Siapa saja boleh melihat foto produk (Public Read)
CREATE POLICY "Public products are viewable by everyone" ON storage.objects FOR
SELECT USING (bucket_id = 'products');

-- 2. HANYA Admin yang boleh upload/update foto produk
CREATE POLICY "Only admins can manage product images" ON storage.objects FOR ALL TO authenticated USING (public.is_admin ())
WITH
    CHECK (public.is_admin ());