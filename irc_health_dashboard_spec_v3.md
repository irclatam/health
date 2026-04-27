# IRC Latin America — health services dashboard: spec v3

*Supersedes v2. Key changes: scope narrowed to Ecuador + Peru (Mexico deferred); trends section removed; equity lens folded into clinical section; nationality and services-per-client charts added; chronic conditions now available; value boxes introduced.*

---

## Purpose

A static comparative dashboard for the IRC Ecuador–Peru Response (EPR) health programme. The value of this product is what neither country team can see in their own dashboard: the regional comparison. It is not an indicator dashboard and does not replicate operational monitoring. It answers a different set of questions: who are we reaching, what are we treating, and how do the two countries compare?

Primary audiences: health coordinators, programme managers, donors. Built in Quarto with ggplot2, deployed as a standalone GitHub Pages site. Mexico deferred pending pipeline build.

---

## Colour system

### Country palette

| Country | Hex | Swatch |
|---|---|---|
| Ecuador | `#22A06B` | green |
| Peru | `#AF59E1` | purple |

Defined once in `scripts/theme_irc.R`. Mexico (`#357DE8`, blue) is reserved for when that pipeline is built.

### Colour rules

1. **Country is the variable** (grouped bars on shared axes, line charts) → country palette.
2. **Country is the facet** (small multiples) → country colour for fills within each panel.
3. **A second categorical variable within a panel** → purpose-specific palette, not country colour. Applies to Chart 3.1 (SSR service types) only.

**Exceptions:**
- Chart 1.2 (sex breakdown): neutral grey bars — country is carried by panel title only.
- Chart 2.2 (prenatal age profile): safeguarding red (`#E53935`) for under-18 bars only.

### Additional palettes

**SSR service types** (`pal_service`, Chart 3.1): ColorBrewer Dark2 subset.

**Safeguarding highlight** (`col_highlight`): `#E53935`. Under-18 bars only — never used for any other purpose.

---

## Data freshness

Single line below the page title: *Data last updated: [date]. Source: CommCare, IRC Latin America.*

---

## Page structure

The document is organised in two conceptual halves: **Clients** (who we're registering) and **Services** (what we're delivering). These are not separate tabs — they are clearly labelled sections within a single scrolling page. Each half opens with a row of value boxes giving headline numbers before the charts begin.

---

### Section 0: Geographic overview

**Chart 0.1 — Consultation locations map**

Opening visual. Two-panel bubble map (Ecuador, Peru side by side). Bubbles sized by total registered clients at each municipality, coloured by country. Establishes the geographic footprint before any clinical detail.

*R approach:* `geom_sf()` via `rnaturalearth`. `geom_sf()` with `size = n_clients` for bubbles. `coord_sf()` set to cover both countries in a single frame (western South America). Coordinates from `data/locations.csv`.

---

### — CLIENTS —

*Value boxes (row of 3–4):*
- Total registered clients (Ecuador + Peru combined)
- Ecuador clients / Peru clients (two boxes, or one split box)
- % under 18 across both countries

---

### Section 1: Who we're reaching

**Chart 1.1 — Consultations over time**

Single chart, two coloured lines (Ecuador, Peru). X: month. Y: consultation count. This is the volume and trajectory chart — the first thing a reader looks for after the map.

*ggplot2:* `geom_line() + geom_point()` with `colour = country`. No smoothing unless visually warranted.

---

**Chart 1.2 — Sex breakdown**

Two panels side by side. Horizontal bars, neutral grey fill, country colour in panel title. Categories: Mujer, Hombre, Intersexual, No desea responder. Caption notes sex not gender.

---

**Chart 1.3 — Age and sex distribution (population pyramid)**

Two panels, 5-year age bands × sex. Standard population pyramid layout — women right, men left. Country colour for fills.

A headline sentence above: *"X% of all registered clients are under 18."*

---

**Chart 1.4 — Migration profile**

Two panels. Horizontal ranked bar chart of migration profile categories as percentage of clients. The most programmatically significant chart in this section — Ecuador is 77% host community, Peru is 69% transit migrants.

A one-sentence callout above flagging this contrast explicitly.

---

**Chart 1.5 — Ethnic profile**

Two panels. Horizontal ranked bars. Headline callout: *"X% of clients identify as indigenous."*

---

**Chart 1.6 — Nationality** *(new in v3)*

