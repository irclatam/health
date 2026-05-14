# 01_pipeline_mx.R
# Mexico — transform anonymised CommCare export into pre-aggregated tables.
# Outputs go to data/mx/; 02_combine.R binds these with EPR outputs.
#
# Input:  data_anonymised/mexico_historia_clean.csv  (one row per consultation)
# Source: SALUD Registro Consultas (MX) - SALUD V2 - Historia Clínica form export
#
# What Mexico CAN produce (vs EPR):
#   ✓ Monthly consultations, sex/age breakdown, age-sex pyramid
#   ✓ APS diagnoses, APS trend (bump chart)
#   ✓ SSR service mix, family planning
#   ✓ Chronic conditions (enfermedad_cronica multi-select)
#   ✓ Location (city — all Ciudad Juárez currently)
#   ✓ Pharmaceutical dispensing (Mexico-specific, not in EPR)
#   ✗ Migration / equity analysis (no population group field)
#   ✗ Mental health (no MH module)
#   ✗ Ethnicity / nationality (not collected)
#   ✗ ITS serology results (no test result fields in this export)

library(tidyverse)
library(janitor)

# ── Helpers ───────────────────────────────────────────────────────────────────

age_band <- function(age) {
  case_when(
    age > 100 ~ NA_character_,
    age < 6   ~ "0-5",
    age < 12  ~ "6-11",
    age < 18  ~ "12-17",
    age < 50  ~ "18-49",
    age >= 50 ~ "50+",
    TRUE      ~ NA_character_
  )
}

age_band_5yr <- function(age) {
  case_when(
    age > 100 ~ NA_character_,
    age <  5  ~ "0-4",
    age < 10  ~ "5-9",
    age < 15  ~ "10-14",
    age < 20  ~ "15-19",
    age < 25  ~ "20-24",
    age < 30  ~ "25-29",
    age < 35  ~ "30-34",
    age < 40  ~ "35-39",
    age < 45  ~ "40-44",
    age < 50  ~ "45-49",
    age < 55  ~ "50-54",
    age < 60  ~ "55-59",
    age < 65  ~ "60-64",
    age >= 65 ~ "65+",
    TRUE      ~ NA_character_
  )
}

normalise_cie10 <- function(code) {
  code %>% str_to_upper() %>% str_remove("X$")
}

dx_group <- function(code) {
  ch <- str_sub(code, 1, 1)
  case_when(
    ch %in% c("A", "B")              ~ "Infectious & parasitic",
    ch == "C"                         ~ "Cancer",
    ch == "D"                         ~ "Blood & neoplasms",
    ch == "E"                         ~ "Endocrine & metabolic",
    ch == "F"                         ~ "Mental health",
    ch == "G"                         ~ "Neurological",
    ch == "H"                         ~ "Eye & ENT",
    ch == "I"                         ~ "Cardiovascular",
    ch == "J"                         ~ "Respiratory",
    ch == "K"                         ~ "Digestive",
    ch == "L"                         ~ "Skin",
    ch == "M"                         ~ "Musculoskeletal",
    ch == "N"                         ~ "Genitourinary",
    ch == "O"                         ~ "Obstetric",
    ch == "R"                         ~ "Symptoms & signs",
    ch %in% c("S","T","V","W","X","Y") ~ "Injury & trauma",
    ch == "Z"                         ~ "Preventive & check-up",
    TRUE                              ~ "Other"
  )
}

write_agg <- function(df, filename) {
  dir.create("data/mx", showWarnings = FALSE)
  path <- file.path("data/mx", filename)
  write_csv(df, path)
  cat("Written:", path, "(", nrow(df), "rows )\n")
}

parse_code  <- function(x) {
  x <- if_else(str_detect(coalesce(x, ""), "^-+$"), NA_character_, x)
  normalise_cie10(str_extract(x, "^[^_]+"))
}
parse_label <- function(x) {
  x <- if_else(str_detect(coalesce(x, ""), "^-+$"), NA_character_, x)
  str_remove(x, "^[^_]+_") %>% str_replace_all("_", " ") %>% str_to_sentence()
}

