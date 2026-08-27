CREATE TABLE IF NOT EXISTS drivers (id uuid DEFAULT gen_random_uuid() PRIMARY KEY, name text NOT NULL, vehicle text NOT NULL, rating text NOT NULL, color text NOT NULL, lat double precision NOT NULL, lng double precision NOT NULL);
ALTER TABLE drivers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access" ON drivers FOR SELECT USING (true);
INSERT INTO drivers (name, vehicle, rating, color, lat, lng) VALUES
  ('Ali', 'EV Proton e.MAS 7', '4.9', '0xFF00E2A7', 3.1529, 101.7049),
  ('Candy', 'Hyundai Ioniq 5', '4.8', '0xFF40A9FF', 3.1421, 101.6953),
  ('Jenny', 'BYD Dolphin', '4.7', '0xFFFFCE3D', 3.1623, 101.7118);

CREATE TABLE IF NOT EXISTS vouchers (id text PRIMARY KEY, title text NOT NULL, description text NOT NULL, point_cost integer NOT NULL, kind text NOT NULL, icon text NOT NULL, accent_color text NOT NULL, hub_pool_credit double precision DEFAULT 0);
ALTER TABLE vouchers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access" ON vouchers FOR SELECT USING (true);
INSERT INTO vouchers (id, title, description, point_cost, kind, icon, accent_color, hub_pool_credit) VALUES
  ('hubpool-5', 'RM5 HubPool Credit', 'Add RM5 credit to your Trasia HubPool wallet.', 100, 'hubPool', 'Icons.local_taxi_rounded', '0xFF0B7CFF', 5),
  ('hubpool-10', 'RM10 HubPool Credit', 'Add RM10 credit to your Trasia HubPool wallet.', 150, 'hubPool', 'Icons.directions_car_rounded', '0xFF0057C8', 10),
  ('kfc-5', 'RM5 KFC Voucher', 'Show the demo voucher code at KFC for RM5 off.', 120, 'kfc', 'Icons.restaurant_rounded', '0xFFE1251B', 0);

