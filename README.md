# IRC Latin America — Health Services Dashboard

A Quarto-based dashboard tracking health service delivery across IRC's Latin America programmes in Ecuador, Peru, and Mexico.

**Live site:** [irclatam.github.io/health](https://irclatam.github.io/health)

---

## What it shows

- Caseload trends and client demographics across three countries
- Primary care and mental health diagnosis profiles
- Sexual and reproductive health outcomes
- Equity comparisons between host community and migrant/refugee clients
- Pharmaceutical dispensing (Mexico only)

---

## Repository structure

```
index.qmd                 — Quarto source for the dashboard
_quarto.yml               — Site configuration
styles.css                — Custom CSS
scripts/
  theme_irc.R             — ggplot2 theme and colour palette
  01_pipeline_epr.R       — Aggregation pipeline for Ecuador & Peru
  01_pipeline_mx.R        — Aggregation pipeline for Mexico
  02_combine.R            — Combines EPR and Mexico aggregates
  run_all.R               — Runs full pipeline in sequence
docs/                     — Rendered HTML (served by GitHub Pages)
```

---

## Data

Source data is drawn from IRC's CommCare health information system. Raw exports and anonymised data files are **not committed** to this repository. The `data/` and `data_anonymised/` folders are gitignored and exist only on authorised local machines.

The pipeline scripts (`01_pipeline_*.R`, `02_combine.R`) read from `data_anonymised/` and write aggregated, non-identifiable summary tables to `data/`. The dashboard reads only from `data/`.

---

## Contact

- **Philip Blue**, Regional Measurement Adviser, Latin America — [philip.blue@rescue.org](mailto:philip.blue@rescue.org)
- **Bibiana Wanger**, Health Technical Adviser
