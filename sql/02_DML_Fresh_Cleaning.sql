-- Preview duplicate ticket groups before cleaning.
WITH tickets AS (
    SELECT '2023' AS source_year, ticket_id FROM public.raw_service_complaints_2023
    UNION ALL
    SELECT '2024', ticket_id FROM public.raw_service_complaints_2024
), groups AS (
    SELECT source_year, ticket_id, COUNT(*) AS rows_per_ticket
    FROM tickets
    WHERE NULLIF(BTRIM(ticket_id), '') IS NOT NULL
        AND LOWER(BTRIM(ticket_id)) NOT IN ('null', '[null]')
    GROUP BY source_year, ticket_id
)
SELECT source_year,
        COUNT(*) FILTER (WHERE rows_per_ticket > 1) AS duplicated_ticket_groups,
        SUM(rows_per_ticket - 1) AS proposed_duplicate_removals
FROM groups GROUP BY source_year ORDER BY source_year;

-- Run once on fresh replay imports; execute this transaction through COMMIT.
BEGIN;

SET LOCAL search_path TO public;

SET LOCAL TIME ZONE 'Asia/Kolkata';

-- Restrict cleaning to untouched imports in new_ola_analytics_replay.
DO $fresh$
BEGIN
    IF current_database() <> 'new_ola_analytics_replay' THEN
        RAISE EXCEPTION
            'Fresh cleaning is restricted to new_ola_analytics_replay; do not run on your current database';
    END IF;
    IF EXISTS (SELECT 1 FROM public.master_id_map) THEN
        RAISE EXCEPTION 'Expected an empty master_id_map; do not append repeated associations';
    END IF;
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name
        = 'raw_service_complaints_2024' AND column_name = 'complaint_date_raw') THEN
        RAISE EXCEPTION 'Already converted: use the cleaned-source load script instead';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND
        table_name = 'raw_archived_sales_legacy' AND column_name = 'rev_inr_lakh') THEN
        RAISE EXCEPTION 'Expected untouched legacy import columns';
    END IF;
END $fresh$;

CREATE SCHEMA raw_snapshot;

-- Preserve the original imported tables before cleaning.
DO $backup$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'raw\_%'
        ESCAPE '\' LOOP
        EXECUTE format('CREATE TABLE raw_snapshot.%I AS TABLE public.%I', r.tablename, r.tablename);
    END LOOP;
END $backup$;

-- Convert blank and textual NULL markers to SQL NULL.
DO $clean$
DECLARE
    r RECORD;