# ── Load ──────────────────────────────────────────────────────────────────────

mex_raw <- read_csv("data_anonymised/mexico_historia_clean.csv", show_col_types = FALSE,
                    col_types = cols(.default = col_character()))

cat("Historia loaded:", nrow(mex_raw), "rows,", ncol(mex_raw), "cols\n")

# Join migration profile + nationality from health_case export
mex_cases <- read_csv("data_anonymised/mexico_cases_clean.csv", show_col_types = FALSE,
                      col_types = cols(.default = col_character())) %>%
  select(case_id, perfil_migratorio, nacionalidad, deportado,
         discapacidad, estado, pais, ciudad, fecha_registro)

cat("Cases loaded:", nrow(mex_cases), "rows\n")
cat("Historia rows matching a case:",
    sum(mex_raw$case_id %in% mex_cases$case_id), "/", nrow(mex_raw), "\n\n")

# ── Client-level demographics from cases (full coverage: n = 2,010) ───────────
# The cases export and the historia export have largely disjoint case IDs, so
# these aggregations are built directly from the cases file rather than via the
# historia join (which only covers ~14% of rows).

clean_str <- function(x) if_else(is.na(x) | x == "NA" | str_detect(x, "^-+$"), NA_character_, x)

agg_migration_profile <- mex_cases %>%
  transmute(country = "mexico",
            migration_profile = clean_str(str_to_lower(perfil_migratorio))) %>%
  filter(!is.na(migration_profile), migration_profile != "prefiere_no_responder") %>%
  count(country, migration_profile) %>%
  mutate(pct = n / sum(n)) %>%
  arrange(desc(n))

write_agg(agg_migration_profile, "agg_migration_profile.csv")

agg_nationality <- mex_cases %>%
  transmute(country = "mexico",
            nacionalidad = clean_str(str_to_lower(nacionalidad))) %>%
  filter(!is.na(nacionalidad), nacionalidad != "nationality_other") %>%
  count(country, nacionalidad) %>%
  mutate(pct = n / sum(n)) %>%
  arrange(desc(n))

write_agg(agg_nationality, "agg_nationality.csv")

agg_location_consultations <- mex_cases %>%
  transmute(country = "mexico", municipio = clean_str(ciudad)) %>%
  filter(!is.na(municipio)) %>%
  count(country, municipio, name = "n_clients") %>%
  arrange(country, desc(n_clients))

write_agg(agg_location_consultations, "agg_location_consultations.csv")

mex_raw <- mex_raw %>%
  left_join(mex_cases, by = "case_id")

rm(mex_cases)

mex <- mex_raw %>%
  mutate(
    country    = "mexico",
    year_month = if_else(
      is.na(fecha_atencion) | fecha_atencion == "NA",
      substr(completed_time, 1, 7),
      as.character(fecha_atencion)
    ),
    edad       = as.numeric(edad),
    age_band   = age_band(edad),
    age_5yr    = age_band_5yr(edad),
    sexo = case_when(
      str_to_lower(sexo) == "hombre"      ~ "H",
      str_to_lower(sexo) == "mujer"       ~ "M",
      str_to_lower(sexo) == "intersexual" ~ "I",
      is.na(sexo)                         ~ NA_character_,
      TRUE                                ~ "Otro"
    ),
    city = case_when(
      city == "ciudad_de_mxico"  ~ "Ciudad de México",
      city == "ciudad_jurez"     ~ "Ciudad Juárez",
      city == "ciudad_juarez"    ~ "Ciudad Juárez",
      str_detect(coalesce(city, ""), "^-+$") ~ NA_character_,
      TRUE ~ city
    ),
    perfil_migratorio = str_to_lower(coalesce(perfil_migratorio, "")),
    perfil_migratorio = if_else(perfil_migratorio == "", NA_character_, perfil_migratorio),
    servicio     = if_else(str_detect(coalesce(servicio, ""), "^-+$"), NA_character_, servicio),
    ssr_tipo     = if_else(str_detect(coalesce(ssr_tipo, ""), "^-+$"), NA_character_, ssr_tipo),
    has_aps      = str_detect(coalesce(servicio, ""), "atencion_primaria_de_salud"),
    has_ssr      = str_detect(coalesce(servicio, ""), "salud_sexual_y_reproductiva"),
    ssr_tipo_std = str_replace_all(coalesce(ssr_tipo, ""), "ets", "its"),
    dx_aps_code  = parse_code(dx_aps),
    dx_aps_label = parse_label(dx_aps),
    dx_sti_code  = parse_code(dx_sti),
    dx_sti_label = parse_label(dx_sti),
    dx_fp_code   = parse_code(dx_fp),
    dx_fp_label  = parse_label(dx_fp)
  )

