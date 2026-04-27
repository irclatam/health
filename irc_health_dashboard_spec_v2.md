# IRC Latin America — health services dashboard: MVP spec (v2)

## Purpose

A static epidemiological dashboard summarising IRC health service data across Peru, Ecuador, and Mexico in a single comparative view. Country is treated as a visual variable throughout — a consistent three-colour palette, one colour per country, used across every chart. The value of this product is the regional picture: patterns that emerge from comparison across three contexts serving similar populations.

Primary audiences are health coordinators, programme managers, and donors. Built in Quarto with ggplot2, deployed as a standalone page within the existing irclatam GitHub Pages site. Updated on a defined cadence (weekly or monthly depending on pipeline).

**Suggested URL:** `irclatam.github.io/health`

---

## Colour system

### Country palette

From the IRC Latam Atlassian palette, used across the Shiny app. **Provisional** — will be updated when a formal IRC Latam brand palette is finalised. All colours are defined once in `scripts/theme_irc.R`; changing a value there propagates across every chart.

| Country | Hex | Swatch |
|---|---|---|
| Ecuador | `#22A06B` | green |
| Mexico | `#357DE8` | blue |
| Peru | `#AF59E1` | purple |

A legend appears once at the top of the page and is not repeated on every chart.

### Three rules for colour use

1. **Country is the variable** (line charts, grouped bars on shared axes) → use country palette.
2. **Country is the facet** (small multiples — country per panel) → use country colour for bars within each panel. Reinforces country identity when panels are spread across a wide page.
3. **A second categorical variable is encoded within a panel** → use a purpose-specific palette, not country colour (to avoid country colour meaning two different things). Currently applies to Chart 3.1 (SSR service types) only.

**Exception to rule 2:** Chart 1.2 (sex breakdown) uses neutral grey bars — country colour is carried by the panel title only, to avoid the colour implying sex is a country-level attribute.

### Additional palettes

**SSR service types** (`pal_service`, Chart 3.1 only) — ColorBrewer Dark2 subset: planificación familiar `#1B9E77`, atención prenatal `#D95F02`, ITS/ETS `#7570B3`, detección de cáncer `#E7298A`, VBG `#E6AB02`, consejería `#A6761D`.

**Safeguarding highlight** (`col_highlight`, Charts 3.4 and 7.4) — `#E53935` (red). Used exclusively for the under-18 bar to draw the eye to a safeguarding signal. Never used for any other purpose.

### Typography

Fonts match the existing IRC Latam GitHub Pages product: **Inter** for all text, **Roboto Mono** for numeric axis labels. Both loaded via `showtext` / `font_add_google()`.

---

## Data freshness

A single line below the page title: *Data last updated: [date]. Source: CommCare. N = [total consultations in dataset].*

---

## Page structure

### Section 0: Geographic overview

The opening visual. A bubble map showing where IRC health consultations are taking place across Peru, Ecuador, and Mexico. Sets the geographic scene before any clinical or demographic detail.

**Chart 0.1 — Consultation locations map**
Three country-level panels side by side — Peru, Ecuador, Mexico — each showing admin-level locations as proportional bubbles sized by consultation volume. Bubble colour follows the country palette. A small inset locator map of the Americas above or beside the three panels orients readers to the regional context.

For the MVP the map shows cumulative consultation volumes for the most recent 12 months rather than all-time totals, making it sensitive to where the programme is currently active. A caption notes the time window.

Location coordinates are drawn from a lookup table mapping CommCare location names to lat/long — this infrastructure already exists for Peru and Ecuador from prior clustering work and needs extending to Mexico only.

*R approach:* `geom_sf()` for country and admin-1 boundaries via `rnaturalearth`. `geom_point()` with `size = consultations` and `colour = country` for bubbles. `facet_wrap(~ country, ncol = 3)` with `coord_sf()` set per country panel. Output as SVG via `ggsave()`.

A second variable can be encoded in bubble colour in a future version — for example, ITS positivity rate or proportion of migrant clients — but for the MVP volume alone is sufficient.

