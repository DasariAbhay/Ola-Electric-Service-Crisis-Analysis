# Raw source inventory

Counts were read from the supplied original files during packaging. CSV counts exclude headers. JSON counts refer to top-level records.

| Source | Records | Bytes |
| --- | ---: | ---: |
| `data/raw/complaints/app_store_reviews.csv` | 50,000 | 4,400,860 |
| `data/raw/complaints/service_complaints_2023.csv` | 52,224 | 9,021,181 |
| `data/raw/complaints/service_complaints_2024.csv` | 81,769 | 14,683,715 |
| `data/raw/external/competitor_incidents.json` | 800 | 162,671 |
| `data/raw/external/nch_ccpa_complaints.csv` | 55,000 | 3,579,110 |
| `data/raw/external/social_media_posts.json` | 50,000 | 15,492,574 |
| `data/raw/financial/warranty_claims.csv` | 65,000 | 5,668,757 |
| `data/raw/sales/archived_sales_legacy.csv` | 52,012 | 1,432,925 |
| `data/raw/sales/ola_sales_daily_2023.csv` | 54,750 | 3,680,141 |
| `data/raw/sales/ola_sales_daily_2024.csv` | 54,900 | 3,695,168 |
| `data/raw/sales/vahan_competitor_registrations.csv` | 65,790 | 3,605,736 |
| `data/raw/service/job_cards_2024.csv` | 76,158 | 9,474,527 |
| `data/raw/service/service_centers_master.csv` | 620 | 48,905 |
| `data/raw/service/spare_parts_consumption.csv` | 62,400 | 3,153,858 |

Total: **721,423 records across 14 files**. These raw counts differ from cleaned model loads because source coverage, overlaps and duplicate handling differ.