BEGIN
    FOR r IN SELECT table_name, column_name FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name LIKE 'raw\_%' ESCAPE '\'
    AND data_type IN ('text', 'character varying', 'character') LOOP
        EXECUTE
            format('UPDATE public.%I SET %I=NULL WHERE LOWER(BTRIM(%I)) IN ('''',''[null]'',''null'')',
            r.table_name, r.column_name, r.column_name);
    END LOOP;
END $clean$;

-- TABLE: public.dict_city_lookup
CREATE TABLE IF NOT EXISTS public.dict_city_lookup (
    raw_name VARCHAR(100) PRIMARY KEY,
    clean_name VARCHAR(100) NOT NULL
);

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

-- TABLE: raw_app_store_reviews
ALTER TABLE raw_app_store_reviews RENAME COLUMN rating_raw TO rating;

ALTER TABLE raw_app_store_reviews
    ALTER COLUMN review_date TYPE DATE USING TO_DATE(TRIM(review_date), 'YYYY-MM-DD'),
    ALTER COLUMN rating TYPE INT USING CASE WHEN LOWER(TRIM(rating)) ~ '^[1-5](\.0+)?( stars?)?$'
        THEN SUBSTRING(rating FROM '[0-9\.]+')::NUMERIC::INT ELSE NULL END,
    ALTER COLUMN reply_from_ola TYPE BOOLEAN USING TRIM(reply_from_ola)::BOOLEAN;

-- TABLE: raw_competitor_incidents
ALTER TABLE raw_competitor_incidents RENAME COLUMN date TO incident_date;

ALTER TABLE raw_competitor_incidents
    ALTER COLUMN incident_date TYPE DATE USING incident_date::TIMESTAMP::DATE;

-- TABLE: raw_social_media_posts
ALTER TABLE raw_social_media_posts RENAME COLUMN posted_epoch TO posted_epoch_raw;

ALTER TABLE raw_social_media_posts
    ADD COLUMN post_timestamp_ist TIMESTAMP,
    ALTER COLUMN is_verified TYPE BOOLEAN USING is_verified::BOOLEAN;

-- TABLE: raw_ola_sales_daily_2023
ALTER TABLE raw_ola_sales_daily_2023
    ALTER COLUMN sale_date TYPE DATE USING TO_DATE(TRIM(sale_date), 'DD-MM-YYYY');

-- TABLE: raw_ola_sales_daily_2024
ALTER TABLE raw_ola_sales_daily_2024
    ALTER COLUMN sale_date TYPE DATE USING TRIM(sale_date)::DATE;

-- TABLE: raw_vahan_competitor_registrations
ALTER TABLE raw_vahan_competitor_registrations
    ALTER COLUMN reg_date TYPE DATE USING TO_DATE(TRIM(reg_date), 'YYYY-MM-DD');

-- TABLE: raw_archived_sales_legacy
ALTER TABLE raw_archived_sales_legacy RENAME COLUMN txn_dt TO sale_date;

ALTER TABLE raw_archived_sales_legacy RENAME COLUMN cty TO city;

ALTER TABLE raw_archived_sales_legacy RENAME COLUMN mdl_cd TO model;

ALTER TABLE raw_archived_sales_legacy RENAME COLUMN qty TO units_sold;

ALTER TABLE raw_archived_sales_legacy RENAME COLUMN rev_inr_lakh TO revenue;

ALTER TABLE raw_archived_sales_legacy
    ALTER COLUMN sale_date TYPE DATE USING TO_DATE(TRIM(sale_date), 'DD/MM/YY'),
    ALTER COLUMN revenue TYPE NUMERIC USING revenue * 100000;

-- TABLE: raw_warranty_claims
ALTER TABLE raw_warranty_claims ADD COLUMN IF NOT EXISTS is_usd_converted BOOLEAN DEFAULT FALSE;

ALTER TABLE raw_warranty_claims ADD COLUMN claim_amount_inr NUMERIC(14, 2);

-- TABLE: raw_service_complaints_2023
ALTER TABLE raw_service_complaints_2023
    ALTER COLUMN complaint_date TYPE DATE USING TO_DATE(TRIM(complaint_date), 'DD-MM-YYYY'),
    ALTER COLUMN resolution_date TYPE DATE USING NULLIF(TRIM(resolution_date::TEXT),
        '[null]')::DATE,
    ALTER COLUMN csat_score TYPE NUMERIC USING NULLIF(TRIM(csat_score::TEXT), '[null]')::NUMERIC;

ALTER TABLE raw_service_complaints_2023 ADD COLUMN IF NOT EXISTS component_extracted VARCHAR(50);

-- TABLE: raw_service_complaints_2024
ALTER TABLE raw_service_complaints_2024 RENAME COLUMN complaint_date TO complaint_date_raw;

ALTER TABLE raw_service_complaints_2024 RENAME COLUMN resolution_date TO resolution_date_raw;

ALTER TABLE raw_service_complaints_2024
    ADD COLUMN complaint_date DATE,
    ADD COLUMN resolution_date DATE,
    ALTER COLUMN csat_score TYPE NUMERIC USING NULLIF(TRIM(csat_score::TEXT), '[null]')::NUMERIC;

ALTER TABLE raw_service_complaints_2024 ADD COLUMN IF NOT EXISTS component_extracted VARCHAR(50);

-- TABLE: raw_job_cards_2024
ALTER TABLE raw_job_cards_2024
    ALTER COLUMN open_date TYPE DATE USING open_date::DATE,
    ALTER COLUMN close_date TYPE DATE USING NULLIF(TRIM(close_date), '[null]')::DATE,
    ALTER COLUMN parts_cost_inr TYPE NUMERIC USING parts_cost_inr::NUMERIC,
    ALTER COLUMN labour_cost_inr TYPE NUMERIC USING labour_cost_inr::NUMERIC;

-- TABLE: public.raw_service_centers_master
ALTER TABLE public.raw_service_centers_master
    ALTER COLUMN opened_date TYPE DATE
    USING NULLIF(NULLIF(TRIM(opened_date), ''), '[null]')::DATE;

-- TABLE: public.raw_spare_parts_consumption
ALTER TABLE public.raw_spare_parts_consumption
    ALTER COLUMN week_start TYPE DATE
    USING NULLIF(NULLIF(TRIM(week_start), ''), '[null]')::DATE;

-- TABLE: public.raw_warranty_claims
ALTER TABLE public.raw_warranty_claims
    ALTER COLUMN claim_date TYPE DATE
    USING NULLIF(NULLIF(TRIM(claim_date), ''), '[null]')::DATE;

-- TABLE: public.raw_nch_ccpa_complaints
ALTER TABLE public.raw_nch_ccpa_complaints
    ALTER COLUMN filed_date TYPE DATE
    USING NULLIF(NULLIF(TRIM(filed_date), ''), '[null]')::DATE;

ALTER TABLE public.raw_nch_ccpa_complaints
    ALTER COLUMN resolution_days TYPE INTEGER
    USING (
    CASE
        WHEN LOWER(TRIM(resolution_days)) IN ('', '[null]', 'null')
            THEN NULL
        ELSE TRIM(resolution_days)::NUMERIC::INTEGER
    END
);

-- TABLE: public.raw_spare_parts_consumption
ALTER TABLE public.raw_spare_parts_consumption
    ALTER COLUMN reorder_flag TYPE BOOLEAN
    USING TRIM(reorder_flag)::BOOLEAN;

-- TABLE: public.raw_nch_ccpa_complaints
ALTER TABLE public.raw_nch_ccpa_complaints
    ALTER COLUMN escalated_to_ccpa TYPE BOOLEAN
    USING TRIM(escalated_to_ccpa)::BOOLEAN;

-- TABLE: public.raw_service_complaints_2024
ALTER TABLE public.raw_service_complaints_2024
    ADD COLUMN IF NOT EXISTS complaint_date_inferred DATE;

-- TABLE: raw_service_complaints_2023
UPDATE raw_service_complaints_2023 SET
    vehicle_reg_no = NULLIF(TRIM(vehicle_reg_no), '[null]'),
    component_tag = NULLIF(TRIM(component_tag), '[null]'),
    severity = NULLIF(TRIM(severity), '[null]');

UPDATE raw_service_complaints_2023 SET tat_days = (resolution_date - complaint_date);

UPDATE raw_service_complaints_2023
SET component_extracted = CASE
    WHEN complaint_text ILIKE '%fork%' OR complaint_text ILIKE '%brake%' OR complaint_text ILIKE
        '%suspension%' OR complaint_text ILIKE '%handle vibrat%' THEN 'Brakes/Suspension'
    WHEN complaint_text ILIKE '%refund%' OR complaint_text ILIKE '%invoice%' OR complaint_text ILIKE
        '%charged twice%' OR complaint_text ILIKE '%booking amount%' THEN 'Refund/Billing'
    WHEN complaint_text ILIKE '%service center%' OR complaint_text ILIKE '%service centre%' OR
        complaint_text ILIKE '%pickup%' OR complaint_text ILIKE '%job card%' OR complaint_text ILIKE
        '%no response%' OR complaint_text ILIKE '%spare part%' OR complaint_text ILIKE '%slot%' THEN
        'Service Delay'
    WHEN complaint_text ILIKE '%charger%' OR complaint_text ILIKE '%charging%' OR complaint_text
        ILIKE '%hypercharger%' OR complaint_text ILIKE '%plug%' THEN 'Charger/Charging'
    WHEN complaint_text ILIKE '%range%' OR complaint_text ILIKE '%battery%' OR complaint_text ILIKE
        '%bms%' OR complaint_text ILIKE '%drain%' OR complaint_text ILIKE '%charge shows%' THEN
        'Battery/Range'
    WHEN complaint_text ILIKE '%motor%' OR complaint_text ILIKE '%grinding%' OR complaint_text ILIKE
        '%power cut%' OR complaint_text ILIKE '%belt%' OR complaint_text ILIKE '%jerk%' OR
        complaint_text ILIKE '%incline%' THEN 'Motor/Drivetrain'
    WHEN complaint_text ILIKE '%screen%' OR complaint_text ILIKE '%display%' OR complaint_text ILIKE
        '%ota%' OR complaint_text ILIKE '%moveos%' OR complaint_text ILIKE '%speedometer%' OR
        complaint_text ILIKE '%cruise%' OR complaint_text ILIKE '%reverse mode%' OR complaint_text
        ILIKE '%navigation%' THEN 'Software/Display'
    WHEN complaint_text ILIKE '%app%' OR complaint_text ILIKE '%bluetooth%' OR complaint_text ILIKE
        '%sync%' OR complaint_text ILIKE '%remote lock%' OR complaint_text ILIKE '%key sharing%'
        THEN 'App/Connectivity'
    ELSE 'Unclassified' END;

-- TABLE: raw_social_media_posts
UPDATE raw_social_media_posts
SET post_timestamp_ist = CASE
    WHEN posted_epoch_raw::TEXT ~ '^[0-9]{10}$'
        THEN to_timestamp(posted_epoch_raw::DOUBLE PRECISION) AT TIME ZONE 'Asia/Kolkata'
    WHEN posted_epoch_raw::TEXT ~ '^[0-9]{13}$'
        THEN to_timestamp(posted_epoch_raw::DOUBLE PRECISION / 1000) AT TIME ZONE 'Asia/Kolkata'
    ELSE NULL END;

UPDATE raw_social_media_posts SET location_tag = NULLIF(TRIM(location_tag), '[null]');

-- TABLE: raw_archived_sales_legacy
UPDATE raw_archived_sales_legacy
SET model = CASE
    WHEN model = 'SP' THEN 'S1 Pro'
    WHEN model = 'SA' THEN 'S1 Air'
    WHEN model = 'SX' THEN 'S1 X'
    WHEN model = 'SXP' THEN 'S1 X+'
    WHEN model = 'SG' THEN 'S1 Gig'
    ELSE model
END;

-- TABLE: raw_warranty_claims
-- Convert USD claims at the project assumption of INR 84 per USD.
UPDATE raw_warranty_claims
SET claim_amount_inr = CASE UPPER(TRIM(currency))
        WHEN 'USD' THEN claim_amount * 84
        WHEN 'INR' THEN claim_amount
        ELSE NULL END,
    is_usd_converted = COALESCE(UPPER(TRIM(currency)) = 'USD', FALSE);

-- TABLE: raw_service_complaints_2024
UPDATE raw_service_complaints_2024 SET
    vehicle_reg_no = NULLIF(TRIM(vehicle_reg_no), '[null]'),
    component_tag = NULLIF(TRIM(component_tag), '[null]'),
    severity = NULLIF(TRIM(severity), '[null]');

UPDATE raw_service_complaints_2024
SET complaint_date = CASE
        WHEN TRIM(complaint_date_raw) IN ('', '[null]') THEN NULL
        WHEN TRIM(complaint_date_raw) ~ '^[0-9]{10}$'
            THEN (to_timestamp(TRIM(complaint_date_raw)::DOUBLE PRECISION)
                AT TIME ZONE 'Asia/Kolkata')::DATE
        WHEN TRIM(complaint_date_raw) ~ '^[0-9]{13}$'
            THEN (to_timestamp(TRIM(complaint_date_raw)::DOUBLE PRECISION / 1000)
                AT TIME ZONE 'Asia/Kolkata')::DATE
        WHEN TRIM(complaint_date_raw) ~ '^[0-9]+$' THEN NULL
        WHEN TRIM(complaint_date_raw) ~ '(Z|[+-][0-9]{2}:[0-9]{2})$'
            THEN (TRIM(complaint_date_raw)::TIMESTAMPTZ AT TIME ZONE 'Asia/Kolkata')::DATE
        ELSE TRIM(complaint_date_raw)::TIMESTAMP::DATE END,
    resolution_date = CASE
        WHEN TRIM(resolution_date_raw) IN ('', '[null]') THEN NULL
        WHEN TRIM(resolution_date_raw) ~ '^[0-9]{10}$'
            THEN (to_timestamp(TRIM(resolution_date_raw)::DOUBLE PRECISION)
                AT TIME ZONE 'Asia/Kolkata')::DATE
        WHEN TRIM(resolution_date_raw) ~ '^[0-9]{13}$'
            THEN (to_timestamp(TRIM(resolution_date_raw)::DOUBLE PRECISION / 1000)
                AT TIME ZONE 'Asia/Kolkata')::DATE
        WHEN TRIM(resolution_date_raw) ~ '^[0-9]+$' THEN NULL
        WHEN TRIM(resolution_date_raw) ~ '(Z|[+-][0-9]{2}:[0-9]{2})$'
            THEN (TRIM(resolution_date_raw)::TIMESTAMPTZ AT TIME ZONE 'Asia/Kolkata')::DATE
        ELSE TRIM(resolution_date_raw)::TIMESTAMP::DATE END;

UPDATE raw_service_complaints_2024 SET tat_days = (resolution_date - complaint_date);

UPDATE raw_service_complaints_2024
SET component_extracted = CASE
    WHEN complaint_text ILIKE '%fork%' OR complaint_text ILIKE '%brake%' OR complaint_text ILIKE
        '%suspension%' OR complaint_text ILIKE '%handle vibrat%' THEN 'Brakes/Suspension'
    WHEN complaint_text ILIKE '%refund%' OR complaint_text ILIKE '%invoice%' OR complaint_text ILIKE
        '%charged twice%' OR complaint_text ILIKE '%booking amount%' THEN 'Refund/Billing'
    WHEN complaint_text ILIKE '%service center%' OR complaint_text ILIKE '%service centre%' OR
        complaint_text ILIKE '%pickup%' OR complaint_text ILIKE '%job card%' OR complaint_text ILIKE
        '%no response%' OR complaint_text ILIKE '%spare part%' OR complaint_text ILIKE '%slot%' THEN
        'Service Delay'
    WHEN complaint_text ILIKE '%charger%' OR complaint_text ILIKE '%charging%' OR complaint_text
        ILIKE '%hypercharger%' OR complaint_text ILIKE '%plug%' THEN 'Charger/Charging'
    WHEN complaint_text ILIKE '%range%' OR complaint_text ILIKE '%battery%' OR complaint_text ILIKE
        '%bms%' OR complaint_text ILIKE '%drain%' OR complaint_text ILIKE '%charge shows%' THEN
        'Battery/Range'
    WHEN complaint_text ILIKE '%motor%' OR complaint_text ILIKE '%grinding%' OR complaint_text ILIKE
        '%power cut%' OR complaint_text ILIKE '%belt%' OR complaint_text ILIKE '%jerk%' OR
        complaint_text ILIKE '%incline%' THEN 'Motor/Drivetrain'
    WHEN complaint_text ILIKE '%screen%' OR complaint_text ILIKE '%display%' OR complaint_text ILIKE
        '%ota%' OR complaint_text ILIKE '%moveos%' OR complaint_text ILIKE '%speedometer%' OR
        complaint_text ILIKE '%cruise%' OR complaint_text ILIKE '%reverse mode%' OR complaint_text
        ILIKE '%navigation%' THEN 'Software/Display'
    WHEN complaint_text ILIKE '%app%' OR complaint_text ILIKE '%bluetooth%' OR complaint_text ILIKE
        '%sync%' OR complaint_text ILIKE '%remote lock%' OR complaint_text ILIKE '%key sharing%'
        THEN 'App/Connectivity'
    ELSE 'Unclassified' END;

-- TABLE: raw_job_cards_2024
UPDATE raw_job_cards_2024
SET technician_id = 'UNASSIGNED'
WHERE technician_id IS NULL OR TRIM(technician_id) IN ('', '[null]');

-- TABLE: public.raw_service_complaints_2023
UPDATE public.raw_service_complaints_2023 SET customer_id = BTRIM(customer_id), vehicle_reg_no =
    UPPER(BTRIM(vehicle_reg_no));

-- TABLE: public.raw_service_complaints_2024
UPDATE public.raw_service_complaints_2024 SET customer_id = BTRIM(customer_id), vehicle_reg_no =
    UPPER(BTRIM(vehicle_reg_no));

-- TABLE: public.raw_warranty_claims
UPDATE public.raw_warranty_claims SET vehicle_reg_no = UPPER(BTRIM(vehicle_reg_no)), chassis_no =
    UPPER(BTRIM(chassis_no));

-- TABLE: public.raw_job_cards_2024
UPDATE public.raw_job_cards_2024 SET chassis_no = UPPER(BTRIM(chassis_no)), mobile_hash =
    BTRIM(mobile_hash);

-- TABLE: public.raw_service_complaints_2024
-- Sensitivity only: interpret seven digits as thousands of epoch seconds.
UPDATE public.raw_service_complaints_2024
SET complaint_date_inferred = (
    TO_TIMESTAMP(
        TRIM(complaint_date_raw)::DOUBLE PRECISION * 1000
    ) AT TIME ZONE 'Asia/Kolkata'
)::DATE
WHERE complaint_date IS NULL
    AND TRIM(complaint_date_raw) ~ '^[0-9]{7}$';

-- TABLE: public.raw_ola_sales_daily_2023
UPDATE public.raw_ola_sales_daily_2023 s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_ola_sales_daily_2024
UPDATE public.raw_ola_sales_daily_2024 s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_archived_sales_legacy
UPDATE public.raw_archived_sales_legacy s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_service_complaints_2023
UPDATE public.raw_service_complaints_2023 s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_service_complaints_2024
UPDATE public.raw_service_complaints_2024 s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_service_centers_master
UPDATE public.raw_service_centers_master s SET city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.city))),
    INITCAP(NULLIF(BTRIM(s.city), '')));

-- TABLE: public.raw_vahan_competitor_registrations
UPDATE public.raw_vahan_competitor_registrations s SET rto_city = COALESCE((SELECT clean_name FROM
    public.dict_city_lookup d WHERE d.raw_name = LOWER(BTRIM(s.rto_city))),
    INITCAP(NULLIF(BTRIM(s.rto_city), '')));

-- TABLE: master_id_map
-- Retain unmatched associations when joining normalized identifiers.
WITH complaint_pairs AS (
    SELECT
        NULLIF(TRIM(customer_id), '') AS customer_id,
        NULLIF(UPPER(TRIM(vehicle_reg_no)), '') AS vehicle_reg_no
    FROM raw_service_complaints_2023

    UNION

    SELECT
        NULLIF(TRIM(customer_id), ''),
        NULLIF(UPPER(TRIM(vehicle_reg_no)), '')
    FROM raw_service_complaints_2024
),
warranty_pairs AS (
    SELECT DISTINCT
        NULLIF(UPPER(TRIM(vehicle_reg_no)), '') AS vehicle_reg_no,
        NULLIF(UPPER(TRIM(chassis_no)), '') AS chassis_no
    FROM raw_warranty_claims
),
job_pairs AS (
    SELECT DISTINCT
        NULLIF(UPPER(TRIM(chassis_no)), '') AS chassis_no,
        NULLIF(TRIM(mobile_hash), '') AS mobile_hash
    FROM raw_job_cards_2024
),
multiple_customer_regs AS (
    SELECT vehicle_reg_no
    FROM complaint_pairs
    WHERE vehicle_reg_no IS NOT NULL
    GROUP BY vehicle_reg_no
    HAVING COUNT(DISTINCT customer_id) > 1
)

INSERT INTO master_id_map (
    customer_id,
    vehicle_reg_no,
    chassis_no,
    mobile_hash,
    multiple_customers_flag
)
SELECT DISTINCT
    c.customer_id,
    COALESCE(c.vehicle_reg_no, w.vehicle_reg_no),
    COALESCE(w.chassis_no, j.chassis_no),
    j.mobile_hash,
    m.vehicle_reg_no IS NOT NULL
FROM complaint_pairs c
FULL OUTER JOIN warranty_pairs w
    ON c.vehicle_reg_no = w.vehicle_reg_no
FULL OUTER JOIN job_pairs j
    ON w.chassis_no = j.chassis_no
LEFT JOIN multiple_customer_regs m
    ON m.vehicle_reg_no =
        COALESCE(c.vehicle_reg_no, w.vehicle_reg_no);

-- TABLE: raw_snapshot.deleted_complaints_2023
CREATE TABLE raw_snapshot.deleted_complaints_2023 AS
SELECT * FROM raw_service_complaints_2023 WITH NO DATA;

-- TABLE: raw_service_complaints_2023
-- Retain the highest-priority ticket row and audit removed duplicates.
WITH ranked AS (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY ticket_id
            ORDER BY
                CASE UPPER(TRIM(status))
                    WHEN 'ESCALATED' THEN 1
                    WHEN 'OPEN' THEN 2
                    WHEN 'IN_PROGRESS' THEN 2
                    WHEN 'IN PROGRESS' THEN 2
                    WHEN 'RESOLVED' THEN 3
                    WHEN 'CLOSED' THEN 3
                    ELSE 4
                END,
                resolution_date DESC NULLS LAST,
                complaint_date DESC NULLS LAST,
                TO_JSONB(c)::TEXT,
                ctid
        ) AS row_num
    FROM raw_service_complaints_2023 c
    WHERE NULLIF(TRIM(ticket_id), '') IS NOT NULL
)
, deleted AS (
    DELETE FROM raw_service_complaints_2023 c
    USING ranked r
    WHERE c.ctid = r.ctid AND r.row_num > 1
    RETURNING c.*
)
INSERT INTO raw_snapshot.deleted_complaints_2023
SELECT * FROM deleted;

-- TABLE: raw_snapshot.deleted_complaints_2024
CREATE TABLE raw_snapshot.deleted_complaints_2024 AS
SELECT * FROM raw_service_complaints_2024 WITH NO DATA;

-- TABLE: raw_service_complaints_2024
-- Retain the highest-priority ticket row and audit removed duplicates.
WITH ranked AS (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY ticket_id
            ORDER BY
                CASE UPPER(TRIM(status))
                    WHEN 'ESCALATED' THEN 1
                    WHEN 'OPEN' THEN 2
                    WHEN 'IN_PROGRESS' THEN 2
                    WHEN 'IN PROGRESS' THEN 2
                    WHEN 'RESOLVED' THEN 3
                    WHEN 'CLOSED' THEN 3
                    ELSE 4
                END,
                resolution_date DESC NULLS LAST,
                complaint_date DESC NULLS LAST,
                TO_JSONB(c)::TEXT,
                ctid
        ) AS row_num
    FROM raw_service_complaints_2024 c
    WHERE NULLIF(TRIM(ticket_id), '') IS NOT NULL
)
, deleted AS (
    DELETE FROM raw_service_complaints_2024 c
    USING ranked r
    WHERE c.ctid = r.ctid AND r.row_num > 1
    RETURNING c.*
)
INSERT INTO raw_snapshot.deleted_complaints_2024
SELECT * FROM deleted;

-- Reject ticket IDs shared by both years before committing.
DO $check$
BEGIN
    IF EXISTS (
    SELECT ticket_id FROM raw_service_complaints_2023
    INTERSECT SELECT ticket_id FROM raw_service_complaints_2024
    ) THEN
    RAISE EXCEPTION 'Ticket ID occurs in both years; review source ownership before loading';
    END IF;
END $check$;

-- Count duplicate rows removed from each year.
SELECT '2023' AS source_year, COUNT(*) AS removed_duplicates
FROM raw_snapshot.deleted_complaints_2023
UNION ALL
SELECT '2024', COUNT(*) FROM raw_snapshot.deleted_complaints_2024;

COMMIT;