rm(mex_raw)

cat("Service mix:\n"); print(table(mex$servicio, useNA = "ifany"))
cat("\nSSR types:\n");  print(table(mex$ssr_tipo,  useNA = "ifany"))
cat("\n")

# ── APS long format ───────────────────────────────────────────────────────────

mex_aps_long <- mex %>%
  filter(!is.na(dx_aps_code)) %>%
  mutate(diagnosis_group = dx_group(dx_aps_code)) %>%
  select(country, year_month, age_band, perfil_migratorio,
         diagnosis_code  = dx_aps_code,
         diagnosis_label = dx_aps_label,
         diagnosis_group)

cat("APS diagnoses:", nrow(mex_aps_long), "rows with a code\n\n")

# ── Section 1: Who we're reaching ─────────────────────────────────────────────

agg_monthly_consultations <- mex %>%
  filter(!is.na(year_month)) %>%
  count(country, year_month, name = "n_consultations")

write_agg(agg_monthly_consultations, "agg_monthly_consultations.csv")

agg_sex_breakdown <- mex %>%
  filter(!is.na(sexo)) %>%
  count(country, sex = sexo) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

write_agg(agg_sex_breakdown, "agg_sex_breakdown.csv")

agg_age_breakdown <- mex %>%
  filter(!is.na(age_band)) %>%
  count(country, age_band) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

write_agg(agg_age_breakdown, "agg_age_breakdown.csv")

mex_mf_totals <- mex %>%
  filter(sexo %in% c("H", "M"), !is.na(edad)) %>%
  count(country, name = "total_mf")

agg_age_sex_pyramid <- mex %>%
  filter(sexo %in% c("H", "M"), !is.na(edad), !is.na(age_5yr)) %>%
  count(country, sexo, age_5yr) %>%
  left_join(mex_mf_totals, by = "country") %>%
  mutate(pct = n / total_mf) %>%
  select(-total_mf)

write_agg(agg_age_sex_pyramid, "agg_age_sex_pyramid.csv")

mex_svc_counts <- mex %>%
  filter(!is.na(case_id)) %>%
  count(country, case_id, name = "n_services")

agg_services_per_client <- mex_svc_counts %>%
  mutate(n_services_band = case_when(
    n_services == 1  ~ "1",
    n_services == 2  ~ "2",
    n_services == 3  ~ "3",
    n_services <= 5  ~ "4-5",
    n_services <= 10 ~ "6-10",
    TRUE             ~ "11+"
  )) %>%
  count(country, n_services_band) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

write_agg(agg_services_per_client, "agg_services_per_client.csv")

agg_services_per_client_summary <- mex_svc_counts %>%
  group_by(country) %>%
  summarise(
    n_clients       = n(),
    mean_services   = round(mean(n_services), 1),
    pct_one_service = mean(n_services == 1),
    .groups         = "drop"
  )

write_agg(agg_services_per_client_summary, "agg_services_per_client_summary.csv")


# ── Section 2: APS clinical picture ───────────────────────────────────────────

agg_aps_diagnoses <- mex_aps_long %>%
  count(country, diagnosis_code, diagnosis_label, diagnosis_group) %>%
  arrange(country, desc(n))

