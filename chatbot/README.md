# Ola Care Assistant demonstration

[Open the chatbot](https://vdk-viber-runtime-prod.bot.botpress.host/edge/?botId=d9d95cda-60ba-4d80-8895-25fbef540aad)

This is a student support prototype using synthetic and fictional project records. It is not an official Ola service channel. The link was supplied by the author; availability and current hosted configuration have not been independently tested during packaging.

## Design and evidence

- [Intent design](Chatbot_Intent_Design.docx)
- [Five fictional ticket records](demo_ticket_records.pdf)
- [Service-centre CSV](knowledge/service_centers_cleaned.csv)
- [Course FAQ](knowledge/course_faq.md) - supplied project policies, not independently verified current manufacturer policy.
- [Final historical classification](evidence/intent_counts.csv)
- [Eligibility sample and scenario calculations](evidence/deflection_sample.csv)
- [Safety-handoff screenshot](evidence/safety_handoff.png)

The screenshot shows a reported burning smell, safety guidance, a transfer notice, an agent joining and a human reply. It supports one demonstrated end-to-end safety handoff. It does not establish a complete 15-case test result, operational response times or a production success rate.

The HTML file under `webpage/draft/chatbot_section.html` is a webpage section, not Botpress source. A portable Botpress project export is not included. The knowledge files and intent design document describe the demonstration, but do not reproduce its hosted workflow on their own.

## Sample-based eligibility and deflection

| Reporting group | Historical tickets | Reviewed | Eligible in sample | Projected eligible tickets |
| --- | ---: | ---: | ---: | ---: |
| Battery / range | 31,687 | 25 | 10 | 12,674.80 |
| Software / display | 12,130 | 25 | 4 | 1,940.80 |
| Charger / charging | 11,831 | 25 | 3 | 1,419.72 |
| App / connectivity | 6,481 | 25 | 9 | 2,333.16 |
| Total across reviewed groups | 62,129 | 100 | 26 | 18,368.48 |

Projected eligibility is 18,368.48 / 131,366 = approximately **13.98% of all historical tickets**. The denominator includes all reporting groups, not just the four reviewed groups. The remaining groups contribute no eligible cases to this particular projection; that is a modelling choice, not proof of universal ineligibility.

| Scenario | Assumed successful self-service rate | Estimated deflection | Rounded ticket-equivalents |
| --- | ---: | ---: | ---: |
| Lower | 40% | 5.59% | 7,347 |
| Central | 60% | 8.39% | 11,021 |
| Higher | 80% | 11.19% | 14,695 |

The sample sheet is supplied evidence. Ticket-level review decisions, selection method and sampling uncertainty are not documented. The 26% unweighted eligible share in the sample is not the weighted population projection. Success rates above are assumptions, not measured bot outcomes. No realised contact reduction or cost saving is claimed.

Final classification covers all 131,366 tickets using one primary group per ticket. Zero unclassified tickets demonstrates rule coverage, not independently validated accuracy. The final CSV matches the supplied intent design and webpage section; the earlier draft is retained in `archive/`.
