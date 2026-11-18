# Ola Electric Service Crisis Analytics — Dataset
7,21,423 records | 14 raw files | Jan 2023 – Dec 2024 | Synthetic, modelled on publicly reported events

## Start here
1. Read challenge_brief.md fully (issue map, ID mapping hint, keyword table, KPI definitions).
2. Complete all data cleaning before any analysis.
3. Build master_id_map.csv first — every crew/customer join depends on it.

## Folder map
raw/sales/       ola_sales_daily_2023.csv (54,750) · ola_sales_daily_2024.csv (54,900) · archived_sales_legacy.csv (52,012) · vahan_competitor_registrations.csv (65,790)
raw/complaints/  service_complaints_2023.csv (52,224) · service_complaints_2024.csv (81,769) · app_store_reviews.csv (50,000)
raw/service/     service_centers_master.csv (620) · job_cards_2024.csv (76,158) · spare_parts_consumption.csv (62,400)
raw/financial/   warranty_claims.csv (65,000)
raw/external/    social_media_posts.json (50,000) · nch_ccpa_complaints.csv (55,000) · competitor_incidents.json (800)
support/         chatbot_faq_source.md (knowledge base for the chatbot phase)

## Conventions
- Currency target: INR (convert USD @ ₹84, flag rows)
- Timezone target: IST · Date target: YYYY-MM-DD
- Dimension files (centres, incidents) are intentionally small; fact files are 50–80k rows each.