Two panels, vertical column chart. Top nationalities by country as percentage of clients. Ecuador: predominantly Ecuadorian (84%) + Venezuelan (12%) + Colombian (3%). Peru: Venezuelan (55%) + Peruvian (30%) + Colombian (11%). Chart reveals that Peru is primarily serving Venezuelan migrants while Ecuador is primarily a host-community programme — a different framing of the same contrast as Chart 1.4.

*ggplot2:* `geom_col() + facet_wrap(~ country, ncol = 2)`. Bars in country colour. X axis: nationality label, Y axis: percentage. Collapse "otra_nacionalidad" and "doble_nacionalidad" into "Other / dual".

---

**Chart 1.7 — Services per client** *(new in v3)*

Two panels. Stacked or grouped bar showing distribution of total service count per client (1, 2, 3, 4–5, 6–10, 11+) as percentage of clients.

Headline callout above: *"77% of clients in Ecuador and 62% in Peru received only one service. Peru clients receive on average 1.6 services vs 1.3 in Ecuador."*

This is a meaningful programmatic difference: Peru has higher service intensity, likely reflecting a transit corridor model where clients return for follow-up. Ecuador's single-service dominance may reflect a first-contact, onward-referral model.

*Data source:* `agg_services_per_client.csv` (distribution) and `agg_services_per_client_summary.csv` (headline stats).

*ggplot2:* `geom_col() + facet_wrap(~ country, ncol = 2)`. Ordered factor for service band.

---

### — SERVICES —

*Value boxes (row of 3–4):*
- Total services delivered (Ecuador + Peru combined)
- Syphilis positivity rate (combined, flagged)
- % of prenatal clients under 18

---

### Section 2: Clinical picture — primary care

**Chart 2.1 — Top 10 APS diagnoses by country**

Two panels, free y-scale. Horizontal bars in country colour. ICD-10 label displayed, not code.

One-sentence analytical note below: the Ecuador vs Peru contrast (parasitosis/UTI/cold vs child health checks/headache/cold) and what it implies about the populations being served.

---

**Chart 2.2 — Top diagnoses by age band**

`facet_grid`: age band (rows) × country (columns). Top 5 diagnoses per cell. Small font. Five age bands × two countries = 10 panels.

---

**Chart 2.3 — Chronic conditions** *(previously blocked, now available)*

Two panels. Horizontal bars showing percentage of clients (among those with data, 44%) who have each chronic condition. Conditions: Hipertensión, Diabetes, Cáncer, Cardiopatías, ACV, EPOC. Note that `otro_cronico` (12% of those with any condition) retains the flag but not the free-text specification.

Caption: *"44% of registered clients have chronic conditions data. Clients may have more than one condition."*

---

**Chart 2.4 — Top diagnoses: host community vs migrants** *(moved from v2 Section 6)*

`facet_grid`: population group (host community / migrants) × country. Top 5 diagnoses per cell. Four panels total.

This is the equity-lens insight embedded in the clinical section where it belongs: do migrants and host community present with different conditions? In Ecuador where both groups are sizeable this is particularly interesting.

*Data source:* `agg_equity_diagnoses.csv`.

---

### Section 3: Sexual and reproductive health

**Chart 3.1 — SSR service mix**

Single grouped bar chart. One bar per country, proportional fill by SSR service type (family planning, prenatal, ITS/ETS, cancer screening, GBV, counselling). Uses SSR service palette, not country colour.

---

**Chart 3.2 — ITS/ETS testing and positivity**

Paired bars per condition (Syphilis, HIV, Hepatitis B) × country. Positivity rate on y-axis, n tested as label.

Headline callout: *"Syphilis positivity: Peru 5.9% vs Ecuador 1.8%."*

---

**Chart 3.3 — Family planning method mix**

*Data status:* `fp_corta` / `fp_larga` consistently empty across full EPR dataset. Pending field-name investigation. Placeholder text until resolved.

---

**Chart 3.4 — Prenatal care: age profile**

Two panels. Bar chart by age band, under-18 bars in safeguarding red. Headline callout: *"X% of prenatal clients are under 18."*

---

**Chart 3.5 — CACU/IVAA screening**

Stat callout. Ecuador: N screened, positivity rate. Peru: absent from current dataset (unconfirmed whether service runs or field name differs).

---

### Section 4: Mental health

*Section note: Mental health services in Peru and Ecuador only.*