---

### Section 1: Who we're reaching

The population entry point. Answers: how many people, who are they.

**Chart 1.1 — Consultations over time**
A single time series chart with three coloured lines, one per country. X axis: month. Y axis: consultation count. This is the first chart a reader sees and establishes scale and trajectory. If volumes are very different in magnitude across countries, use a log scale or facet — but try the single chart first.

*ggplot2 approach:* `geom_line() + geom_point()` with `colour = country`. Add a `geom_smooth()` if trends are noisy.

---

**Chart 1.2 — Sex breakdown**
Small multiples: three panels side by side, one per country. Each panel is a horizontal bar chart showing percentage of consultations by sex category (Mujer, Hombre, Intersexual, No responde/No desea responder). Bars within each panel are the same neutral grey — country colour is carried by the panel title or a small colour indicator, not the bars themselves, to avoid redundancy.

*ggplot2 approach:* `geom_col() + facet_wrap(~ country, ncol = 3) + coord_flip()`. Note in caption that this is sex not gender.

---

**Chart 1.3 — Age band distribution**
Small multiples, same three-panel structure. Each panel shows percentage of consultations by age band: 0–5, 6–11, 12–17, 18–49, 50+. Bars in country colour. A headline stat above the chart series: *"X% of clients across all three countries are under 18."*

*ggplot2 approach:* `geom_col() + facet_wrap(~ country, ncol = 3)`.

---

**Chart 1.4 — Migration profile**
This is one of the most programmatically significant charts. Small multiples, three panels. Each panel is a horizontal ranked bar chart showing population categories as a percentage of total clients. Categories vary slightly by country but map to a common set: Local/host community, Migrant (settled), Migrant (transit), Refugee/asylum seeker, Returnee/IDP, Deportado/retornado (Mexico only — appears in Mexico panel, absent from others with no placeholder needed).

*ggplot2 approach:* `geom_col() + facet_wrap(~ country, ncol = 3) + coord_flip()`. Rank bars within each panel by frequency using `reorder()`.

---

**Chart 1.5 — Ethnic profile (Peru and Ecuador only)**
Two panels side by side — Peru and Ecuador. Mexico is simply absent from this chart. A brief caption: *"Ethnic profile not collected in Mexico."* Categories: Mestizo, Indígena, Afrodescendiente, Caucásico, Sin autorreconocimiento, Otro. Horizontal ranked bars.

This chart carries particular significance for IRC's mandate around indigenous populations. A one-sentence callout above it notes what proportion of clients self-identify as indígena across both countries.

*ggplot2 approach:* Filter to Peru and Ecuador before plotting. `geom_col() + facet_wrap(~ country, ncol = 2) + coord_flip()`.

---

### Section 2: Clinical picture — primary care

Answers: what conditions are we seeing in primary care, do patterns differ across countries and demographic groups.

**Chart 2.1 — Top 10 APS diagnoses by country**
The core epidemiological chart. Three panels, one per country, each showing the top 10 ICD-10 diagnoses in that country ranked by frequency. Bars in country colour. ICD-10 label displayed, not code.

A brief analytical note below: one or two sentences observing the most notable similarities and differences across the three panels.

*ggplot2 approach:* `geom_col() + facet_wrap(~ country, ncol = 3, scales = "free_y") + coord_flip()`. Use `scales = "free_y"` because the ranking will differ across countries.

---

**Chart 2.2 — Top diagnoses by age band**
A `facet_grid` chart: age band on rows, country on columns. Each cell shows the top 5 diagnoses for that country/age band combination as a small horizontal bar chart. Five age bands × three countries = 15 panels. If this becomes unreadable, simplify to a written comparison note alongside a single-country view.

*ggplot2 approach:* `facet_grid(age_band ~ country, scales = "free")`. Use a small base font size.

---

**Chart 2.3 — Chronic disease prevalence**
Three panels, one per country. Horizontal bar chart of chronic conditions as percentage of all clients. Note that clients can have multiple conditions so bars sum to more than 100% — a caption clarifies this. Categories: Diabetes, Hipertensión, Cardiovascular, Respiratoria, Cáncer, Neurológica, Renal, Otras.