write_agg(agg_aps_diagnoses, "agg_aps_diagnoses.csv")

agg_aps_diagnoses_grouped <- mex_aps_long %>%
  count(country, diagnosis_group) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup() %>%
  arrange(country, desc(n))

write_agg(agg_aps_diagnoses_grouped, "agg_aps_diagnoses_grouped.csv")

agg_aps_by_age <- mex_aps_long %>%
  filter(!is.na(age_band)) %>%
  count(country, age_band, diagnosis_code, diagnosis_label) %>%
  group_by(country, age_band) %>%
  slice_max(n, n = 5) %>%
  ungroup() %>%
  arrange(country, age_band, desc(n))

write_agg(agg_aps_by_age, "agg_aps_by_age.csv")

mex_top5 <- mex_aps_long %>%
  count(diagnosis_code, diagnosis_label) %>%
  slice_max(n, n = 5) %>%
  pull(diagnosis_code)

agg_aps_trend_ctry <- mex_aps_long %>%
  filter(!is.na(year_month), diagnosis_code %in% mex_top5) %>%
  count(country, year_month, diagnosis_code, diagnosis_label)

write_agg(agg_aps_trend_ctry, "agg_aps_trend_ctry.csv")

mex_chronic_base <- mex %>%
  filter(!is.na(enfermedad_cronica)) %>%
  count(country, name = "n_with_data")

agg_chronic_conditions <- mex %>%
  filter(!is.na(enfermedad_cronica)) %>%
  separate_longer_delim(enfermedad_cronica, delim = " ") %>%
  filter(enfermedad_cronica != "ninguna", enfermedad_cronica != "") %>%
  count(country, condition = enfermedad_cronica) %>%
  left_join(mex_chronic_base, by = "country") %>%
  mutate(pct = n / n_with_data) %>%
  arrange(country, desc(n))

write_agg(agg_chronic_conditions, "agg_chronic_conditions.csv")

# ── Section 3: Sexual and reproductive health ──────────────────────────────────

agg_ssr_service_mix <- mex %>%
  filter(has_ssr, ssr_tipo_std != "") %>%
  separate_longer_delim(ssr_tipo_std, delim = " ") %>%
  filter(ssr_tipo_std != "") %>%
  count(country, ssr_tipo = ssr_tipo_std) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup() %>%
  arrange(country, desc(n))

write_agg(agg_ssr_service_mix, "agg_ssr_service_mix.csv")

agg_fp_methods <- mex %>%
  filter(!is.na(dx_fp_code)) %>%
  count(country, diagnosis_code = dx_fp_code, diagnosis_label = dx_fp_label) %>%
  arrange(country, desc(n))

write_agg(agg_fp_methods, "agg_fp_methods.csv")

agg_pharma <- mex %>%
  filter(!is.na(pharma_dispensed), pharma_dispensed != "") %>%
  separate_longer_delim(pharma_dispensed, delim = " ") %>%
  filter(pharma_dispensed != "", !str_detect(pharma_dispensed, "^-+$")) %>%
  count(country, product = pharma_dispensed) %>%
  arrange(country, desc(n))

write_agg(agg_pharma, "agg_pharma_dispensed.csv")

# ── Sankey inputs ─────────────────────────────────────────────────────────────

mex_aps_sankey <- mex %>%
  filter(has_aps) %>%
  transmute(country, service = "aps",
            sub_service = if_else(
              str_detect(ssr_tipo_std, "prenatal"),
              "atencion_preventiva", "atencion_recuperativa"
            ))

mex_ssr_sankey <- mex %>%
  filter(has_ssr, ssr_tipo_std != "") %>%
  mutate(sub_service = word(ssr_tipo_std, 1)) %>%
  transmute(country, service = "ssr", sub_service)

agg_service_sankey <- bind_rows(mex_aps_sankey, mex_ssr_sankey) %>%
  count(country, service, sub_service) %>%
  arrange(service, sub_service)

write_agg(agg_service_sankey, "agg_service_sankey.csv")

cat("\nMexico pipeline done.\n")