**Chart 4.1 — Mental health service type**
Two panels. Horizontal bars by service modality.

**Chart 4.2 — Top mental health diagnoses**
Two panels. Top 10 ICD-10 MH diagnoses, free y-scale, country colour.

**Chart 4.3 — Referral rate**
Stat callout per country: % of MH clients referred externally.

---

### Section 5: Pharmaceutical dispensing

*Deferred. Mexico pipeline not yet built. Section retained as placeholder.*

---

## What was removed from v2

| Removed | Reason |
|---|---|
| Section 6: Equity lens (full) | Chart 6.1 folded into Section 2 as Chart 2.4. Charts 6.2 and 6.3 cut — marginal value given small cell sizes |
| Section 7: Trends over time (all 5 charts) | No clinically meaningful outbreak or trend signal in current data. Ecuador Mar 2025 dip is operational, not clinical. Early 2024 spikes are programme ramp-up. Cut for now — restore if data warrants |
| Chart 1.1 as opening chart | Map now opens the document; consultations-over-time moved to start of Services half |

---

## Implementation status

Legend: ✓ ready · ⚠ data issue · ✗ pending · n/a not applicable

| Chart | Ecuador | Peru | Notes |
|---|---|---|---|
| **0.1** Map | ✓ | ✓ | |
| **1.1** Consultations over time | ✓ | ✓ | |
| **1.2** Sex breakdown | ✓ | ✓ | |
| **1.3** Population pyramid | ✓ | ✓ | |
| **1.4** Migration profile | ✓ | ✓ | |
| **1.5** Ethnic profile | ✓ | ✓ | |
| **1.6** Nationality | ✓ | ✓ | New in v3 |
| **1.7** Services per client | ✓ | ✓ | New in v3 |
| **2.1** Top 10 APS diagnoses | ✓ | ✓ | |
| **2.2** Diagnoses by age band | ✓ | ✓ | |
| **2.3** Chronic conditions | ✓ | ✓ | Previously blocked; now available from clientes cases |
| **2.4** Diagnoses: host vs migrant | ✓ | ✓ | Moved from v2 Chart 6.1 |
| **3.1** SSR service mix | ✓ | ✓ | |
| **3.2** ITS testing & positivity | ✓ | ✓ | |
| **3.3** FP method mix | ⚠ | ⚠ | Fields empty — field name investigation pending |
| **3.4** Prenatal age profile | ✓ | ✓ | |
| **3.5** CACU screening | ✓ | ⚠ | Peru records absent — cause unconfirmed |
| **4.1** MH service type | ✓ | ✓ | |
| **4.2** Top MH diagnoses | ✓ | ✓ | |
| **4.3** MH referral rate | ✓ | ✓ | |

**18 of 20 charts have data ready. 2 charts have known data gaps (3.3 FP methods, 3.5 CACU Peru).**

---

## Key findings

**Population contrast**
- Ecuador: 84% Ecuadorian nationals, 77% host community. A settled community-based programme.
- Peru: 55% Venezuelan nationals, 69% transit migrants. A transit corridor programme.
- These are fundamentally different service models serving populations with different needs.

**Service intensity**
- 77% of Ecuador clients receive only one service (mean 1.3). 62% of Peru clients receive only one service (mean 1.6).
- Peru's higher return rate is consistent with a more complex caseload in a transit setting.

**Sexual health**
- Syphilis positivity: Peru 5.9% vs Ecuador 1.8% — clinically significant.

**Primary care**
- Ecuador: parasitosis, UTI, cold dominate. Peru: child health checks, cold, headache, pharyngitis, lumbago.
- Peru's prominence of Z00.1 (child health check) reflects a different service model.

**Chronic conditions**
- 44% of clients have chronic conditions data. Hypertension and diabetes are the main named conditions.

---

## Known limitations

- FP method fields (`fp_corta`/`fp_larga`) empty — field name investigation pending.
- CACU/IVAA: Ecuador 15 records only; Peru absent.
- `referido` (referral) not available in service cases — referral chart shows zero counts.
- `cual_otro_cronico` (other chronic condition free text) blanked as PII — `otro_cronico` flag retained.
- Mexico pipeline not built — Section 5 is a placeholder.
- Ecuador Feb–Apr 2026 shows low consultation counts — likely incomplete recent data rather than programme decline.

---

*Spec v3 — April 2026. IRC Latin America health programme.*