*ggplot2 approach:* `geom_col() + facet_wrap(~ country, ncol = 3) + coord_flip()`.

*Data status:* `patologias_cronicas` is currently blank for both Ecuador and Peru — an overly broad anonymisation pattern in `00_anonymise_epr.R` stripped this field. Fix is in place; re-running the anonymisation script will recover the data before building this chart.

---

### Section 3: Sexual and reproductive health

**Chart 3.1 — SSR service mix**
A single grouped or stacked bar chart with one bar per country showing the proportional breakdown of SSR service types: family planning, prenatal care, ITS/ETS, cancer screening (Peru/Ecuador only), VBG, counselling. Country on the x axis, proportion on the y axis, fill by service type. Uses a separate categorical colour palette for service type — country colours are not used here to avoid confusion.

*ggplot2 approach:* `geom_col(position = "fill") + scale_fill_brewer()`.

---

**Chart 3.2 — ITS/ETS testing and positivity**
A grid of small charts: three conditions (syphilis, HIV, Hepatitis B) × three countries. Each cell shows testing rate and positivity rate as a paired dot or bar. Mexico adds Hepatitis C as a fourth row.

A headline callout above: *"Syphilis positivity rate across all three countries: X%."*

*ggplot2 approach:* Reshape to long format with condition, country, metric as variables. `geom_point() + facet_grid(condition ~ country)` or `geom_col()` depending on what reads more clearly.

---

**Chart 3.3 — Family planning method mix (Peru and Ecuador only)**
Two panels. Horizontal bar chart of contraceptive methods: short-acting (ACOS, injectable, emergency contraception) and long-acting (IUD, implant). Caption: *"Family planning method detail not available for Mexico."*

*ggplot2 approach:* `geom_col() + facet_wrap(~ country, ncol = 2) + coord_flip()`.

*Data status:* `fp_corta` and `fp_larga` fields are consistently empty across the full EPR dataset. The FP method is likely stored under a different CommCare field name — requires investigation before this chart can be built. If the field cannot be located, this chart will be replaced with a stat callout showing total FP consultations only.

---

**Chart 3.4 — Prenatal care: age profile**
Three panels. Bar chart of pregnant clients by age band. Headline stat above: *"X% of pregnant clients across all three countries are under 18."* Under-18 bars highlighted in a distinct colour to draw the eye — this figure is relevant to both safeguarding and donor reporting.

*ggplot2 approach:* `geom_col() + facet_wrap(~ country, ncol = 3)`. Use `scale_fill_manual()` to highlight the under-18 bar.

---

**Chart 3.5 — CACU screening (Peru and Ecuador only)**
Two stat callouts rather than a chart: total clients screened for cervical cancer (IVAA + PAP combined) and IVAA positivity rate as a percentage. Presented as large numbers with labels, one pair per country. Caption: *"Cervical cancer screening not recorded in Mexico app."*

*Data status:* CACU/IVAA records appear only for Ecuador (15 records in full dataset). Peru shows zero records — either Peru does not run this service or the field name differs between country apps. Confirm with Peru health coordinator before publishing the Peru stat callout.

---

### Section 4: Mental health (Peru and Ecuador only)

Section header note: *"Mental health services are provided in Peru and Ecuador. This module is not currently part of the Mexico programme."*

**Chart 4.1 — Mental health service type**
Two panels. Bar chart of service types: individual single session, individual multi-session, first psychological aid (PAP), specialised referral, community-based.

*ggplot2 approach:* `geom_col() + facet_wrap(~ country, ncol = 2) + coord_flip()`.

---

**Chart 4.2 — Top mental health diagnoses**
Two panels. Top 10 ICD-10 mental health diagnoses ranked by frequency, country colour bars, free y scale.

*ggplot2 approach:* `geom_col() + facet_wrap(~ country, ncol = 2, scales = "free_y") + coord_flip()`.

---

