# 02_combine.R
# Merge pre-aggregated EPR (Ecuador / Peru) and Mexico outputs into
# unified tables for the dashboard.
#
# Reads:  data/      — EPR pipeline outputs  (01_pipeline_epr.R)
#         data/mx/   — Mexico pipeline outputs (01_pipeline_mx.R)
# Writes: data/combined/ — three-country merged tables

library(tidyverse)

dir.create("data/combined", showWarnings = FALSE)

# ── Helper ────────────────────────────────────────────────────────────────────

dx_group <- function(code) {
  ch <- str_sub(code, 1, 1)
  case_when(
    ch %in% c("A", "B")               ~ "Infectious & parasitic",
    ch == "C"                          ~ "Cancer",
    ch == "D"                          ~ "Blood & neoplasms",
    ch == "E"                          ~ "Endocrine & metabolic",
    ch == "F"                          ~ "Mental health",
    ch == "G"                          ~ "Neurological",
    ch == "H"                          ~ "Eye & ENT",
    ch == "I"                          ~ "Cardiovascular",
    ch == "J"                          ~ "Respiratory",
    ch == "K"                          ~ "Digestive",
    ch == "L"                          ~ "Skin",
    ch == "M"                          ~ "Musculoskeletal",
    ch == "N"                          ~ "Genitourinary",
    ch == "O"                          ~ "Obstetric",
    ch == "R"                          ~ "Symptoms & signs",
    ch %in% c("S","T","V","W","X","Y") ~ "Injury & trauma",
    ch == "Z"                          ~ "Preventive & check-up",
    TRUE                               ~ "Other"
  )
}

write_combined <- function(df, filename) {
  path <- file.path("data/combined", filename)
  write_csv(df, path)
  cat("Written:", path, "(", nrow(df), "rows )\n")
}

# ── Direct bind: tables with identical schemas ─────────────────────────────────

simple_bind <- function(epr_file, mx_file = epr_file) {
  bind_rows(
    read_csv(file.path("data",      epr_file), show_col_types = FALSE),
    read_csv(file.path("data/mx",   mx_file),  show_col_types = FALSE)
  )
}

agg_monthly_consultations <- simple_bind("agg_monthly_consultations.csv")
write_combined(agg_monthly_consultations, "agg_monthly_consultations.csv")

agg_sex_breakdown <- simple_bind("agg_sex_breakdown.csv")
write_combined(agg_sex_breakdown, "agg_sex_breakdown.csv")

agg_age_breakdown <- simple_bind("agg_age_breakdown.csv")
write_combined(agg_age_breakdown, "agg_age_breakdown.csv")

agg_age_sex_pyramid <- simple_bind("agg_age_sex_pyramid.csv")
write_combined(agg_age_sex_pyramid, "agg_age_sex_pyramid.csv")

agg_location_consultations <- simple_bind("agg_location_consultations.csv")
write_combined(agg_location_consultations, "agg_location_consultations.csv")

agg_aps_by_age <- simple_bind("agg_aps_by_age.csv")
write_combined(agg_aps_by_age, "agg_aps_by_age.csv")

agg_aps_trend_ctry <- simple_bind("agg_aps_trend_ctry.csv")
write_combined(agg_aps_trend_ctry, "agg_aps_trend_ctry.csv")

agg_chronic_conditions <- simple_bind("agg_chronic_conditions.csv")
write_combined(agg_chronic_conditions, "agg_chronic_conditions.csv")

agg_ssr_service_mix <- simple_bind("agg_ssr_service_mix.csv")
write_combined(agg_ssr_service_mix, "agg_ssr_service_mix.csv")

agg_service_sankey <- simple_bind("agg_service_sankey.csv")
write_combined(agg_service_sankey, "agg_service_sankey.csv")

agg_services_per_client <- simple_bind("agg_services_per_client.csv")
write_combined(agg_services_per_client, "agg_services_per_client.csv")

agg_services_per_client_summary <- simple_bind("agg_services_per_client_summary.csv")
write_combined(agg_services_per_client_summary, "agg_services_per_client_summary.csv")

agg_migration_profile <- simple_bind("agg_migration_profile.csv")
write_combined(agg_migration_profile, "agg_migration_profile.csv")

agg_nationality <- simple_bind("agg_nationality.csv")
write_combined(agg_nationality, "agg_nationality.csv")

# ── APS diagnoses: add diagnosis_group to EPR, then combine ───────────────────
# EPR pipeline does not produce diagnosis_group; derive it here from ICD code.

agg_aps_diagnoses <- bind_rows(
  read_csv("data/agg_aps_diagnoses.csv", show_col_types = FALSE) %>%
    mutate(diagnosis_group = dx_group(diagnosis_code)),
  read_csv("data/mx/agg_aps_diagnoses.csv", show_col_types = FALSE)
) %>%
  arrange(country, desc(n))

write_combined(agg_aps_diagnoses, "agg_aps_diagnoses.csv")

# ICD chapter rollup — the cross-country comparison
agg_aps_diagnoses_grouped <- agg_aps_diagnoses %>%
  count(country, diagnosis_group, wt = n, name = "n") %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup() %>%
  arrange(country, desc(n))

write_combined(agg_aps_diagnoses_grouped, "agg_aps_diagnoses_grouped.csv")

# ── Cross-country diagnosis comparison ────────────────────────────────────────

cat("\n── APS diagnosis mix by ICD chapter (% of coded consultations) ──────────\n\n")

agg_aps_diagnoses_grouped %>%
  mutate(pct_fmt = scales::percent(pct, accuracy = 0.1)) %>%
  select(diagnosis_group, country, pct_fmt) %>%
  pivot_wider(names_from = country, values_from = pct_fmt, values_fill = "—") %>%
  arrange(diagnosis_group) %>%
  print(n = Inf)

cat("\n── Top 10 diagnoses per country ─────────────────────────────────────────\n")

agg_aps_diagnoses %>%
  group_by(country) %>%
  slice_max(n, n = 10) %>%
  select(country, diagnosis_code, diagnosis_label, diagnosis_group, n) %>%
  print(n = Inf)

cat("\n── Diagnoses present in Mexico but not Ecuador or Peru ──────────────────\n")

epr_codes <- agg_aps_diagnoses %>% filter(country != "mexico") %>% pull(diagnosis_code) %>% unique()
mex_codes <- agg_aps_diagnoses %>% filter(country == "mexico")  %>% pull(diagnosis_code) %>% unique()

agg_aps_diagnoses %>%
  filter(country == "mexico", !diagnosis_code %in% epr_codes) %>%
  arrange(desc(n)) %>%
  select(diagnosis_code, diagnosis_label, diagnosis_group, n) %>%
  print(n = Inf)

cat("\n── Diagnoses present in Ecuador/Peru but not Mexico ─────────────────────\n")

agg_aps_diagnoses %>%
  filter(country != "mexico", !diagnosis_code %in% mex_codes) %>%
  count(diagnosis_code, diagnosis_label, diagnosis_group, wt = n, name = "n") %>%
  arrange(desc(n)) %>%
  print(n = 20)

cat("\nCombine done.\n")
