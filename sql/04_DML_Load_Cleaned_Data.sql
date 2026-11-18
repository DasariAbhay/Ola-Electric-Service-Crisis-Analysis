-- Requires cleaned sources and the star schema; run in one connection.
BEGIN;
DO $check$
BEGIN
    IF current_database() <> 'new_ola_analytics' THEN
        RAISE EXCEPTION 'Connect to new_ola_analytics';
    END IF;
END $check$;
SET search_path TO ola_star, public;
SET TIME ZONE 'Asia/Kolkata';
COMMIT;

-- TABLE: public.dict_city_lookup
BEGIN;

INSERT INTO public.dict_city_lookup (raw_name, clean_name) VALUES
    ('bangalore', 'Bengaluru'), ('bombay', 'Mumbai'), ('calcutta', 'Kolkata'),
    ('madras', 'Chennai'), ('gurgaon', 'Gurugram'), ('poona', 'Pune'),
    ('trivandrum', 'Thiruvananthapuram'), ('pondicherry', 'Puducherry'),
    ('benares', 'Varanasi'), ('cochin', 'Kochi'), ('kovai', 'Coimbatore'),
    ('vizag', 'Visakhapatnam'), ('trichy', 'Tiruchirappalli'),
    ('hubli', 'Hubballi'), ('mysore', 'Mysuru')
ON CONFLICT (raw_name) DO UPDATE SET clean_name = EXCLUDED.clean_name;
INSERT INTO public.dict_city_lookup (raw_name, clean_name)
VALUES
    ('bhubaneswa', 'Bhubaneswar'),
    ('tiruchirap', 'Tiruchirappalli'),
    ('visakhapat', 'Visakhapatnam')
ON CONFLICT (raw_name)
DO UPDATE SET clean_name = EXCLUDED.clean_name;

DO $keys$
BEGIN
    IF EXISTS (
        SELECT 1 FROM ola_star.fact_sales f
        WHERE f.city IS DISTINCT FROM COALESCE(
            (SELECT d.clean_name FROM public.dict_city_lookup d
                WHERE d.raw_name = LOWER(BTRIM(f.city))), INITCAP(NULLIF(BTRIM(f.city), '')))
    ) OR EXISTS (
        SELECT 1 FROM ola_star.fact_vahan_registrations f
        WHERE f.rto_city IS DISTINCT FROM COALESCE(
            (SELECT d.clean_name FROM public.dict_city_lookup d
                WHERE d.raw_name = LOWER(BTRIM(f.rto_city))), INITCAP(NULLIF(BTRIM(f.rto_city),
                    '')))
            OR f.oem IS DISTINCT FROM UPPER(BTRIM(f.oem))
    ) THEN
        RAISE EXCEPTION
            'Existing sales/VAHAN keys need migration; stop before normalizing source cities or reloading';
    END IF;
END $keys$;