**Chart 4.3 — Referral rate**
Two stat callouts: percentage of mental health clients referred externally, one per country.

---

### Section 5: Pharmaceutical dispensing (Mexico only)

Section header note: *"Pharmaceutical dispensing data is recorded in Mexico. This module is not part of the Peru or Ecuador apps."*

**Chart 5.1 — Top 15 products dispensed**
Single panel, Mexico only. Horizontal bar chart ranked by total units dispensed. Useful for supply chain visibility and as a proxy for what conditions are being treated in practice — the dispensing list is often more reliable than the diagnosis field for common presentations.

*ggplot2 approach:* `geom_col() + coord_flip()` with `reorder()`.

---

### Section 6: Equity lens

This section reframes selected indicators through the population comparison that is most distinctively IRC's analytical contribution. The question throughout is: do health patterns differ between migrant and local populations, and between ethnic groups?

**Chart 6.1 — Top diagnoses: migrant vs local**
A `facet_grid` chart: country on one axis, population group (migrant / local) on the other. Each cell shows top 5 diagnoses as a small horizontal bar. Six cells total. This is the single most analytically interesting chart in the dashboard.

*ggplot2 approach:* `facet_grid(population_group ~ country, scales = "free")`.

---

**Chart 6.2 — ITS positivity by population group**
Syphilis and HIV positivity rates broken down by migrant vs local, for each country. Peru and Ecuador add indigenous vs non-indigenous as an additional breakdown.

*ggplot2 approach:* `geom_point()` or `geom_col()`. `facet_wrap(~ country)`.

---

**Chart 6.3 — Proportion of pregnant clients under 18 by population group**
Three panels. For each country, a two-bar chart: proportion of pregnant clients under 18 for migrant clients vs local clients.

*ggplot2 approach:* `geom_col() + facet_wrap(~ country, ncol = 3)`.

---

### Section 7: Trends over time

The aggregate charts in sections 1–6 show the cumulative or period picture. This section surfaces change — what is moving, and in which direction. Each chart here is a time series, typically monthly, with one line per country.

The key question for each trend chart is not just whether something is changing but whether the change is meaningful given the underlying volumes. All trend charts should include a caption noting the N on which rates are based, particularly for smaller countries or service types.

**Chart 7.1 — Migration profile over time**
A faceted line chart: one panel per population category (migrant, local, refugee, etc.), each showing monthly count or proportion across all three countries as coloured lines. Reveals whether the composition of who is being reached is shifting — for instance, a rising share of transit migrants in Mexico, or a growing indigenous caseload in Ecuador.

*ggplot2 approach:* `geom_line() + facet_wrap(~ population_category)` with `colour = country`.

---

**Chart 7.2 — ITS positivity over time**
Monthly positivity rates for syphilis and HIV, one line per country. Presented as two side-by-side panels — one per condition. An uptick in positivity is an outbreak signal and the chart most likely to prompt clinical action.

*ggplot2 approach:* `geom_line() + geom_point() + facet_wrap(~ condition, ncol = 2)` with `colour = country`. Add a `geom_smooth()` to surface the underlying trend through monthly noise.

---

**Chart 7.3 — Top APS diagnosis trends**
Rather than trying to trend all diagnoses, select the five most frequent diagnoses across all three countries combined and show their monthly trajectory as a small multiple. One panel per diagnosis, three coloured lines per panel.

This chart will likely reveal seasonality — respiratory conditions peaking in winter months, for instance — which has operational implications for staffing and supplies.

*ggplot2 approach:* Filter to top 5 diagnoses. `geom_line() + facet_wrap(~ diagnosis, ncol = 3)` with `colour = country`.

---

**Chart 7.4 — Proportion of pregnant clients under 18 over time**
Monthly proportion of pregnant clients who are minors, one line per country. A flat or declining line is reassuring. A rising line is a safeguarding signal worth flagging to programme leadership.

*ggplot2 approach:* `geom_line() + geom_smooth()` with `colour = country`.

---

