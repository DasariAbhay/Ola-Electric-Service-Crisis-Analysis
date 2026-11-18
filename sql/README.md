# SQL modules and execution context

The project uses PostgreSQL and pgAdmin. Scripts preserve the supplied SQL logic. Database guards intentionally distinguish two environments:

- `new_ola_analytics_replay`: untouched raw imports and one-time cleaning.
- `new_ola_analytics`: cleaned sources and the analytical model used by the completed project.

The two parts of the supplied `DML(8).sql` are separated into fresh-cleaning and cleaned-source-load files. They are not intended to be executed sequentially in one connection to one database.

## Modules

| Module | Purpose | Database |
| --- | --- | --- |
| `01_DDL_Raw_Tables.sql` | Raw tables, identifier-map and city-lookup structures | Replay |
| `02_DML_Fresh_Cleaning.sql` | Source cleaning, mapping, snapshots and audited duplicate removal | Replay |
| `03_DDL_Star_Schema.sql` | Dimensions, facts, constraints, indexes and views | Analytical |
| `04_DML_Load_Cleaned_Data.sql` | Loads the model from existing cleaned `public` sources | Analytical |
| `05_DQL_Validation.sql` | Reconciliation, missingness and consistency queries | Analytical |
| `06_DQL_Root_Cause.sql` | Operational analysis | Analytical |
| `07_DQL_Window_Functions.sql` | Trends, ranking and cumulative analysis | Analytical |
| `08_DQL_Cross_Fact_Analysis.sql` | Aggregated comparisons across facts | Analytical |
| `09_Social_Illustrative_Views.sql` | Explicitly assumed social timeline and related views | Analytical |
| `optional/DCL_Roles.sql` | Role and privilege demonstration | Analytical; appropriate role privileges |
| `optional/TCL_Demonstration.sql` | Transaction/savepoint example using a temporary ledger | Separate demonstration |

## Working from the completed analytical database

With the cleaned `public.raw_*` sources, populated `public.master_id_map` and city lookup already present in `new_ola_analytics`, the schema and load scripts form the model-building path. Keep each script in one session where it relies on session search paths or temporary tables. The DDL contains analytical views that reference cleaned source columns, so untouched imports are not a substitute for cleaned sources.

`09_Social_Illustrative_Views.sql` precedes any query that references its views. `05_DQL_Validation.sql` contains diagnostics; results must be interpreted rather than treated as an automatic pass. Read the comments for individual analytical query populations and denominators.

## Working from the original course files

1. Use a separate replay database named `new_ola_analytics_replay`, then run the raw DDL.
2. Import the 14 course sources into their matching raw structures. CSV columns must match the declared raw columns; JSON records require flattening, including social engagement fields. Import settings and the original flattening execution log are not packaged as a tested loader.
3. Run the fresh-cleaning module once on those untouched imports. It retains snapshots and audits duplicate removals.
4. The analytical model requires the resulting cleaned raw tables, `master_id_map` and city lookup in the `public` schema of `new_ola_analytics`. Transfer of these cleaned structures and data between the two databases is an environment setup step, not automated by this package. The replay database guard is not a reason to rename the completed database.
5. With those prerequisites present, use the analytical path above and examine validation outputs before connecting or refreshing Power BI.

This documents the supplied workflow; a fresh raw-to-model replay has not been executed during packaging. No success is claimed for unrun SQL, and the scripts are not represented as an idempotent migration system. Existing project data should not be overwritten merely to review this repository.

All dates are interpreted in the project context of Asia/Kolkata. Unknown source dates remain distinct from the assumed illustrative timeline. The database names and SQL semantics have not been changed.