CREATE OR REPLACE FUNCTION public.redeem_voucher(p_voucher_id text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  voucher public.vouchers%ROWTYPE;
  redeemed_voucher jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  SELECT * INTO voucher
  FROM public.vouchers
  WHERE id = p_voucher_id;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF voucher.kind = 'kfc' THEN
    redeemed_voucher := jsonb_build_object(
      'id', voucher.id || '-' || floor(extract(epoch FROM clock_timestamp()) * 1000)::bigint,
      'title', voucher.title,
      'description', voucher.description,
      'code', 'TRASIA-KFC-RM5',
      'redeemedAt', to_char(timezone('utc', clock_timestamp()), 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
      'usedAt', NULL
    );
  END IF;

  UPDATE public.profiles
  SET reward_points = reward_points - voucher.point_cost,
      credit = credit + voucher.hub_pool_credit,
      redeemed_vouchers = CASE
        WHEN redeemed_voucher IS NULL THEN redeemed_vouchers
        ELSE jsonb_build_array(redeemed_voucher) || coalesce(redeemed_vouchers, '[]'::jsonb)
      END,
      updated_at = timezone('utc', now())
  WHERE id = auth.uid()
    AND reward_points >= voucher.point_cost;

  RETURN FOUND;
END;
$$;

REVOKE ALL ON FUNCTION public.redeem_voucher(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.redeem_voucher(text) FROM anon;
GRANT EXECUTE ON FUNCTION public.redeem_voucher(text) TO authenticated;

CREATE TABLE IF NOT EXISTS local_suggestions (id uuid DEFAULT gen_random_uuid() PRIMARY KEY, name text NOT NULL, address text NOT NULL, place_id text NOT NULL, lat double precision NOT NULL, lng double precision NOT NULL);
ALTER TABLE local_suggestions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access" ON local_suggestions FOR SELECT USING (true);
INSERT INTO local_suggestions (name, address, place_id, lat, lng) VALUES
  ('Suria KLCC', 'Kuala Lumpur City Centre, 50088 Kuala Lumpur, Malaysia', 'local-suria-klcc', 3.1579, 101.7123),
  ('KLCC LRT Station', 'Kelana Jaya Line, Kuala Lumpur City Centre, Malaysia', 'local-klcc-lrt', 3.1590, 101.7132),
  ('Petronas Twin Towers', 'Kuala Lumpur City Centre, Kuala Lumpur, Malaysia', 'local-petronas-twin-towers', 3.1578, 101.7117),
  ('Aquaria KLCC', 'Kuala Lumpur Convention Centre, Kuala Lumpur, Malaysia', 'local-aquaria-klcc', 3.1539, 101.7131),
  ('KLCC Park', 'Kuala Lumpur City Centre, Kuala Lumpur, Malaysia', 'local-klcc-park', 3.1559, 101.7155);

CREATE TABLE IF NOT EXISTS attractions (id uuid DEFAULT gen_random_uuid() PRIMARY KEY, name text NOT NULL, hours text NOT NULL, open_minute integer NOT NULL, close_minute integer NOT NULL, base_cost integer NOT NULL, stay_minutes integer NOT NULL, suggested_distance_km integer NOT NULL, price_tier text NOT NULL, image_asset text NOT NULL, color text NOT NULL, lat double precision NOT NULL, lng double precision NOT NULL);
ALTER TABLE attractions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read access" ON attractions FOR SELECT USING (true);
INSERT INTO attractions (name, hours, open_minute, close_minute, base_cost, stay_minutes, suggested_distance_km, price_tier, image_asset, color, lat, lng) VALUES
  ('Batu Caves', '07:00 - 21:00', 420, 1260, 12, 75, 16, 'budget', 'assets/attractions/batu_caves.jpg', '0xFFFFCE3D', 3.2379, 101.6840),
  ('National Mosque', '09:00 - 17:30', 540, 1050, 0, 45, 6, 'budget', 'assets/attractions/national_mosque.jpg', '0xFF38D9FF', 3.1412, 101.6915),
  ('Central Market', '10:00 - 20:00', 600, 1200, 35, 70, 5, 'midRange', 'assets/attractions/central_market.jpg', '0xFF00E2A7', 3.1457, 101.6953),
  ('Merdeka Square', 'Open 24 hours', 0, 1440, 0, 40, 4, 'budget', 'assets/attractions/merdeka_square.jpg', '0xFF7C5CFF', 3.1478, 101.6937),
  ('Petronas Twin Towers', '09:00 - 21:00', 540, 1260, 98, 90, 7, 'luxury', 'assets/attractions/petronas_twin_towers.jpg', '0xFF40A9FF', 3.1579, 101.7116),
  ('KLCC Park', '10:00 - 22:00', 600, 1320, 0, 45, 3, 'budget', 'assets/attractions/klcc_park.jpg', '0xFFFF7A59', 3.1555, 101.7153),
  ('Aquaria KLCC', '10:00 - 20:00', 600, 1200, 62, 75, 6, 'luxury', 'assets/attractions/aquaria_klcc.jpg', '0xFF00A9CE', 3.1538, 101.7134),
  ('Perdana Botanical Garden', '07:00 - 20:00', 420, 1200, 0, 70, 8, 'budget', 'assets/attractions/perdana_botanical_garden.jpg', '0xFF3CCB7F', 3.1390, 101.6889),
  ('Thean Hou Temple', '08:00 - 22:00', 480, 1320, 0, 55, 9, 'budget', 'assets/attractions/thean_hou_temple.jpg', '0xFFFF7A59', 3.1219, 101.6870),
  ('Islamic Arts Museum Malaysia', '09:30 - 18:00', 570, 1080, 20, 80, 7, 'midRange', 'assets/attractions/islamic_arts_museum.jpg', '0xFF38D9FF', 3.1418, 101.6897),
  ('KL Tower', '09:00 - 22:00', 540, 1320, 110, 80, 8, 'luxury', 'assets/attractions/kl_tower.jpg', '0xFF40A9FF', 3.1528, 101.7037),
  ('Masjid Jamek', '10:00 - 18:00', 600, 1080, 0, 40, 4, 'budget', 'assets/attractions/jamek_mosque.jpg', '0xFF38D9FF', 3.1489, 101.6956),
  ('River of Life', '07:00 - 23:00', 420, 1380, 0, 45, 4, 'budget', 'assets/attractions/river_of_life.jpg', '0xFF40A9FF', 3.1483, 101.6965),
  ('Royal Selangor Visitor Centre', '09:00 - 17:00', 540, 1020, 80, 85, 12, 'luxury', 'assets/attractions/royal_selangor.jpg', '0xFF8793A4', 3.1967, 101.7246),
  ('Muzium Negara', '09:00 - 17:00', 540, 1020, 5, 60, 7, 'budget', 'assets/attractions/museum_negara.jpg', '0xFF7C5CFF', 3.1379, 101.6870),
  ('Little India Brickfields', '10:00 - 22:00', 600, 1320, 25, 65, 8, 'midRange', 'assets/attractions/little_india_brickfields.jpg', '0xFFFFCE3D', 3.1291, 101.6841),
  ('Jalan Alor', '17:00 - 00:00', 1020, 1440, 45, 75, 6, 'midRange', 'assets/attractions/jalan_alor.jpg', '0xFFFF7A59', 3.1466, 101.7088),
  ('Kwai Chai Hong', '09:00 - 00:00', 540, 1440, 25, 55, 5, 'midRange', 'assets/attractions/kwai_chai_hong.jpg', '0xFF7C5CFF', 3.1415, 101.6979),
  ('REXKL', '10:00 - 22:00', 600, 1320, 40, 70, 5, 'midRange', 'assets/attractions/rexkl.jpg', '0xFF00E2A7', 3.1420, 101.6992),
  ('Tugu Negara', '07:00 - 18:00', 420, 1080, 0, 45, 9, 'budget', 'assets/attractions/tugu_negara.jpg', '0xFF8793A4', 3.1490, 101.6839),
  ('Berjaya Times Square', '10:00 - 22:00', 600, 1320, 80, 80, 7, 'luxury', 'assets/attractions/berjaya_times_square.jpg', '0xFFFFCE3D', 3.1426, 101.7106),
  ('Pavilion Kuala Lumpur', '10:00 - 22:00', 600, 1320, 120, 90, 6, 'luxury', 'assets/attractions/pavilion_kl.jpg', '0xFF40A9FF', 3.1490, 101.7132),
  ('Titiwangsa Lake Gardens', '06:00 - 22:00', 360, 1320, 0, 60, 10, 'budget', 'assets/attractions/titiwangsa_lake_gardens.jpg', '0xFF3CCB7F', 3.1781, 101.7044),
  ('Bank Negara Malaysia Museum', '10:00 - 17:00', 600, 1020, 10, 70, 8, 'midRange', 'assets/attractions/bank_negara_museum.jpg', '0xFF7C5CFF', 3.1592, 101.6925),
  ('Bukit Bintang Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 3, 'midRange', 'assets/attractions/area_bukit_bintang.jpg', '0xFFFF7A59', 3.1437999999999997, 101.7143),
  ('Bukit Bintang Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 6, 'midRange', 'assets/attractions/area_bukit_bintang.jpg', '0xFF40A9FF', 3.145, 101.7131),
  ('Bukit Bintang Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 9, 'budget', 'assets/attractions/area_bukit_bintang.jpg', '0xFFFFCE3D', 3.1462, 101.7119),
  ('Bukit Bintang Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 12, 'budget', 'assets/attractions/area_bukit_bintang.jpg', '0xFF7C5CFF', 3.1473999999999998, 101.71069999999999),
  ('Bukit Bintang Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 15, 'budget', 'assets/attractions/area_bukit_bintang.jpg', '0xFF3CCB7F', 3.1485999999999996, 101.70949999999999),
  ('Bukit Bintang Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 18, 'luxury', 'assets/attractions/area_bukit_bintang.jpg', '0xFF00A9CE', 3.1498, 101.7083),
  ('Chinatown Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 8, 'midRange', 'assets/attractions/area_chinatown.jpg', '0xFFFF7A59', 3.1391, 101.6994),
  ('Chinatown Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 11, 'midRange', 'assets/attractions/area_chinatown.jpg', '0xFF40A9FF', 3.1403000000000003, 101.6982),
  ('Chinatown Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 14, 'budget', 'assets/attractions/area_chinatown.jpg', '0xFFFFCE3D', 3.1415, 101.697),
  ('Chinatown Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 17, 'budget', 'assets/attractions/area_chinatown.jpg', '0xFF7C5CFF', 3.1427, 101.69579999999999),
  ('Chinatown Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 20, 'budget', 'assets/attractions/area_chinatown.jpg', '0xFF3CCB7F', 3.1439, 101.6946),
  ('Chinatown Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 23, 'luxury', 'assets/attractions/area_chinatown.jpg', '0xFF00A9CE', 3.1451000000000002, 101.6934),
  ('KLCC Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 13, 'midRange', 'assets/attractions/area_klcc.jpg', '0xFFFF7A59', 3.1549, 101.7153),
  ('KLCC Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 16, 'midRange', 'assets/attractions/area_klcc.jpg', '0xFF40A9FF', 3.1561000000000003, 101.7141),
  ('KLCC Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 19, 'budget', 'assets/attractions/area_klcc.jpg', '0xFFFFCE3D', 3.1573, 101.7129),
  ('KLCC Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 22, 'budget', 'assets/attractions/area_klcc.jpg', '0xFF7C5CFF', 3.1585, 101.7117),
  ('KLCC Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 25, 'budget', 'assets/attractions/area_klcc.jpg', '0xFF3CCB7F', 3.1597, 101.7105),
  ('KLCC Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 28, 'luxury', 'assets/attractions/area_klcc.jpg', '0xFF00A9CE', 3.1609000000000003, 101.7093),
  ('Brickfields Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 18, 'midRange', 'assets/attractions/area_brickfields.jpg', '0xFFFF7A59', 3.1261, 101.6871),
  ('Brickfields Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 21, 'midRange', 'assets/attractions/area_brickfields.jpg', '0xFF40A9FF', 3.1273000000000004, 101.6859),
  ('Brickfields Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 24, 'budget', 'assets/attractions/area_brickfields.jpg', '0xFFFFCE3D', 3.1285000000000003, 101.6847),
  ('Brickfields Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 27, 'budget', 'assets/attractions/area_brickfields.jpg', '0xFF7C5CFF', 3.1297, 101.6835),
  ('Brickfields Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 30, 'budget', 'assets/attractions/area_brickfields.jpg', '0xFF3CCB7F', 3.1309, 101.6823),
  ('Brickfields Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 33, 'luxury', 'assets/attractions/area_brickfields.jpg', '0xFF00A9CE', 3.1321000000000003, 101.6811),
  ('Chow Kit Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 23, 'midRange', 'assets/attractions/area_chow_kit.jpg', '0xFFFF7A59', 3.1645, 101.701),
  ('Chow Kit Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 26, 'midRange', 'assets/attractions/area_chow_kit.jpg', '0xFF40A9FF', 3.1657, 101.6998),
  ('Chow Kit Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 29, 'budget', 'assets/attractions/area_chow_kit.jpg', '0xFFFFCE3D', 3.1669, 101.6986),
  ('Chow Kit Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 32, 'budget', 'assets/attractions/area_chow_kit.jpg', '0xFF7C5CFF', 3.1681, 101.69739999999999),
  ('Chow Kit Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 35, 'budget', 'assets/attractions/area_chow_kit.jpg', '0xFF3CCB7F', 3.1693, 101.69619999999999),
  ('Chow Kit Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 38, 'luxury', 'assets/attractions/area_chow_kit.jpg', '0xFF00A9CE', 3.1705, 101.695),
  ('Kampung Baru Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 28, 'midRange', 'assets/attractions/area_kampung_baru.jpg', '0xFFFF7A59', 3.1611, 101.7098),
  ('Kampung Baru Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 31, 'midRange', 'assets/attractions/area_kampung_baru.jpg', '0xFF40A9FF', 3.1623, 101.7086),
  ('Kampung Baru Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 34, 'budget', 'assets/attractions/area_kampung_baru.jpg', '0xFFFFCE3D', 3.1635, 101.7074),
  ('Kampung Baru Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 37, 'budget', 'assets/attractions/area_kampung_baru.jpg', '0xFF7C5CFF', 3.1647, 101.7062),
  ('Kampung Baru Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 40, 'budget', 'assets/attractions/area_kampung_baru.jpg', '0xFF3CCB7F', 3.1658999999999997, 101.705),
  ('Kampung Baru Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 5, 'luxury', 'assets/attractions/area_kampung_baru.jpg', '0xFF00A9CE', 3.1671, 101.7038),
  ('Bangsar Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 33, 'midRange', 'assets/attractions/area_bangsar.jpg', '0xFFFF7A59', 3.1262, 101.6814),
  ('Bangsar Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 36, 'midRange', 'assets/attractions/area_bangsar.jpg', '0xFF40A9FF', 3.1274, 101.6802),
  ('Bangsar Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 39, 'budget', 'assets/attractions/area_bangsar.jpg', '0xFFFFCE3D', 3.1286, 101.679),
  ('Bangsar Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 4, 'budget', 'assets/attractions/area_bangsar.jpg', '0xFF7C5CFF', 3.1298, 101.67779999999999),
  ('Bangsar Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 7, 'budget', 'assets/attractions/area_bangsar.jpg', '0xFF3CCB7F', 3.131, 101.6766),
  ('Bangsar Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 10, 'luxury', 'assets/attractions/area_bangsar.jpg', '0xFF00A9CE', 3.1322, 101.6754),
  ('Mont Kiara Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 38, 'midRange', 'assets/attractions/area_mont_kiara.jpg', '0xFFFF7A59', 3.167, 101.6559),
  ('Mont Kiara Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 3, 'midRange', 'assets/attractions/area_mont_kiara.jpg', '0xFF40A9FF', 3.1682, 101.6547),
  ('Mont Kiara Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 6, 'budget', 'assets/attractions/area_mont_kiara.jpg', '0xFFFFCE3D', 3.1694, 101.65350000000001),
  ('Mont Kiara Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 9, 'budget', 'assets/attractions/area_mont_kiara.jpg', '0xFF7C5CFF', 3.1706, 101.6523),
  ('Mont Kiara Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 12, 'budget', 'assets/attractions/area_mont_kiara.jpg', '0xFF3CCB7F', 3.1717999999999997, 101.6511),
  ('Mont Kiara Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 15, 'luxury', 'assets/attractions/area_mont_kiara.jpg', '0xFF00A9CE', 3.173, 101.6499),
  ('TTDI Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 5, 'midRange', 'assets/attractions/area_ttdi.jpg', '0xFFFF7A59', 3.1383, 101.6327),
  ('TTDI Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 8, 'midRange', 'assets/attractions/area_ttdi.jpg', '0xFF40A9FF', 3.1395000000000004, 101.6315),
  ('TTDI Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 11, 'budget', 'assets/attractions/area_ttdi.jpg', '0xFFFFCE3D', 3.1407000000000003, 101.6303),
  ('TTDI Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 14, 'budget', 'assets/attractions/area_ttdi.jpg', '0xFF7C5CFF', 3.1419, 101.6291),
  ('TTDI Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 17, 'budget', 'assets/attractions/area_ttdi.jpg', '0xFF3CCB7F', 3.1431, 101.6279),
  ('TTDI Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 20, 'luxury', 'assets/attractions/area_ttdi.jpg', '0xFF00A9CE', 3.1443000000000003, 101.6267),
  ('Cheras Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 10, 'midRange', 'assets/attractions/area_cheras.jpg', '0xFFFF7A59', 3.1037999999999997, 101.7289),
  ('Cheras Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 13, 'midRange', 'assets/attractions/area_cheras.jpg', '0xFF40A9FF', 3.105, 101.7277),
  ('Cheras Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 16, 'budget', 'assets/attractions/area_cheras.jpg', '0xFFFFCE3D', 3.1062, 101.7265),
  ('Cheras Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 19, 'budget', 'assets/attractions/area_cheras.jpg', '0xFF7C5CFF', 3.1073999999999997, 101.72529999999999),
  ('Cheras Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 22, 'budget', 'assets/attractions/area_cheras.jpg', '0xFF3CCB7F', 3.1085999999999996, 101.72409999999999),
  ('Cheras Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 25, 'luxury', 'assets/attractions/area_cheras.jpg', '0xFF00A9CE', 3.1098, 101.7229),
  ('Ampang Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 15, 'midRange', 'assets/attractions/area_ampang.jpg', '0xFFFF7A59', 3.1471999999999998, 101.763),
  ('Ampang Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 18, 'midRange', 'assets/attractions/area_ampang.jpg', '0xFF40A9FF', 3.1484, 101.76180000000001),
  ('Ampang Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 21, 'budget', 'assets/attractions/area_ampang.jpg', '0xFFFFCE3D', 3.1496, 101.76060000000001),
  ('Ampang Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 24, 'budget', 'assets/attractions/area_ampang.jpg', '0xFF7C5CFF', 3.1508, 101.7594),
  ('Ampang Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 27, 'budget', 'assets/attractions/area_ampang.jpg', '0xFF3CCB7F', 3.1519999999999997, 101.7582),
  ('Ampang Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 30, 'luxury', 'assets/attractions/area_ampang.jpg', '0xFF00A9CE', 3.1532, 101.757),
  ('Setapak Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 20, 'midRange', 'assets/attractions/area_setapak.jpg', '0xFFFF7A59', 3.1851, 101.7136),
  ('Setapak Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 23, 'midRange', 'assets/attractions/area_setapak.jpg', '0xFF40A9FF', 3.1863, 101.7124),
  ('Setapak Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 26, 'budget', 'assets/attractions/area_setapak.jpg', '0xFFFFCE3D', 3.1875, 101.7112),
  ('Setapak Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 29, 'budget', 'assets/attractions/area_setapak.jpg', '0xFF7C5CFF', 3.1887, 101.71),
  ('Setapak Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 32, 'budget', 'assets/attractions/area_setapak.jpg', '0xFF3CCB7F', 3.1898999999999997, 101.7088),
  ('Setapak Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 35, 'luxury', 'assets/attractions/area_setapak.jpg', '0xFF00A9CE', 3.1911, 101.7076),
  ('Sentul Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 25, 'midRange', 'assets/attractions/area_sentul.jpg', '0xFFFF7A59', 3.1808, 101.6953),
  ('Sentul Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 28, 'midRange', 'assets/attractions/area_sentul.jpg', '0xFF40A9FF', 3.1820000000000004, 101.6941),
  ('Sentul Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 31, 'budget', 'assets/attractions/area_sentul.jpg', '0xFFFFCE3D', 3.1832000000000003, 101.69290000000001),
  ('Sentul Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 34, 'budget', 'assets/attractions/area_sentul.jpg', '0xFF7C5CFF', 3.1844, 101.6917),
  ('Sentul Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 37, 'budget', 'assets/attractions/area_sentul.jpg', '0xFF3CCB7F', 3.1856, 101.6905),
  ('Sentul Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 40, 'luxury', 'assets/attractions/area_sentul.jpg', '0xFF00A9CE', 3.1868000000000003, 101.6893),
  ('Titiwangsa Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 30, 'midRange', 'assets/attractions/area_titiwangsa.jpg', '0xFFFF7A59', 3.1774, 101.7067),
  ('Titiwangsa Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 33, 'midRange', 'assets/attractions/area_titiwangsa.jpg', '0xFF40A9FF', 3.1786000000000003, 101.7055),
  ('Titiwangsa Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 36, 'budget', 'assets/attractions/area_titiwangsa.jpg', '0xFFFFCE3D', 3.1798, 101.7043),
  ('Titiwangsa Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 39, 'budget', 'assets/attractions/area_titiwangsa.jpg', '0xFF7C5CFF', 3.181, 101.70309999999999),
  ('Titiwangsa Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 4, 'budget', 'assets/attractions/area_titiwangsa.jpg', '0xFF3CCB7F', 3.1822, 101.7019),
  ('Titiwangsa Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 7, 'luxury', 'assets/attractions/area_titiwangsa.jpg', '0xFF00A9CE', 3.1834000000000002, 101.7007),
  ('Petaling Jaya Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 35, 'midRange', 'assets/attractions/area_petaling_jaya.jpg', '0xFFFF7A59', 3.1043, 101.6097),
  ('Petaling Jaya Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 38, 'midRange', 'assets/attractions/area_petaling_jaya.jpg', '0xFF40A9FF', 3.1055, 101.6085),
  ('Petaling Jaya Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 3, 'budget', 'assets/attractions/area_petaling_jaya.jpg', '0xFFFFCE3D', 3.1067, 101.60730000000001),
  ('Petaling Jaya Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 6, 'budget', 'assets/attractions/area_petaling_jaya.jpg', '0xFF7C5CFF', 3.1079, 101.6061),
  ('Petaling Jaya Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 9, 'budget', 'assets/attractions/area_petaling_jaya.jpg', '0xFF3CCB7F', 3.1090999999999998, 101.6049),
  ('Petaling Jaya Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 12, 'luxury', 'assets/attractions/area_petaling_jaya.jpg', '0xFF00A9CE', 3.1103, 101.6037),
  ('Subang Jaya Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 40, 'midRange', 'assets/attractions/area_subang_jaya.jpg', '0xFFFF7A59', 3.0537, 101.5881),
  ('Subang Jaya Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 5, 'midRange', 'assets/attractions/area_subang_jaya.jpg', '0xFF40A9FF', 3.0549000000000004, 101.5869),
  ('Subang Jaya Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 8, 'budget', 'assets/attractions/area_subang_jaya.jpg', '0xFFFFCE3D', 3.0561000000000003, 101.5857),
  ('Subang Jaya Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 11, 'budget', 'assets/attractions/area_subang_jaya.jpg', '0xFF7C5CFF', 3.0573, 101.58449999999999),
  ('Subang Jaya Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 14, 'budget', 'assets/attractions/area_subang_jaya.jpg', '0xFF3CCB7F', 3.0585, 101.5833),
  ('Subang Jaya Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 17, 'luxury', 'assets/attractions/area_subang_jaya.jpg', '0xFF00A9CE', 3.0597000000000003, 101.5821),
  ('Shah Alam Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 7, 'midRange', 'assets/attractions/area_shah_alam.jpg', '0xFFFF7A59', 3.0707999999999998, 101.5213),
  ('Shah Alam Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 10, 'midRange', 'assets/attractions/area_shah_alam.jpg', '0xFF40A9FF', 3.072, 101.5201),
  ('Shah Alam Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 13, 'budget', 'assets/attractions/area_shah_alam.jpg', '0xFFFFCE3D', 3.0732, 101.5189),
  ('Shah Alam Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 16, 'budget', 'assets/attractions/area_shah_alam.jpg', '0xFF7C5CFF', 3.0744, 101.51769999999999),
  ('Shah Alam Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 19, 'budget', 'assets/attractions/area_shah_alam.jpg', '0xFF3CCB7F', 3.0755999999999997, 101.5165),
  ('Shah Alam Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 22, 'luxury', 'assets/attractions/area_shah_alam.jpg', '0xFF00A9CE', 3.0768, 101.5153),
  ('Puchong Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 12, 'midRange', 'assets/attractions/area_puchong.jpg', '0xFFFF7A59', 3.0297, 101.6218),
  ('Puchong Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 15, 'midRange', 'assets/attractions/area_puchong.jpg', '0xFF40A9FF', 3.0309000000000004, 101.6206),
  ('Puchong Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 18, 'budget', 'assets/attractions/area_puchong.jpg', '0xFFFFCE3D', 3.0321000000000002, 101.6194),
  ('Puchong Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 21, 'budget', 'assets/attractions/area_puchong.jpg', '0xFF7C5CFF', 3.0333, 101.61819999999999),
  ('Puchong Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 24, 'budget', 'assets/attractions/area_puchong.jpg', '0xFF3CCB7F', 3.0345, 101.61699999999999),
  ('Puchong Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 27, 'luxury', 'assets/attractions/area_puchong.jpg', '0xFF00A9CE', 3.0357000000000003, 101.6158),
  ('Sri Petaling Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 17, 'midRange', 'assets/attractions/area_sri_petaling.jpg', '0xFFFF7A59', 3.0685, 101.6977),
  ('Sri Petaling Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 20, 'midRange', 'assets/attractions/area_sri_petaling.jpg', '0xFF40A9FF', 3.0697, 101.6965),
  ('Sri Petaling Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 23, 'budget', 'assets/attractions/area_sri_petaling.jpg', '0xFFFFCE3D', 3.0709, 101.6953),
  ('Sri Petaling Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 26, 'budget', 'assets/attractions/area_sri_petaling.jpg', '0xFF7C5CFF', 3.0721, 101.69409999999999),
  ('Sri Petaling Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 29, 'budget', 'assets/attractions/area_sri_petaling.jpg', '0xFF3CCB7F', 3.0732999999999997, 101.6929),
  ('Sri Petaling Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 32, 'luxury', 'assets/attractions/area_sri_petaling.jpg', '0xFF00A9CE', 3.0745, 101.6917),
  ('Kepong Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 22, 'midRange', 'assets/attractions/area_kepong.jpg', '0xFFFF7A59', 3.211, 101.6386),
  ('Kepong Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 25, 'midRange', 'assets/attractions/area_kepong.jpg', '0xFF40A9FF', 3.2122, 101.6374),
  ('Kepong Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 28, 'budget', 'assets/attractions/area_kepong.jpg', '0xFFFFCE3D', 3.2134, 101.6362),
  ('Kepong Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 31, 'budget', 'assets/attractions/area_kepong.jpg', '0xFF7C5CFF', 3.2146, 101.63499999999999),
  ('Kepong Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 34, 'budget', 'assets/attractions/area_kepong.jpg', '0xFF3CCB7F', 3.2157999999999998, 101.6338),
  ('Kepong Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 37, 'luxury', 'assets/attractions/area_kepong.jpg', '0xFF00A9CE', 3.217, 101.6326),
  ('Batu Caves Food Discovery', '10:00 - 22:00', 600, 1320, 35, 60, 27, 'midRange', 'assets/attractions/area_batu_caves.jpg', '0xFFFF7A59', 3.2348999999999997, 101.687),
  ('Batu Caves Cafe Corner', '09:00 - 21:00', 540, 1260, 28, 55, 30, 'midRange', 'assets/attractions/area_batu_caves.jpg', '0xFF40A9FF', 3.2361, 101.6858),
  ('Batu Caves Night Market', '17:00 - 00:00', 1020, 1440, 22, 70, 33, 'budget', 'assets/attractions/area_batu_caves.jpg', '0xFFFFCE3D', 3.2373, 101.6846),
  ('Batu Caves Heritage Walk', '09:00 - 19:00', 540, 1140, 12, 65, 36, 'budget', 'assets/attractions/area_batu_caves.jpg', '0xFF7C5CFF', 3.2384999999999997, 101.68339999999999),
  ('Batu Caves Green Escape', '06:00 - 20:00', 360, 1200, 0, 60, 39, 'budget', 'assets/attractions/area_batu_caves.jpg', '0xFF3CCB7F', 3.2396999999999996, 101.6822),
  ('Batu Caves Family Stop', '10:00 - 20:00', 600, 1200, 65, 80, 4, 'luxury', 'assets/attractions/area_batu_caves.jpg', '0xFF00A9CE', 3.2409, 101.681);