**Chart 7.5 — Mental health caseload over time (Peru and Ecuador only)**
Monthly mental health consultation volumes for Peru and Ecuador. Two coloured lines. Useful for understanding whether the mental health service is growing, stable, or declining — which matters for staffing and capacity planning.

*ggplot2 approach:* `geom_line() + geom_point()` filtered to Peru and Ecuador. Caption notes Mexico is absent.

---

## Visual summary

| Section | Charts | Countries |
|---|---|---|
| 0. Geographic overview | 1 | All three |
| 1. Who we're reaching | 5 | All three, with noted exceptions |
| 2. Clinical picture — APS | 3 | All three |
| 3. Sexual and reproductive health | 5 | All three, with noted exceptions |
| 4. Mental health | 3 | Peru, Ecuador only |
| 5. Pharmaceutical dispensing | 1 | Mexico only |
| 6. Equity lens | 3 | All three, with noted exceptions |
| 7. Trends over time | 5 | All three, with noted exceptions |
| **Total** | **26** | |

---

## Implementation status

Pipeline status as of April 2026. Ecuador and Peru data flows through the EPR pipeline (`01_pipeline_epr.R`); Mexico pipeline not yet built.

Legend: ✓ data ready · ⚠ data issue (see note) · ✗ pipeline pending · n/a not applicable to this country

| Chart | Ecuador | Peru | Mexico | Notes |
|---|---|---|---|---|
| **0.1** Map | ✓ | ✓ | ✗ | Mexico location lookup not yet built |
| **1.1** Consultations over time | ✓ | ✓ | ✗ | |
| **1.2** Sex breakdown | ✓ | ✓ | ✗ | |
| **1.3** Age bands | ✓ | ✓ | ✗ | |
| **1.4** Migration profile | ✓ | ✓ | ✗ | |
| **1.5** Ethnic profile | ✓ | ✓ | n/a | Not collected in Mexico app |
| **2.1** Top 10 APS diagnoses | ✓ | ✓ | ✗ | |
| **2.2** Diagnoses by age band | ✓ | ✓ | ✗ | |
| **2.3** Chronic disease prevalence | ⚠ | ⚠ | ✗ | `patologias_cronicas` blank — re-run `00_anonymise_epr.R` to recover |
| **3.1** SSR service mix | ✓ | ✓ | ✗ | |
| **3.2** ITS testing & positivity | ✓ | ✓ | ✗ | |
| **3.3** FP method mix | ⚠ | ⚠ | n/a | `fp_corta`/`fp_larga` fields consistently empty — field name likely differs in CommCare |
| **3.4** Prenatal age profile | ✓ | ✓ | ✗ | |
| **3.5** CACU screening | ✓ | ⚠ | n/a | Only 15 Ecuador records; Peru shows 0 — may not run this service or field name differs |
| **4.1** MH service type | ✓ | ✓ | n/a | |
| **4.2** Top MH diagnoses | ✓ | ✓ | n/a | |
| **4.3** MH referral rate | ✓ | ✓ | n/a | |
| **5.1** Pharma dispensing | n/a | n/a | ✗ | Mexico pipeline pending |
| **6.1** Diagnoses: migrant vs local | ✓ | ✓ | ✗ | |
| **6.2** ITS by population group | ✓ | ✓ | ✗ | |
| **6.3** Pregnant <18 by group | ✓ | ✓ | ✗ | |
| **7.1** Migration profile over time | ✓ | ✓ | ✗ | |
| **7.2** ITS positivity over time | ✓ | ✓ | ✗ | |
| **7.3** Top APS diagnosis trends | ✓ | ✓ | ✗ | |
| **7.4** Pregnant <18 over time | ✓ | ✓ | ✗ | |
| **7.5** MH caseload over time | ✓ | ✓ | n/a | |

**20 of 26 charts have data ready for at least one country.** 3 charts have known data gaps in the EPR pipeline (2.3, 3.3, 3.5-Peru). 13 charts are waiting on the Mexico pipeline.

---

## Key findings from initial data exploration (EPR, full dataset)

