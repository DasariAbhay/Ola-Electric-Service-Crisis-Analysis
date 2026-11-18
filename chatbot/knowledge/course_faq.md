# Ola Support Bot — FAQ Knowledge Base
Load this file into Copilot Studio / Dialogflow / Botpress as the bot's knowledge source.
Design intents from the Top-10 ticket categories you find in the complaints data.

## Service & Tickets
**Q: How do I check my complaint / ticket status?**
A: Share your ticket ID (format TKT-YYYY-NNNNNN). Status values: OPEN, IN_PROGRESS, AWAITING_PARTS, ESCALATED, RESOLVED, CLOSED. You can also track it in the Ola Electric app under Support → My Tickets.

**Q: How do I book a service slot?**
A: Open the Ola Electric app → Service → Book Slot. Choose home pickup or centre drop. Standard TAT is 3–5 working days; battery-related jobs may take longer if parts are awaited.

**Q: My vehicle has been at the service centre for many days with no update.**
A: If TAT has crossed 7 working days, the ticket auto-escalates to the Regional Service Manager. Reply ESCALATE with your ticket ID to trigger it now.

**Q: Where is my nearest service centre?**
A: Share your city name. (Bot: look up service_centers_master by city; return nearest 2 centres with capacity.)

## Battery, Range & Charging
**Q: My range is much lower than advertised.**
A: Certified range varies with mode, rider weight, terrain and temperature. In Eco mode expect closest-to-rated range. If real range is below 60% of rated on a full charge, book a battery health check — it is covered under the 3-year/40,000 km battery warranty.

**Q: Charger not working / charging stuck.**
A: Try a different 5A socket, check the green LED. If dead, raise a ticket under Charger/Charging — replacement chargers are issued against the ticket, subject to stock.

**Q: Is the battery covered under warranty?**
A: Yes — 3 years or 40,000 km (whichever first), covering manufacturing defects and capacity below 70% SoH. Physical/water damage is excluded.

## Software & App
**Q: Screen frozen / display blank after update.**
A: Hard reset: hold brake + power for 10 seconds. If unresolved, raise a Software/Display ticket; a technician can rollback the MoveOS build.

**Q: App not connecting to the scooter.**
A: Toggle Bluetooth, force-close the app, ensure MoveOS and app are on latest versions. Persisting issue → App/Connectivity ticket.

## Refunds & Billing
**Q: My refund is pending.**
A: Booking-amount refunds: 7–10 working days to source account. Beyond that, reply REFUND with your booking ID for finance-team escalation.

**Q: I was charged twice.**
A: Duplicate charges auto-reverse in 5–7 working days. If not reversed, raise a Refund/Billing ticket with both transaction IDs.

## Safety (always escalate — never deflect)
**Q: Brake failure / front fork issue / smoke or burning smell.**
A: Stop riding immediately. This is a P1 safety issue — the bot must create a P1 ticket and hand off to a human agent with a same-day callback commitment.

## Escalation path
Bot → P1/safety or 2 failed answers or user types AGENT → human agent.
Log every conversation with: intent detected, resolved_by_bot (Y/N), handoff_reason.
Bot KPI: deflection rate = conversations resolved without human ÷ total.
