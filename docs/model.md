# Analytical model and table grains

The supplied `sql/03_DDL_Star_Schema.sql` defines six dimensions and nine facts in `ola_star`. The table below describes the declared keys and grains; it is not a fresh inspection of the live database or PBIX relationships.

| Table | Declared grain or identity |
| --- | --- |
| `dim_date` | One calendar date |
| `dim_city` | One canonical city name, with service-region attribute |
| `dim_oem` | One OEM name |
| `dim_part` | One member type and member code, covering parts and complaint components |
| `dim_service_center` | One centre ID |
| `dim_vehicle_customer` | One identity type and identity value; not necessarily one unique vehicle |
| `fact_sales` | One sale date, city and model combination |
| `fact_complaints` | One ticket ID |
| `fact_jobcards` | One job-card ID |
| `fact_warranty` | One claim ID |
| `fact_vahan_registrations` | One registration date, city, OEM and vehicle class |
| `fact_spare_parts` | One week, centre and part code |
| `fact_sentiment` | One source and source ID |
| `fact_nch_complaints` | One NCH reference ID |
| `fact_competitor_incidents` | One incident ID |

Facts reference shared dimensions directly. The DDL does not declare a foreign key from job cards to the complaints fact; linked-ticket fields support validation and analysis. Fact-to-fact aggregation requires care because a complaint can be associated with multiple jobs or claims.

The source `master_id_map` preserves four-identifier associations across customer ID, registration, chassis and mobile hash. The recorded 184,399 associations are not a unique-vehicle count. Missing and ambiguous identifiers are retained as coverage limitations.

Key views include `vw_monthly_kpis`, `vw_city_service_gap`, `vw_vehicle_identifier_map` and `vw_cross_validation_discrepancies`. Illustrative social views live in a separate module to keep assumed event dates distinct from confirmed dates.

The model contains date and city indexes, primary and foreign keys, uniqueness and CHECK constraints. The SQL is the authoritative reference for exact nullability and field names.