These findings emerged during pipeline development and should inform the analytical narrative in the dashboard. They are not exhaustive — they are the patterns that stood out most clearly and are worth highlighting as callouts or caption text.

**Population profile**
- Ecuador: 77% of clients are *poblacion acogida* (host community). Peru: 69% are *migrante en tránsito* (transit migrants). This is the single most striking programmatic contrast between the two countries and should be front-and-centre in Chart 1.4 and Section 6.
- Ecuador's client composition reflects a settled, community-based programme. Peru's reflects a transit corridor — different service implications entirely.

**Sexual health**
- Syphilis positivity: Peru 5.9% vs Ecuador 1.8%. A clinically and programmatically significant difference. Worth a headline callout in Chart 3.2.
- HIV positivity data available; Hepatitis B data available. To be verified against expected ranges before publishing.

**APS diagnoses**
- Ecuador top diagnoses: parasitosis (B82.9), UTI (N39.0), common cold (J00).
- Peru top diagnoses: child health check (Z00.1), common cold (J00), headache (R51), pharyngitis, lumbago.
- The prominence of Z00.1 in Peru reflects a different service model — more child health checks relative to presenting complaints. Note this contrast in the Chart 2.1 analytical note.

**Data quality flag**
- Ecuador November 2025: 921 consultations vs ~400–600 in surrounding months. Possible data entry spike or import artefact. Investigate before publishing trend charts — this will be visually prominent in Charts 1.1, 7.1, 7.2, 7.3.

---

## Methodology note (page footer)

A short paragraph covering: data source (CommCare, IRC Latin America health programmes); what a consultation represents in each country app; the repeat-group structure in Mexico vs the service-form structure in Peru/Ecuador and how these were harmonised; the location lookup table and its provenance; the 12-month rolling window used for the map; and the aggregation approach (no patient-level data is stored or transmitted — all charts reflect pre-aggregated counts and rates).

**Known limitations to include explicitly:**
- Nutrition treatment cascade not recorded in any country app.
- Mental health consultation reasons are free text and not analysed in this version.
- Ethnic profile not collected in Mexico app.
- ICD-10 option lists may differ between country apps and have been harmonised where possible (uppercase, trailing X stripped).
- Family planning method (`fp_corta`/`fp_larga`) fields are empty in the EPR dataset — FP consultations are counted in the SSR service mix but method breakdown is not available pending field-name investigation.
- CACU/IVAA screening records appear only for Ecuador in the current dataset (15 records). Peru data is absent — cause unconfirmed.
- `patologias_cronicas` (chronic conditions) requires a pipeline re-run to populate; currently blank due to a since-fixed anonymisation issue.
- Ecuador November 2025 shows an anomalous spike in consultation volume (921 vs ~400–600 surrounding months) — under investigation.
- Migration profile label `migrante_con_vocación_de_permanencia` has an encoding issue (ó dropped by CommCare export); stored as-is, displayed with corrected accent in charts.

---

## Build notes for Quarto

- One `.qmd` file per section combined via `_quarto.yml`, or one long `.qmd` if simpler.
- Data loaded from pre-aggregated CSV or JSON files produced by the pipeline script. No patient-level data in the repo.
- A `data/last_updated.txt` file written by the pipeline and read by Quarto to populate the freshness note.
- Charts rendered at build time as SVG via `fig-format: svg` in YAML front matter — crisper than PNG on high-density screens.
- `fig-width` and `fig-height` set per chart block to control aspect ratios, particularly for the small multiple grids.
- A shared custom ggplot2 theme function sets consistent typography, background colour, and gridline style across all charts.
- Location data for the map lives in a separate `data/locations.csv` with columns: `location_name`, `country`, `lat`, `lon`. This file is static and maintained manually — it does not need to be regenerated by the pipeline on each run.
- Trend charts use the full time-series export from CommCare. Aggregate charts use a summary table. These are two separate pipeline outputs.

---

*Spec version 2.1 — April 2026. Prepared for IRC Latin America health programme. Updated with implementation status table, known data gaps, and initial data exploration findings.*
