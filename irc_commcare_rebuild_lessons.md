# CommCare App Rebuild — Lessons Learned

Derived from data quality analysis of the EPR (Ecuador-Peru Response) health dashboard pipeline, April 2026.

---

## 1. Never embed a service in the registration form

The root cause of a historical data gap in the EPR app. Registration should register a client, full stop. The first service — even if it's always an information session — belongs in the services form. Mixing the two created a class of clients whose first (and sometimes only) service is permanently invisible to analysis.

## 2. One case per service is the right design — commit to it

The repeat group in Agregar Servicios (one form, multiple service cases) is good architecture. It makes the case export authoritative at the service level. Design the new app so that every service delivery creates exactly one `servicios_salud` case, with all its clinical detail on that case. Don't compress multi-service visits into a single form row.

## 3. Store country as an explicit case property

Country is currently derived from `ubicacion_1_etiqueta` in the pipeline — it works, but it's fragile. If the location label format ever changes, country attribution breaks silently. A dedicated `pais` case property on `cliente_salud`, set at registration and never overwritten, costs nothing and makes every downstream query more robust.

## 4. Use ASCII-only values for coded fields

`migrante_con_vocacion_de_permanencia` lost its accent through the CommCare export chain and required special handling. Option values and case property codes should be plain ASCII — accents belong in display labels only.

## 5. Build a running service counter properly, or don't build one

The EPR app had a `cantidad_servicios` field that stored the count from the most recent visit, not a cumulative total. A genuine running total needs a CommCare calculation that reads the previous case value and increments it. If that's not implemented correctly the field is actively misleading. Either implement it properly or drop it entirely.

## 6. Standardise test account naming and filter at source

Having email addresses as test usernames made them hard to identify programmatically. Agree on a convention before launch — e.g. all test/staff accounts prefixed with `test_` or assigned to a specific CommCare group — and filter them in the CommCare export configuration rather than in post-processing.

## 7. Add a household or family linkage if you want that analysis

There is currently no way to detect that two clients are from the same family. If that analysis matters, it needs to be designed in from the start — either a household case type as parent to individual clients, or a `household_id` field populated at registration. Retrofitting this is very hard.

## 8. Align service form fields across countries before launch

CACU/IVAA screening only appeared for Ecuador; FP method fields were blank entirely. These gaps suggest the form wasn't fully validated against what each country actually delivers. Before launch, do a field-by-field walkthrough with both country teams to confirm every field is in use and named consistently.

## 9. Add date validation to the form

Registration dates as far back as 1991 were present, and a single month had an anomalous spike likely caused by data entry errors. CommCare allows constraints on date fields — set a minimum date (programme start) and block future dates at the form level. It is much easier to prevent bad dates than to filter them out later.

## 10. Export cases, not just forms — and make it routine

The EPR form export was missing ~3,400 services from an Oct 2024–Feb 2025 download gap. Case exports are more durable: they persist even when form exports have gaps, and with a one-case-per-service design they carry all the clinical detail needed for analysis. Make the case export part of the standard download routine from day one.