-- TABLE: public.raw_ola_sales_daily_2023
UPDATE public.raw_ola_sales_daily_2023 s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')))
WHERE s.city IS DISTINCT FROM COALESCE((SELECT clean_name FROM public.dict_city_lookup d WHERE
    d.raw_name = LOWER(BTRIM(s.city))), INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_ola_sales_daily_2024
UPDATE public.raw_ola_sales_daily_2024 s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')))
WHERE s.city IS DISTINCT FROM COALESCE((SELECT clean_name FROM public.dict_city_lookup d WHERE
    d.raw_name = LOWER(BTRIM(s.city))), INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_archived_sales_legacy
UPDATE public.raw_archived_sales_legacy s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')))
WHERE s.city IS DISTINCT FROM COALESCE((SELECT clean_name FROM public.dict_city_lookup d WHERE
    d.raw_name = LOWER(BTRIM(s.city))), INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_service_complaints_2023
UPDATE public.raw_service_complaints_2023 s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')))
WHERE s.city IS DISTINCT FROM COALESCE((SELECT clean_name FROM public.dict_city_lookup d WHERE
    d.raw_name = LOWER(BTRIM(s.city))), INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_service_complaints_2024
UPDATE public.raw_service_complaints_2024 s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')))
WHERE s.city IS DISTINCT FROM COALESCE((SELECT clean_name FROM public.dict_city_lookup d WHERE
    d.raw_name = LOWER(BTRIM(s.city))), INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_service_centers_master
UPDATE public.raw_service_centers_master s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')))
WHERE s.city IS DISTINCT FROM COALESCE((SELECT clean_name FROM public.dict_city_lookup d WHERE
    d.raw_name = LOWER(BTRIM(s.city))), INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_vahan_competitor_registrations
UPDATE public.raw_vahan_competitor_registrations s SET rto_city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.rto_city))),
    INITCAP(NULLIF(BTRIM(s.rto_city), '')))
WHERE s.rto_city IS DISTINCT FROM COALESCE((SELECT clean_name FROM public.dict_city_lookup d WHERE
    d.raw_name = LOWER(BTRIM(s.rto_city))), INITCAP(NULLIF(BTRIM(s.rto_city), '')));

COMMIT;

-- TABLE: _src_complaints
BEGIN;

DROP TABLE IF EXISTS pg_temp._src_complaints;

CREATE TEMP TABLE _src_complaints ON COMMIT PRESERVE ROWS AS
SELECT ticket_id, customer_id, vehicle_reg_no, city, complaint_date, resolution_date,
        channel, complaint_text, component_tag, component_extracted, severity, status,
        csat_score, assigned_center_id, NULL::DATE AS complaint_date_inferred
FROM public.raw_service_complaints_2023
UNION ALL
SELECT ticket_id, customer_id, vehicle_reg_no, city, complaint_date, resolution_date,
        channel, complaint_text, component_tag, component_extracted, severity, status,
        csat_score, assigned_center_id, complaint_date_inferred
FROM public.raw_service_complaints_2024;

COMMIT;

-- TABLE: _src_sales
BEGIN;

DROP TABLE IF EXISTS pg_temp._src_sales;

-- New-system sales take precedence over overlapping legacy rows.
CREATE TEMP TABLE _src_sales ON COMMIT PRESERVE ROWS AS
SELECT sale_date, city, model, units_sold,
        units_sold * avg_selling_price_inr AS revenue, 'New_2024'::TEXT AS source_system,
        state, dealer_type, booking_channel, avg_selling_price_inr
FROM public.raw_ola_sales_daily_2024
UNION ALL
SELECT sale_date, city, model, units_sold, units_sold * avg_selling_price_inr,
        'New_2023', state, dealer_type, booking_channel, avg_selling_price_inr
FROM public.raw_ola_sales_daily_2023
UNION ALL
SELECT l.sale_date, l.city, l.model, l.units_sold, l.revenue, 'Legacy_2023',
        NULL::VARCHAR, NULL::VARCHAR, NULL::VARCHAR, NULL::NUMERIC
FROM public.raw_archived_sales_legacy l
WHERE NOT EXISTS (
    SELECT 1 FROM public.raw_ola_sales_daily_2023 n
    WHERE n.sale_date = l.sale_date AND n.city = l.city AND n.model = l.model
);

COMMIT;

-- Reject duplicate source keys and ambiguous vehicle identifiers.
BEGIN;

DO $guard$
BEGIN
    IF EXISTS (SELECT 1 FROM fact_vahan_registrations WHERE oem <> UPPER(BTRIM(oem))) THEN
        RAISE EXCEPTION
            'Existing VAHAN OEM keys are noncanonical: migrate these keys in a separate transaction before running this script';
    END IF;
END $guard$;
DO $check$
BEGIN
    IF EXISTS (SELECT 1 FROM _src_sales GROUP BY sale_date, city, model HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION
            'Sales grain is not unique: sale_date, city, model; investigate before loading';
    END IF;
    IF EXISTS (SELECT 1 FROM _src_complaints GROUP BY ticket_id HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION 'Duplicate cleaned ticket IDs; stop and review cleanup before loading';
    END IF;
    IF EXISTS (SELECT 1 FROM public.master_id_map WHERE vehicle_reg_no IS NOT NULL
                GROUP BY vehicle_reg_no HAVING COUNT(DISTINCT chassis_no) > 1) THEN
        RAISE EXCEPTION 'A registration maps to several chassis; resolve identity before loading';
    END IF;
    IF EXISTS (SELECT 1 FROM public.master_id_map
                WHERE COALESCE(customer_id, vehicle_reg_no, chassis_no, mobile_hash) IS NULL) THEN
        RAISE EXCEPTION 'Identifier map contains an entirely unidentified row';
    END IF;
    IF EXISTS (SELECT 1 FROM public.raw_spare_parts_consumption GROUP BY part_code
                HAVING COUNT(DISTINCT part_name) > 1 OR COUNT(part_name) < COUNT(*)) THEN
        RAISE EXCEPTION 'Part codes have missing or conflicting names';
    END IF;
END $check$;

DO $map$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.master_id_map) THEN
        RAISE EXCEPTION 'master_id_map is empty; do not load vehicle-dependent facts';
    END IF;
    IF EXISTS (
        SELECT 1 FROM public.master_id_map
        GROUP BY customer_id, vehicle_reg_no, chassis_no, mobile_hash
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'Duplicate map associations; review repeated map INSERTs before loading';
    END IF;
END $map$;

COMMIT;

-- TABLE: _identity_map
BEGIN;

DROP TABLE IF EXISTS pg_temp._identity_map;

-- Reuse map associations; choose chassis before other identifiers.
CREATE TEMP TABLE _identity_map ON COMMIT PRESERVE ROWS AS
WITH registration_bridge AS (
    SELECT vehicle_reg_no, MIN(chassis_no) AS chassis_no
    FROM public.master_id_map WHERE vehicle_reg_no IS NOT NULL
    GROUP BY vehicle_reg_no
), enriched AS (
    SELECT m.*, COALESCE(m.chassis_no, b.chassis_no) AS canonical_chassis
    FROM public.master_id_map m
    LEFT JOIN registration_bridge b ON b.vehicle_reg_no = m.vehicle_reg_no
)
SELECT *, CASE WHEN canonical_chassis IS NOT NULL THEN 'CHASSIS'
                WHEN vehicle_reg_no IS NOT NULL THEN 'REGISTRATION'
                WHEN customer_id IS NOT NULL THEN 'CUSTOMER_ONLY'
                ELSE 'MOBILE_ONLY' END AS identity_type,
            COALESCE(canonical_chassis, vehicle_reg_no, customer_id, mobile_hash) AS identity_value
FROM enriched;

COMMIT;

-- TABLE: dim_city
BEGIN;

INSERT INTO dim_city (city_name)
SELECT city FROM (
    SELECT city FROM public.raw_ola_sales_daily_2023
    UNION SELECT city FROM public.raw_ola_sales_daily_2024
    UNION SELECT city FROM public.raw_archived_sales_legacy
    UNION SELECT city FROM public.raw_service_complaints_2023
    UNION SELECT city FROM public.raw_service_complaints_2024
    UNION SELECT city FROM public.raw_service_centers_master
    UNION SELECT rto_city FROM public.raw_vahan_competitor_registrations
) all_cities WHERE city IS NOT NULL
ON CONFLICT (city_name) DO NOTHING;

COMMIT;

-- TABLE: dim_date
BEGIN;

INSERT INTO dim_date (date_key, year, month, month_name, quarter, day_of_week)
WITH source_dates AS (
    SELECT DATE '2023-01-01' AS d UNION ALL SELECT DATE '2024-12-31'
    UNION ALL SELECT sale_date FROM _src_sales
    UNION ALL SELECT complaint_date FROM _src_complaints
    UNION ALL SELECT resolution_date FROM _src_complaints
    UNION ALL SELECT complaint_date_inferred FROM _src_complaints
    UNION ALL SELECT opened_date FROM public.raw_service_centers_master
    UNION ALL SELECT open_date FROM public.raw_job_cards_2024
    UNION ALL SELECT close_date FROM public.raw_job_cards_2024
    UNION ALL SELECT claim_date FROM public.raw_warranty_claims
    UNION ALL SELECT week_start FROM public.raw_spare_parts_consumption
    UNION ALL SELECT reg_date FROM public.raw_vahan_competitor_registrations
    UNION ALL SELECT review_date FROM public.raw_app_store_reviews
    UNION ALL SELECT post_timestamp_ist::DATE FROM public.raw_social_media_posts
    UNION ALL SELECT filed_date FROM public.raw_nch_ccpa_complaints
    UNION ALL SELECT incident_date FROM public.raw_competitor_incidents
), bounds AS (SELECT MIN(d) AS first_date, MAX(d) AS last_date FROM source_dates),
calendar AS (SELECT first_date + n AS datum FROM bounds,
                LATERAL generate_series(0, last_date - first_date) AS g(n))
SELECT datum, EXTRACT(YEAR FROM datum)::INT, EXTRACT(MONTH FROM datum)::INT,
        TRIM(TO_CHAR(datum, 'Month')), EXTRACT(QUARTER FROM datum)::INT,
        TRIM(TO_CHAR(datum, 'Day')) FROM calendar
ON CONFLICT (date_key) DO UPDATE SET
    year = EXCLUDED.year, month = EXCLUDED.month, month_name = EXCLUDED.month_name,
    quarter = EXCLUDED.quarter, day_of_week = EXCLUDED.day_of_week;

COMMIT;

-- TABLE: dim_oem
BEGIN;

INSERT INTO dim_oem (oem_name)
SELECT UPPER(BTRIM(oem)) AS oem FROM public.raw_vahan_competitor_registrations WHERE oem IS NOT NULL
UNION SELECT UPPER(BTRIM(oem)) AS oem FROM public.raw_competitor_incidents WHERE oem IS NOT NULL
UNION SELECT 'OLA ELECTRIC'
ON CONFLICT (oem_name) DO NOTHING;

COMMIT;

-- TABLE: dim_part
BEGIN;

INSERT INTO dim_part (member_type, member_code, part_name, category)
SELECT 'PART', part_code, MIN(part_name), NULL::VARCHAR
FROM public.raw_spare_parts_consumption GROUP BY part_code
UNION ALL
SELECT 'COMPONENT', component, component, component FROM (
    SELECT component FROM public.raw_warranty_claims WHERE component IS NOT NULL
    UNION SELECT component_extracted FROM _src_complaints WHERE component_extracted IS NOT NULL
) components
ON CONFLICT (member_type, member_code) DO UPDATE SET
    part_name = EXCLUDED.part_name, category = EXCLUDED.category;

COMMIT;

-- TABLE: dim_service_center
BEGIN;

INSERT INTO dim_service_center (
    center_id, city, opened_date, type, center_name, capacity_jobs_per_day, technicians_count,
    source_record_missing
)
SELECT center_id, city, opened_date, center_type, center_name,
        capacity_jobs_per_day, technicians_count, FALSE
FROM public.raw_service_centers_master
ON CONFLICT (center_id) DO UPDATE SET
    city = EXCLUDED.city, opened_date = EXCLUDED.opened_date, type = EXCLUDED.type,
    center_name = EXCLUDED.center_name, capacity_jobs_per_day = EXCLUDED.capacity_jobs_per_day,
    technicians_count = EXCLUDED.technicians_count,
    source_record_missing = EXCLUDED.source_record_missing;

INSERT INTO dim_service_center (center_id, source_record_missing)
SELECT center_id, TRUE FROM (
    SELECT assigned_center_id AS center_id FROM _src_complaints
    UNION SELECT center_id FROM public.raw_job_cards_2024
    UNION SELECT dealer_center_id FROM public.raw_warranty_claims
    UNION SELECT center_id FROM public.raw_spare_parts_consumption
) referenced_centers WHERE center_id IS NOT NULL
ON CONFLICT (center_id) DO NOTHING;

COMMIT;

-- TABLE: dim_vehicle_customer
BEGIN;

INSERT INTO dim_vehicle_customer (
    identity_type, identity_value, customer_id, vehicle_reg_no, chassis_no, mobile_hash,
    multiple_customers_flag
)
SELECT identity_type, identity_value,
        CASE WHEN COUNT(DISTINCT customer_id) = 1 THEN MIN(customer_id) END,
        CASE WHEN COUNT(DISTINCT vehicle_reg_no) = 1 THEN MIN(vehicle_reg_no) END,
        CASE WHEN COUNT(DISTINCT canonical_chassis) = 1 THEN MIN(canonical_chassis) END,
        CASE WHEN COUNT(DISTINCT mobile_hash) = 1 THEN MIN(mobile_hash) END,
        COUNT(DISTINCT customer_id) > 1
FROM _identity_map GROUP BY identity_type, identity_value
ON CONFLICT (identity_type, identity_value) DO UPDATE SET
    customer_id = EXCLUDED.customer_id, vehicle_reg_no = EXCLUDED.vehicle_reg_no,
    chassis_no = EXCLUDED.chassis_no, mobile_hash = EXCLUDED.mobile_hash,
    multiple_customers_flag = EXCLUDED.multiple_customers_flag;

COMMIT;

-- TABLE: _map_keys
BEGIN;

DROP TABLE IF EXISTS pg_temp._map_keys;

CREATE TEMP TABLE _map_keys ON COMMIT PRESERVE ROWS AS
SELECT m.*, v.vehicle_customer_key FROM _identity_map m
JOIN dim_vehicle_customer v USING (identity_type, identity_value);

-- TABLE: _reg_keys
DROP TABLE IF EXISTS pg_temp._reg_keys;

CREATE TEMP TABLE _reg_keys ON COMMIT PRESERVE ROWS AS
SELECT vehicle_reg_no, MIN(vehicle_customer_key) AS vehicle_customer_key
FROM _map_keys WHERE vehicle_reg_no IS NOT NULL GROUP BY vehicle_reg_no
HAVING COUNT(DISTINCT vehicle_customer_key) = 1;

-- TABLE: _chassis_keys
DROP TABLE IF EXISTS pg_temp._chassis_keys;

CREATE TEMP TABLE _chassis_keys ON COMMIT PRESERVE ROWS AS
SELECT canonical_chassis AS chassis_no, MIN(vehicle_customer_key) AS vehicle_customer_key
FROM _map_keys WHERE canonical_chassis IS NOT NULL GROUP BY canonical_chassis
HAVING COUNT(DISTINCT vehicle_customer_key) = 1;

-- TABLE: _mobile_keys
DROP TABLE IF EXISTS pg_temp._mobile_keys;

CREATE TEMP TABLE _mobile_keys ON COMMIT PRESERVE ROWS AS
SELECT mobile_hash, MIN(vehicle_customer_key) AS vehicle_customer_key
FROM _map_keys WHERE mobile_hash IS NOT NULL GROUP BY mobile_hash
HAVING COUNT(DISTINCT vehicle_customer_key) = 1;

CREATE UNIQUE INDEX ON _reg_keys (vehicle_reg_no);

CREATE UNIQUE INDEX ON _chassis_keys (chassis_no);

CREATE UNIQUE INDEX ON _mobile_keys (mobile_hash);

COMMIT;

-- TABLE: fact_sales
BEGIN;

INSERT INTO fact_sales (
    sale_date, city, model, units_sold, revenue, source_system, oem, state, dealer_type,
    booking_channel, avg_selling_price_inr
)
SELECT sale_date, city, model, units_sold, revenue, source_system, 'OLA ELECTRIC',
        state, dealer_type, booking_channel, avg_selling_price_inr FROM _src_sales
ON CONFLICT (sale_date, city, model) DO UPDATE SET
    units_sold = EXCLUDED.units_sold, revenue = EXCLUDED.revenue,
    source_system = EXCLUDED.source_system, oem = EXCLUDED.oem, state = EXCLUDED.state,
    dealer_type = EXCLUDED.dealer_type, booking_channel = EXCLUDED.booking_channel,
    avg_selling_price_inr = EXCLUDED.avg_selling_price_inr;

COMMIT;

-- TABLE: fact_complaints
BEGIN;

INSERT INTO fact_complaints (
    ticket_id, complaint_date, complaint_date_inferred, resolution_date, customer_id,
        vehicle_reg_no,
    vehicle_customer_key, city, part_key, oem, status, severity, channel, complaint_text,
        component_tag,
    tat_days, csat_score, assigned_center_id, component_extracted
)
SELECT c.ticket_id, c.complaint_date, c.complaint_date_inferred, c.resolution_date,
        c.customer_id, c.vehicle_reg_no, COALESCE(r.vehicle_customer_key, u.vehicle_customer_key),
        c.city, p.part_key, 'OLA ELECTRIC', c.status, c.severity, c.channel,
        c.complaint_text, c.component_tag, c.resolution_date - c.complaint_date,
        c.csat_score, c.assigned_center_id, c.component_extracted
FROM _src_complaints c
LEFT JOIN _reg_keys r ON r.vehicle_reg_no = c.vehicle_reg_no
LEFT JOIN dim_vehicle_customer u ON c.vehicle_reg_no IS NULL
        AND u.identity_type = 'CUSTOMER_ONLY' AND u.identity_value = c.customer_id
LEFT JOIN dim_part p ON p.member_type = 'COMPONENT' AND p.member_code = c.component_extracted
ON CONFLICT (ticket_id) DO UPDATE SET
    complaint_date = EXCLUDED.complaint_date,
    complaint_date_inferred = EXCLUDED.complaint_date_inferred,
    resolution_date = EXCLUDED.resolution_date, customer_id = EXCLUDED.customer_id,
    vehicle_reg_no = EXCLUDED.vehicle_reg_no, vehicle_customer_key = EXCLUDED.vehicle_customer_key,
    city = EXCLUDED.city, part_key = EXCLUDED.part_key, oem = EXCLUDED.oem, status =
        EXCLUDED.status,
    severity = EXCLUDED.severity, channel = EXCLUDED.channel, complaint_text =
        EXCLUDED.complaint_text,
    component_tag = EXCLUDED.component_tag, tat_days = EXCLUDED.tat_days,
    csat_score = EXCLUDED.csat_score, assigned_center_id = EXCLUDED.assigned_center_id,
    component_extracted = EXCLUDED.component_extracted;

COMMIT;

-- TABLE: fact_jobcards
BEGIN;

INSERT INTO fact_jobcards (
    jobcard_id, chassis_no, mobile_hash, vehicle_customer_key, center_id, city, oem, open_date,
    close_date, technician_id, issue_category, parts_replaced, parts_cost_inr, labour_cost_inr,
        status,
    linked_ticket_id, linked_ticket_key
)
SELECT j.jobcard_id, j.chassis_no, j.mobile_hash,
        COALESCE(k.vehicle_customer_key, m.vehicle_customer_key), j.center_id, sc.city,
            'OLA ELECTRIC',
        j.open_date, j.close_date, j.technician_id, j.issue_category, j.parts_replaced,
        j.parts_cost_inr, j.labour_cost_inr, j.status, j.linked_ticket_id, c.ticket_id
FROM public.raw_job_cards_2024 j
LEFT JOIN _chassis_keys k ON k.chassis_no = j.chassis_no
LEFT JOIN _mobile_keys m ON j.chassis_no IS NULL AND m.mobile_hash = j.mobile_hash
LEFT JOIN dim_service_center sc ON sc.center_id = j.center_id
LEFT JOIN fact_complaints c ON c.ticket_id = j.linked_ticket_id
ON CONFLICT (jobcard_id) DO UPDATE SET
    chassis_no = EXCLUDED.chassis_no, mobile_hash = EXCLUDED.mobile_hash,
    vehicle_customer_key = EXCLUDED.vehicle_customer_key, center_id = EXCLUDED.center_id,
    city = EXCLUDED.city, oem = EXCLUDED.oem, open_date = EXCLUDED.open_date,
    close_date = EXCLUDED.close_date, technician_id = EXCLUDED.technician_id,
    issue_category = EXCLUDED.issue_category, parts_replaced = EXCLUDED.parts_replaced,
    parts_cost_inr = EXCLUDED.parts_cost_inr, labour_cost_inr = EXCLUDED.labour_cost_inr,
    status = EXCLUDED.status, linked_ticket_id = EXCLUDED.linked_ticket_id,
    linked_ticket_key = EXCLUDED.linked_ticket_key;

COMMIT;

-- TABLE: fact_warranty
BEGIN;

INSERT INTO fact_warranty (
    claim_id, claim_date, chassis_no, vehicle_reg_no, vehicle_customer_key, part_key, part_name,
    dealer_center_id, city, oem, claim_amount_inr, is_usd_converted, approved_flag, km_at_claim
)
SELECT w.claim_id, w.claim_date::DATE, w.chassis_no, w.vehicle_reg_no,
        COALESCE(k.vehicle_customer_key, r.vehicle_customer_key), p.part_key, w.component,
        w.dealer_center_id, sc.city, 'OLA ELECTRIC', w.claim_amount_inr::NUMERIC,
        w.is_usd_converted, w.approved_flag, w.km_at_claim
FROM public.raw_warranty_claims w
LEFT JOIN _chassis_keys k ON k.chassis_no = w.chassis_no
LEFT JOIN _reg_keys r ON w.chassis_no IS NULL AND r.vehicle_reg_no = w.vehicle_reg_no
LEFT JOIN dim_part p ON p.member_type = 'COMPONENT' AND p.member_code = w.component
LEFT JOIN dim_service_center sc ON sc.center_id = w.dealer_center_id
ON CONFLICT (claim_id) DO UPDATE SET
    claim_date = EXCLUDED.claim_date, chassis_no = EXCLUDED.chassis_no,
    vehicle_reg_no = EXCLUDED.vehicle_reg_no, vehicle_customer_key = EXCLUDED.vehicle_customer_key,
    part_key = EXCLUDED.part_key, part_name = EXCLUDED.part_name,
    dealer_center_id = EXCLUDED.dealer_center_id, city = EXCLUDED.city, oem = EXCLUDED.oem,
    claim_amount_inr = EXCLUDED.claim_amount_inr, is_usd_converted = EXCLUDED.is_usd_converted,
    approved_flag = EXCLUDED.approved_flag, km_at_claim = EXCLUDED.km_at_claim;

COMMIT;

-- TABLE: fact_vahan_registrations
BEGIN;

INSERT INTO fact_vahan_registrations (reg_date, rto_city, oem, vehicle_class, registrations)
SELECT reg_date, rto_city, UPPER(BTRIM(oem)), vehicle_class, registrations FROM
    public.raw_vahan_competitor_registrations
ON CONFLICT (reg_date, rto_city, oem, vehicle_class) DO UPDATE SET
    registrations = EXCLUDED.registrations;

COMMIT;

-- TABLE: fact_spare_parts
BEGIN;

INSERT INTO fact_spare_parts (
    week_start, center_id, city, part_code, part_key, part_name, consumption_qty, stockout_days,
    reorder_flag
)
SELECT s.week_start, s.center_id, c.city, s.part_code, p.part_key, s.part_name,
        s.qty_consumed, s.stockout_days, s.reorder_flag
FROM public.raw_spare_parts_consumption s
LEFT JOIN dim_service_center c ON c.center_id = s.center_id
LEFT JOIN dim_part p ON p.member_type = 'PART' AND p.member_code = s.part_code
ON CONFLICT (week_start, center_id, part_code) DO UPDATE SET
    city = EXCLUDED.city, part_key = EXCLUDED.part_key, part_name = EXCLUDED.part_name,
    consumption_qty = EXCLUDED.consumption_qty, stockout_days = EXCLUDED.stockout_days,
    reorder_flag = EXCLUDED.reorder_flag;

COMMIT;

-- TABLE: fact_sentiment
BEGIN;

-- Preserve undated social rows and label provisional sentiment rules.
INSERT INTO fact_sentiment (
    source, source_id, feedback_date, rating, sentiment_label, classification_method, platform,
    feedback_text, posted_epoch_raw, likes, shares, comments
)
SELECT 'App Store', review_id, review_date, rating,
        CASE WHEN rating >= 4 THEN 'Positive' WHEN rating <= 2 THEN 'Negative'
            WHEN rating = 3 THEN 'Neutral' END,
        'rating_rule', platform, review_text, NULL::BIGINT, NULL::INT, NULL::INT, NULL::INT
FROM public.raw_app_store_reviews
UNION ALL
SELECT 'Social Media', post_id, post_timestamp_ist::DATE, NULL::INT,
        CASE WHEN text IS NULL OR BTRIM(text) = '' THEN NULL
            WHEN text ~ *
                '(not good|not happy|not satisfied|bad|worst|poor|fail|broken|refund|delay|stranded|fire|smoke|unsafe|frustrat|disappoint|no response)'
                THEN 'Negative'
            WHEN text ~ * '(great|excellent|love|happy|satisfied|smooth|awesome|impress|thank)' THEN
                'Positive'
            ELSE 'Neutral' END,
        'keyword_v1_provisional_negative_first', platform, text, posted_epoch_raw, likes, shares,
            comments
FROM public.raw_social_media_posts
ON CONFLICT (source, source_id) DO UPDATE SET
    feedback_date = EXCLUDED.feedback_date, rating = EXCLUDED.rating,
    sentiment_label = EXCLUDED.sentiment_label, classification_method =
        EXCLUDED.classification_method,
    platform = EXCLUDED.platform, feedback_text = EXCLUDED.feedback_text,
    posted_epoch_raw = EXCLUDED.posted_epoch_raw, likes = EXCLUDED.likes, shares = EXCLUDED.shares,
    comments = EXCLUDED.comments;

COMMIT;

-- TABLE: fact_nch_complaints
BEGIN;

INSERT INTO fact_nch_complaints (
    nch_ref_id, filed_date, state, category, status, escalated_to_ccpa, resolution_days,
    compensation_inr
)
SELECT nch_ref_id, filed_date, state, category, status, escalated_to_ccpa,
        resolution_days, compensation_inr FROM public.raw_nch_ccpa_complaints
ON CONFLICT (nch_ref_id) DO UPDATE SET
    filed_date = EXCLUDED.filed_date, state = EXCLUDED.state, category = EXCLUDED.category,
    status = EXCLUDED.status, escalated_to_ccpa = EXCLUDED.escalated_to_ccpa,
    resolution_days = EXCLUDED.resolution_days, compensation_inr = EXCLUDED.compensation_inr;

COMMIT;

-- TABLE: fact_competitor_incidents
BEGIN;

INSERT INTO fact_competitor_incidents (
    incident_id, oem, incident_date, incident_type, units_affected, resolution_days, source
)
SELECT incident_id, UPPER(BTRIM(oem)), incident_date, incident_type, units_affected,
    resolution_days, source
FROM public.raw_competitor_incidents
ON CONFLICT (incident_id) DO UPDATE SET
    oem = EXCLUDED.oem, incident_date = EXCLUDED.incident_date, incident_type =
        EXCLUDED.incident_type,
    units_affected = EXCLUDED.units_affected, resolution_days = EXCLUDED.resolution_days,
    source = EXCLUDED.source;

COMMIT;

-- Reconcile loaded rows, units and known revenue against the sources.
WITH counts AS (
SELECT 'sales' AS source, (SELECT COUNT(*) FROM _src_sales) AS expected_rows,
        (SELECT COUNT(*) FROM fact_sales) AS loaded_rows
UNION ALL
SELECT 'complaints' AS source, (SELECT COUNT(*) FROM _src_complaints) AS expected_rows,
        (SELECT COUNT(*) FROM fact_complaints) AS loaded_rows
UNION ALL
SELECT 'jobcards' AS source, (SELECT COUNT(*) FROM public.raw_job_cards_2024) AS expected_rows,
        (SELECT COUNT(*) FROM fact_jobcards) AS loaded_rows
UNION ALL
SELECT 'warranty' AS source, (SELECT COUNT(*) FROM public.raw_warranty_claims) AS expected_rows,
        (SELECT COUNT(*) FROM fact_warranty) AS loaded_rows
UNION ALL
SELECT 'vahan' AS source, (SELECT COUNT(*) FROM public.raw_vahan_competitor_registrations) AS
    expected_rows,
        (SELECT COUNT(*) FROM fact_vahan_registrations) AS loaded_rows
UNION ALL
SELECT 'spares' AS source, (SELECT COUNT(*) FROM public.raw_spare_parts_consumption) AS
    expected_rows,
        (SELECT COUNT(*) FROM fact_spare_parts) AS loaded_rows
UNION ALL
SELECT 'nch' AS source, (SELECT COUNT(*) FROM public.raw_nch_ccpa_complaints) AS expected_rows,
        (SELECT COUNT(*) FROM fact_nch_complaints) AS loaded_rows
UNION ALL
SELECT 'incidents' AS source, (SELECT COUNT(*) FROM public.raw_competitor_incidents) AS
    expected_rows,
        (SELECT COUNT(*) FROM fact_competitor_incidents) AS loaded_rows
UNION ALL
SELECT 'sentiment', (SELECT COUNT(*) FROM public.raw_app_store_reviews) + (SELECT COUNT(*) FROM
    public.raw_social_media_posts), (SELECT COUNT(*) FROM fact_sentiment)
)
SELECT *, loaded_rows - expected_rows AS difference FROM counts ORDER BY source;
SELECT (SELECT SUM(units_sold) FROM _src_sales) AS expected_units,
        (SELECT SUM(units_sold) FROM fact_sales) AS loaded_units,
        (SELECT SUM(revenue) FROM _src_sales) AS expected_known_revenue,
        (SELECT SUM(revenue) FROM fact_sales) AS loaded_known_revenue,
        (SELECT COUNT(*) FROM _src_sales WHERE revenue IS NULL) AS expected_unknown_revenue_rows,
        (SELECT COUNT(*) FROM fact_sales WHERE revenue IS NULL) AS loaded_unknown_revenue_rows;

SELECT COUNT(*) AS noncanonical_core_oem_rows
FROM (
    SELECT oem FROM fact_sales UNION ALL SELECT oem FROM fact_complaints
    UNION ALL SELECT oem FROM fact_jobcards UNION ALL SELECT oem FROM fact_warranty
) f WHERE oem IS DISTINCT FROM 'OLA ELECTRIC';
