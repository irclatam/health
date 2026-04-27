# IRC Latin America Health Dashboard

Static Quarto/GitHub Pages dashboard for the Ecuador–Peru Response (EPR) health programme. Comparative view across Ecuador and Peru for health coordinators, programme managers, and donors.

---

## Repository structure

```
scripts/
  00_anonymise_epr.R          — strips PII from 3 form exports (registro, servicios, historia)
  00_anonymise_epr_cases.R    — strips PII from 2 case exports (clientes, servicios cases)
  01_pipeline_epr.R           — produces aggregated tables in data/ from data_anonymised/
data_anonymised/              — gitignored; output of anonymisation scripts
data/                         — gitignored; output of pipeline (pre-aggregated CSVs for dashboard)
irc_commcare_rebuild_lessons.md
irc_health_dashboard_spec_v2.md
```

---

## Date handling

### The problem

CommCare form exports contain two types of dates:

- **System timestamps** (`completed_time`, `opened_date`): set automatically when a form is submitted or a case is opened. Always present, no manual entry errors, but reflect submission time — not the actual visit.
- **Manual dates** (`fecha_de_registro`, `fecha_de_atencion`): entered by the clinician. Closer to the true event date, but subject to entry errors, and 32% missing in registration.

Field workers frequently operate offline and submit forms days or weeks after seeing a client, so system timestamps alone overstate how recently services occurred.

### The offline entry lag

Using the service form export (which has both a manually entered `fecha_de_atencion` and a `completed_time`), we can measure the lag between the actual service date and form submission. Validated across 28,030 service rows:

| Statistic | Days |
|-----------|------|
| Mean | 7.8 |
| Median | 5 |
| 75th percentile | 10 |
| 90th percentile | 18 |
| 95th percentile | 27 |
| Max (cutoff) | 90 |

The distribution is not Poisson. Three distinct behaviours are visible:

- **Day 0** (20.8%): form submitted same day — online entry or good connectivity.
- **Day 1** (9.3%): next-morning entry — clearly elevated versus days 2–7.
- **Days 2–14** (flat plateau, ~5–6%/day): forms submitted in the days after a visit, with mild spikes at day 7 and day 14 consistent with weekly batch submission.
- **Tail (days 15–90)**: trailing off, likely isolated connectivity gaps. The 90-day cutoff removes only 1.1% of rows.

### Validation rules for service dates

A manually entered `fecha_de_atencion` is accepted as valid if:

1. It is on or after the project start date (`2024-06-01`).
2. It is not in the future relative to the form submission date (lag ≥ 0).
3. The lag is ≤ 90 days (excludes implausible backdating).

88.1% of service rows pass these checks and receive a validated manual date. The remaining 11.9% fall back to `opened_date` (the case system timestamp).

The validated date is stored as **`service_date_validated`** on the servicios table.

### reg_date_validated

`fecha_de_registro` (manual registration date) is 32% missing and contained dates as far back as 1991. It is not used in the validated registration date.

Instead, **`reg_date_validated`** is derived as:

> The earlier of: (a) the registration form submission timestamp (`completed_time`), and (b) the client's earliest `service_date_validated`.

Triangulating against the first service date allows us to recover earlier visit dates for clients whose registration form was submitted late. In practice:

- 15,338 clients (of ~18,000) shifted to an earlier date via this triangulation.
- 2,891 clients changed month as a result.

### Validation results

Both final checks pass on the current dataset:

- **0** services have a `service_date_validated` before the client's `reg_date_validated`.
- **0** clients have a `reg_date_validated` before `2024-06-01` (project start).

---

## Authoritative service source

Service data comes from the **servicios_salud case export** (`ecuador_servicios_cases_clean.csv`), not the form export. The form export is missing ~3,400 services from an Oct 2024–Feb 2025 download gap. The case export has one row per individual service and is complete. See `irc_commcare_rebuild_lessons.md` for the full reasoning.

---

## Test/staff account exclusion

The following accounts are excluded at anonymisation time (before any analysis):

```
test, test_peru, test_ecuador, irc2
jorge.jaramillo@rescue.org, zahira.soraluz@rescue.org, leticia.lopera@rescue.org
taraneh.missaghian@rescue.org, angela.pajuelo@rescue.org
hebert.delgado@rescue.org, belen.agurto@rescue.org
```

---

## Known data issues

- `fp_corta` / `fp_larga` (FP methods) consistently empty — field likely stored under a different name in CommCare.
- CACU/IVAA screening only appears for Ecuador (15 records) — Peru may not run this service.
- Ecuador November 2025 has an anomalous spike — possible data entry error.
- `patologias_cronicas` (chronic conditions) recovered from the `cliente_salud` case export after anonymisation fix — 44% of clients have data. The historia clinica form export version remains blank (CommCare appears not to populate it there).
- `referido` (referrals) not available in service cases — referrals chart currently produces zero counts.
