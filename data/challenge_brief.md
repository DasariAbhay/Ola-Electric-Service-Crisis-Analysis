# Challenge Brief — Ola Electric Service Crisis Analytics
**Read this file completely before opening any data file.**

Window: Jan 2023 – Dec 2024 · 14 raw files · 7,21,423 records
Crisis window: Aug – Dec 2024 · CCPA show-cause notice: Oct 2024 (modelled on publicly reported events)

---

## 1. Data Quality Issue Map (find, fix, document every one)

| # | File(s) | Issue | Your job |
|---|---------|-------|----------|
| 1 | ola_sales_daily_2023 | Dates in `DD-MM-YYYY` | Standardise all dates to `YYYY-MM-DD` |
| 2 | ola_sales_daily_2024 | Dates in `YYYY-MM-DD` | Same target format |
| 3 | archived_sales_legacy | Legacy schema: `txn_dt (DD/MM/YY)`, `cty`, `mdl_cd`, `qty`, `rev_inr_lakh` | Rename/map to master schema; decode model codes (SP, SA, SX, SXP, SG) |
| 4 | archived_sales_legacy vs ola_sales_daily_2023 | Overlapping duplicates; ~1.5% rows have **conflicting qty** | Priority rule: **new system wins**. Document conflicts found |
| 5 | service_complaints_2024 | ~5% of `complaint_date` values are **epoch timestamps (UTC)** mixed with datetime strings | Detect, convert epoch → IST, standardise |
| 6 | Both complaint files | ~2% duplicate `ticket_id` with **conflicting status** | Priority rule (customer-first): ESCALATED > OPEN/IN_PROGRESS > RESOLVED/CLOSED |
| 7 | Both complaint files | `resolution_date` nulls ≈ 25–30% | Split: legitimately-open tickets vs missing data on resolved tickets. Do NOT blanket-drop |
| 8 | Both complaint files | `tat_days` column is **wrong in ~5% rows** (incl. negatives) | Recompute TAT from dates; never trust the given column |
| 9 | Both complaint files | `component_tag` only ~40% filled | Extract component from `complaint_text` using the keyword table in Section 3 |
| 10 | All files with `city` | Spelling variants (Bangalore/Bengaluru, Bombay/Mumbai, Kovai/Coimbatore, Vizag, Trichy, Hubli, Mysore, Cochin, case/space noise) | Build a city-standardisation lookup; apply everywhere |
| 11 | warranty_claims | ~8% rows in **USD** (imported battery cells) | Convert at 1 USD = ₹84. Flag every converted row |
| 12 | app_store_reviews | `rating_raw` mixed formats: "4 stars", "4", "4.0" | Parse to numeric 1–5 |
| 13 | social_media_posts.json | Nested JSON; `posted_epoch` is **UTC epoch** | Flatten `engagement{}`; convert epoch → IST |
| 14 | job_cards_2024 | `technician_id` ~8% null; `close_date` null = still open | Handle and document |
| 15 | complaints vs job_cards | Some tickets marked RESOLVED while linked job card is OPEN/AWAITING_PARTS | Cross-validation finding — flag and count, do not "fix" silently |
| 16 | complaints vs job_cards | Job cards exist **only for 2024** (2023 lost in ticketing-system migration) | State this limitation in your report |
| 17 | service_complaints files | `severity` ~8% null, `csat_score` ~25% null | Impute/flag/drop — justify your choice |

## 2. Identifier Mapping Hint (build master_id_map.csv FIRST)
Three ID systems exist. **No single file contains all four IDs.**

- `service_complaints_*` → customer_id + vehicle_reg_no
- `warranty_claims`      → chassis_no + vehicle_reg_no   ← **the bridge file**
- `job_cards_2024`       → chassis_no + mobile_hash

Join path: complaints ↔ (reg_no) ↔ warranty ↔ (chassis_no) ↔ job_cards.
Deliver `master_id_map.csv`: customer_id | vehicle_reg_no | chassis_no | mobile_hash.
Note: ~6% of complaint rows have null reg_no — quantify unmappable records.

## 3. Component Extraction Keyword Table (no-code text mining)
Use as a lookup for Power Query conditional columns / SQL CASE. First match wins, top-down.

| Priority | Keywords in text (contains, case-insensitive) | component_extracted |
|---|---|---|
| 1 | fork, brake, suspension, handle vibrat | Brakes/Suspension |
| 2 | refund, invoice, charged twice, booking amount | Refund/Billing |
| 3 | service center, service centre, pickup, job card, no response, spare part, slot | Service Delay |
| 4 | charger, charging, hypercharger, plug | Charger/Charging |
| 5 | range, battery, bms, drain, charge shows | Battery/Range |
| 6 | motor, grinding, power cut, belt, jerk, incline | Motor/Drivetrain |
| 7 | screen, display, ota, moveos, speedometer, cruise, reverse mode, navigation | Software/Display |
| 8 | app, bluetooth, sync, remote lock, key sharing | App/Connectivity |
| 9 | (no match) | Unclassified |

Validate: where `component_tag` is filled, your extracted value should match ≥ 90%.

## 4. KPI Definitions (use exactly these in SQL + dashboard)
- **Market Share %** = OEM registrations ÷ total registrations (from VAHAN file), monthly
- **Complaints per 1,000 Vehicles** = monthly complaints ÷ cumulative vehicles on road × 1000
- **TAT (days)** = resolution_date − complaint_date (recomputed)
- **First-Time-Fix proxy** = % tickets with no second job card on same chassis within 30 days
- **CSAT** = avg csat_score (resolved tickets only)
- **Vehicles per Service Centre** = cumulative vehicles ÷ active centres (opened_date ≤ month)
- **Stockout Rate** = weeks with stockout_days > 0 ÷ total part-weeks
- **Sentiment Index** = (positive − negative posts) ÷ total posts (rule-based tagging)
- **Escalation Rate** = ESCALATED tickets ÷ total tickets

## 5. Dashboard Panel → KPI Mapping
1. Crisis Overview → Market Share trend, KPI cards (share, complaints/1000, avg TAT, CSAT)
2. Complaint Heatmap → complaints by city × month; complaints per 1,000 vehicles
3. Service Capacity Gap → cumulative vehicles vs active centres (dual axis) + vehicles/centre line
4. TAT & Parts Tracker → monthly TAT distribution, stockout_days by part, AWAITING_PARTS share
5. Sentiment vs Sales → sentiment index and monthly sales with 2-month lag annotation

## 6. Ground Rules
- All money in ₹. Flag USD-converted rows.
- All timestamps in IST, `YYYY-MM-DD`.
- Every cleaning decision goes into data_quality_report.pdf with justification.
- Conflicts between files are **findings**, not inconveniences.
