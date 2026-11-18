# Power BI report

`Ola_Crisis_Analysis.pbix` is the final dashboard confirmed by the author. The original filename was `backup_Ola_Crisis_Star_Schema.pbix`; the bytes are unchanged. `Ola_Crisis_Analysis.pdf` is the supplied eight-page dashboard export.

| Page | Preview |
| --- | --- |
| Crisis Overview | [Image](../assets/dashboard/crisis_overview.png) |
| Complaint Heatmap | [Image](../assets/dashboard/complaint_heatmap.png) |
| Service Capacity Gap | [Image](../assets/dashboard/service_capacity_gap.png) |
| TAT and Parts Tracker | [Image](../assets/dashboard/tat_parts_tracker.png) |
| Sentiment and Sales | [Image](../assets/dashboard/sentiment_sales.png) |
| Forecasting | [Image](../assets/dashboard/forecasting.png) |
| Recovery Scenarios | [Image](../assets/dashboard/recovery_scenarios.png) |
| Scenario Details | [Image](../assets/dashboard/scenario_details.png) |

Open the PBIX in Power BI Desktop for the interactive report. Refresh requires access to the configured PostgreSQL source and local credentials. The package does not include credentials or a running database.

Filters in the PDF are the saved export state. Some pages use different scenario selections, so their totals should not be combined as if they were one scenario. Social dates are reconstructed for illustration. Forecasts cover January-June 2025 as a historical exercise.

The PBIX contains report definitions and an embedded data model. Packaging checks inspected its structure; they did not execute its DAX, refresh data or validate every relationship in Power BI Desktop.
