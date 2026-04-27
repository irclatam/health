# 01_pipeline_epr.R
# Ecuador-Peru Response — transform anonymised CommCare exports into
# pre-aggregated tables for the health dashboard. All outputs go to data/.
# Country is derived from ubicacion_1_etiqueta; both countries run in one pass.
#
# Inputs (data_anonymised/):
#   ecuador_registro_clean.csv         — one row per client registration
#   ecuador_servicios_cases_clean.csv  — one row per individual service (case export)
#   ecuador_historia_clinica_clean.csv — one row per clinical record
#
# Outputs (data/):
#   agg_monthly_consultations.csv  — Chart 1.1
#   agg_sex_breakdown.csv          — Chart 1.2
#   agg_age_breakdown.csv          — Chart 1.3 headline stat (broad bands, under-18 %)
#   agg_age_sex_pyramid.csv        — Chart 1.3 pyramid (5-year bands × sex)
#   agg_migration_profile.csv      — Chart 1.4
#   agg_ethnic_profile.csv         — Chart 1.5
#   agg_nationality.csv            — Chart 1.6
#   agg_services_per_client.csv    — Chart 1.7 distribution
#   agg_services_per_client_summary.csv — Chart 1.7 headline stats
#   agg_aps_diagnoses.csv          — Chart 2.1
#   agg_aps_by_age.csv             — Chart 2.2
#   agg_chronic_conditions.csv     — Chart 2.3
#   agg_aps_trend.csv              — Chart 7.3
#   agg_ssr_service_mix.csv        — Chart 3.1
#   agg_its_results.csv            — Chart 3.2
#   agg_its_by_month.csv           — Chart 7.2
#   agg_fp_methods.csv             — Chart 3.3
#   agg_cacu_screening.csv         — Chart 3.5
#   agg_prenatal_age.csv           — Chart 3.4
#   agg_mh_service_type.csv        — Chart 4.1
#   agg_mh_diagnoses.csv           — Chart 4.2
#   agg_referrals.csv              — Chart 4.3
#   agg_equity_diagnoses.csv       — Chart 6.1
#   agg_its_by_population.csv      — Chart 6.2
#   agg_migration_by_month.csv     — Chart 7.1
#   agg_mh_by_month.csv            — Chart 7.5

library(tidyverse)
library(janitor)

# ── Constants ─────────────────────────────────────────────────────────────────

PROJECT_START    <- as.Date("2024-06-01")  # earliest plausible service/registration date
SVC_MAX_LAG_DAYS <- 90L                    # max days between manual service date and form submission

# ── Helpers ───────────────────────────────────────────────────────────────────

na_dashes <- function(df) {
  df %>% mutate(across(where(is.character), ~ na_if(.x, "---")))
}

age_band <- function(age) {
  case_when(
    age > 100 ~ NA_character_,
    age < 6   ~ "0-5",
    age < 12  ~ "6-11",
    age < 18  ~ "12-17",
    age < 50  ~ "18-49",
    age >= 50 ~ "50+",
    .default  = NA_character_
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
    .default  = NA_character_
  )
}

# Normalise CommCare ICD-10 codes: uppercase, strip trailing X.
# "j00x" -> "J00", "n390" -> "N390"
normalise_cie10 <- function(code) {
  code %>% str_to_upper() %>% str_remove("X$")
}

write_agg <- function(df, filename) {
  path <- file.path("data", filename)
  write_csv(df, path)
  cat("Written:", path, "(", nrow(df), "rows )\n")
}

# ── Pre-load: validated service date lookup from form export ──────────────────
# The service case export uses opened_date (CommCare system timestamp), which
# reflects when the form was submitted rather than when the service occurred.
# The form export contains a manually-entered fecha_de_atencion that is closer
# to the true service date. We validate it (within project dates, lag ≤ 90 days
# before submission) and build a (client_id × submission_date) lookup used to
# enrich both service_date_validated and reg_date_validated below.

svc_form_date_lookup <- read_csv("data_anonymised/ecuador_servicios_clean.csv", show_col_types = FALSE) %>%
  na_dashes() %>%
  clean_names() %>%
  transmute(
    client_id    = form_case_case_id,
    form_date    = as.Date(substr(completed_time, 1, 10)),
    fecha_manual = suppressWarnings(as.Date(form_agregar_servicios_inicio_servicios_fecha_de_atencion)),
    lag          = as.numeric(form_date - fecha_manual)
  ) %>%
  filter(
    !is.na(fecha_manual),
    fecha_manual >= PROJECT_START,
    lag >= 0L,
    lag <= SVC_MAX_LAG_DAYS
  ) %>%
  group_by(client_id, form_date) %>%
  summarise(svc_date_validated = min(fecha_manual), .groups = "drop")

cat("Service date lookup:", nrow(svc_form_date_lookup), "client-days with valid manual dates\n")

# ── Load: Registro de Cliente ─────────────────────────────────────────────────

registro_raw <- read_csv("data_anonymised/ecuador_registro_clean.csv", show_col_types = FALSE) %>%
  na_dashes() %>%
  clean_names()

registro <- registro_raw %>%
  select(
    case_id = case_id,
    fecha_registro = fecha_de_registro,
    reg_system = completed_time,
    sexo,
    edad = cliente_edad,
    perfil_migratorio,
    etnia_ecu = perfil_etnico_ecu,
    etnia_per = perfil_etnico_per,
    ubicacion = ubicacion_1_etiqueta,
    municipio = ubicacion_3_etiqueta,
    discapacidad,
    vulnerabilidad = condiciones_de_vulnerabilidad,
    nacionalidad   = nacionalidad_cliente
  ) %>%
  mutate(
    country = str_to_lower(ubicacion),
    fecha_registro = as.Date(fecha_registro),
    reg_system = as.Date(substr(reg_system, 1, 10)),
    year_month = format(fecha_registro, "%Y-%m"),
    edad = as.numeric(edad),
    age_band = age_band(edad),
    etnia = coalesce(str_to_lower(etnia_ecu), str_to_lower(etnia_per)),
    perfil_migratorio = str_to_lower(perfil_migratorio) %>%
      str_replace_all("[áà]", "a") %>% str_replace_all("[éè]", "e") %>%
      str_replace_all("[íì]", "i") %>% str_replace_all("[óò]", "o") %>%
      str_replace_all("[úù]", "u")
  ) %>%
  select(-etnia_ecu, -etnia_per)

cat("Registro:", nrow(registro), "rows —",
    sum(registro$country == "ecuador", na.rm = TRUE), "Ecuador,",
    sum(registro$country == "peru", na.rm = TRUE), "Peru\n")

# Country lookup used to propagate country into servicios and historia
country_lookup <- registro %>% select(case_id, country)

# ── Load: Agregar Servicios (service cases) ───────────────────────────────────
# Using the servicios_salud case export (one row per individual service) rather
# than the form export (one row per visit). The form export is missing ~3,400
# services from an Oct 2024–Feb 2025 download gap; cases are the authoritative
# source. The referido field is not available per-service in the case export.

servicios_raw <- read_csv("data_anonymised/ecuador_servicios_cases_clean.csv", show_col_types = FALSE) %>%
  na_dashes() %>%
  clean_names()

servicios <- servicios_raw %>%
  select(
    case_id           = indices_cliente_salud,
    fecha_atencion    = opened_date,
    servicio          = service_name,
    dx_aps_1          = diagnos_principal,
    dx_aps_2          = diagnos_segundario,
    ssr_tipo,
    fp_corta          = metd_corta_anticonceptivo,
    fp_larga          = mtd_larga_anticonceptivo,
    prenatal          = ssr_tipo_prenatal,
    despistaje_cancer = ssr_tipo_cancer,
    sm_modalidad      = sm_psic_tipo,
    sm_tipo,
    dx_sm_1           = sm_diagnostico_p,
    dx_sm_2           = sm_diagnostico_s
  ) %>%
  mutate(
    referido       = NA_character_,
    fecha_atencion = as.Date(fecha_atencion)
  ) %>%
  left_join(country_lookup, by = "case_id") %>%
  left_join(svc_form_date_lookup,
            by = c("case_id" = "client_id", "fecha_atencion" = "form_date")) %>%
  mutate(
    service_date_validated = as.Date(coalesce(svc_date_validated, fecha_atencion)),
    year_month = format(fecha_atencion, "%Y-%m"),
    across(
      c(dx_aps_1, dx_aps_2, dx_sm_1, dx_sm_2),
      list(
        code  = ~ normalise_cie10(str_extract(.x, "^[a-z][0-9]{2}[a-z0-9]*\\.?[0-9]*")),
        label = ~ str_remove(.x, "^[a-z][0-9]{2}[a-z0-9]*\\.?[0-9]*_?") %>%
          str_replace_all("_", " ") %>%
          str_to_sentence()
      )
    )
  ) %>%
  select(-svc_date_validated)

cat("Servicios:", nrow(servicios), "rows\n")

# ── Derive reg_date_validated ─────────────────────────────────────────────────
# Use the earliest service_date_validated for each client if it pre-dates their
# registration system timestamp; otherwise keep reg_system. reg_system is the
# form completed_time — reliable and complete but reflects submission not visit.

earliest_svc <- servicios %>%
  group_by(case_id) %>%
  summarise(earliest_svc = min(service_date_validated, na.rm = TRUE), .groups = "drop")

registro <- registro %>%
  left_join(earliest_svc, by = "case_id") %>%
  mutate(
    reg_date_validated = as.Date(if_else(
      !is.na(earliest_svc) & earliest_svc < reg_system,
      earliest_svc,
      reg_system
    ))
  ) %>%
  select(-earliest_svc)

cat("reg_date_validated: ",
    sum(registro$reg_date_validated < registro$reg_system, na.rm = TRUE),
    "clients shifted earlier,",
    sum(format(registro$reg_date_validated, "%Y-%m") != format(registro$reg_system, "%Y-%m"), na.rm = TRUE),
    "change month\n")

# ── Load: Cliente Salud cases (chronic conditions) ────────────────────────────
# patologias_cronicas is a space-delimited multi-select on the cliente_salud
# case — not available in the registration form export. Joined here via caseid.

clientes_cases_raw <- read_csv("data_anonymised/ecuador_clientes_cases_clean.csv", show_col_types = FALSE) %>%
  na_dashes() %>%
  clean_names()

patologias_lookup <- clientes_cases_raw %>%
  select(case_id = caseid, patologias_cronicas) %>%
  filter(!is.na(patologias_cronicas))

registro <- registro %>%
  left_join(patologias_lookup, by = "case_id")

cat("patologias_cronicas: ", sum(!is.na(registro$patologias_cronicas)), "clients with data (",
    round(100 * mean(!is.na(registro$patologias_cronicas)), 1), "%)\n")

# ── Load: Historia Clinica ────────────────────────────────────────────────────

historia_raw <- read_csv("data_anonymised/ecuador_historia_clinica_clean.csv", show_col_types = FALSE) %>%
  na_dashes() %>%
  clean_names()

historia <- historia_raw %>%
  select(
    formid,
    case_id = form_case_case_id,
    tipo_hc = form_historia_clinica_inicio_hc_tipo_hc,
    fecha_hc = form_historia_clinica_inicio_hc_registration_date,
    sifilis_resultado = form_historia_clinica_inicio_hc_historia_clinica_aps_ssr_resultados_examenes_its_servicios_sifilis_resultado,
    vih_resultado = form_historia_clinica_inicio_hc_historia_clinica_aps_ssr_resultados_examenes_its_servicios_vih_resultado,
    hepatitis_resultado = form_historia_clinica_inicio_hc_historia_clinica_aps_ssr_resultados_examenes_its_servicios_hepatitis_resultado,
    ivaa_resultado = form_historia_clinica_inicio_hc_historia_clinica_aps_ssr_resultados_examenes_despitajes_de_cancer_servicios_seale_el_resultado_de_ivaa,
    embarazada = form_historia_clinica_inicio_hc_historia_clinica_aps_ssr_notas_iniciales_embarazada,
    caso_vbg = form_historia_clinica_inicio_hc_vbg_servicios_caso_vbg,
    tipo_vbg = form_historia_clinica_inicio_hc_vbg_servicios_tipo_vbg,
    sm_prueba = form_historia_clinica_inicio_hc_historia_clinica_salud_mental_prueba_de_bienestar
    # patologias_cronicas blanked by 'antecedentes' PII pattern — re-run
    # 00_anonymise_ecuador.R after fix to recover this field.
  ) %>%
  left_join(country_lookup, by = "case_id") %>%
  mutate(
    fecha_hc = as.Date(fecha_hc),
    year_month = format(fecha_hc, "%Y-%m")
  )

cat("Historia:", nrow(historia), "rows\n")

# ── Join: add demographics to service visits and historia ─────────────────────
# form.case.@case_id in servicios and historia is the parent cliente_salud
# case ID, matching case_id in registro. Confirmed via UUID overlap test.

demo_slim <- registro %>% select(case_id, country, age_band, perfil_migratorio, etnia)

servicios_demo <- servicios %>%
  select(-country) %>%
  left_join(demo_slim, by = "case_id")

historia_demo <- historia %>%
  select(-country) %>%
  left_join(demo_slim, by = "case_id")

# ── Section 1: Who we're reaching ─────────────────────────────────────────────

# Chart 1.1 — Consultations over time
agg_monthly_consultations <- servicios %>%
  filter(!is.na(year_month), !is.na(country)) %>%
  count(country, year_month) %>%
  rename(n_consultations = n)

write_agg(agg_monthly_consultations, "agg_monthly_consultations.csv")

# Chart 1.2 — Sex breakdown
agg_sex_breakdown <- registro %>%
  mutate(sexo = case_when(
    is.na(sexo) ~ "Otro",
    sexo == "I" ~ "Otro",
    sexo == "NR" ~ "Otro",
    sexo == "M" ~ "M",
    sexo == "H" ~ "H",
    TRUE ~ sexo
  )) %>%
  filter(!is.na(sexo), !is.na(country)) %>%
  count(country, sex = sexo) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

write_agg(agg_sex_breakdown, "agg_sex_breakdown.csv")

# Chart 1.3 — Age band distribution
agg_age_breakdown <- registro %>%
  filter(!is.na(age_band), !is.na(country)) %>%
  count(country, age_band) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

write_agg(agg_age_breakdown, "agg_age_breakdown.csv")

# Chart 1.3 (pyramid) — Age × sex in 5-year bands
# Denominator is total M+F per country so both bars share a common scale.
mf_totals <- registro %>%
  filter(sexo %in% c("H", "M"), !is.na(edad), !is.na(country)) %>%
  count(country, name = "total_mf")

agg_age_sex_pyramid <- registro %>%
  filter(sexo %in% c("H", "M"), !is.na(edad), !is.na(country)) %>%
  mutate(age_5yr = age_band_5yr(edad)) %>%
  filter(!is.na(age_5yr)) %>%
  count(country, sexo, age_5yr) %>%
  left_join(mf_totals, by = "country") %>%
  mutate(pct = n / total_mf) %>%
  select(-total_mf)

write_agg(agg_age_sex_pyramid, "agg_age_sex_pyramid.csv")

# Chart 1.4 — Migration profile
agg_migration_profile <- registro %>%
  filter(!is.na(perfil_migratorio), !is.na(country)) %>%
  count(country, migration_profile = perfil_migratorio) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup() %>%
  arrange(country, desc(n))

write_agg(agg_migration_profile, "agg_migration_profile.csv")

# Chart 1.5 — Ethnic profile (Ecuador and Peru; Mexico does not collect this)
agg_ethnic_profile <- registro %>%
  filter(!is.na(etnia), !is.na(country)) %>%
  count(country, ethnic_profile = etnia) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup() %>%
  arrange(country, desc(n))

write_agg(agg_ethnic_profile, "agg_ethnic_profile.csv")

# Chart 1.6 — Nationality breakdown
nationality_labels <- c(
  ecuatoriana       = "Ecuadorian",
  venezolana        = "Venezuelan",
  peruana           = "Peruvian",
  colombiana        = "Colombian",
  otra_nacionalidad = "Other",
  doble_nacionalidad = "Dual nationality"
)

agg_nationality <- registro %>%
  filter(!is.na(nacionalidad), !is.na(country)) %>%
  mutate(nacionalidad = str_to_lower(nacionalidad)) %>%
  count(country, nacionalidad) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup() %>%
  arrange(country, desc(n))

write_agg(agg_nationality, "agg_nationality.csv")

# Chart 1.7 — Services per client distribution
svc_counts <- servicios %>%
  filter(!is.na(case_id), !is.na(country)) %>%
  count(country, case_id, name = "n_services")

agg_services_per_client <- svc_counts %>%
  mutate(n_services_band = case_when(
    n_services == 1 ~ "1",
    n_services == 2 ~ "2",
    n_services == 3 ~ "3",
    n_services <= 5 ~ "4-5",
    n_services <= 10 ~ "6-10",
    TRUE ~ "11+"
  )) %>%
  count(country, n_services_band) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

agg_services_per_client_summary <- svc_counts %>%
  group_by(country) %>%
  summarise(
    n_clients      = n(),
    mean_services  = round(mean(n_services), 1),
    median_services = median(n_services),
    pct_one_service = round(mean(n_services == 1), 3),
    .groups = "drop"
  )

write_agg(agg_services_per_client,         "agg_services_per_client.csv")
write_agg(agg_services_per_client_summary, "agg_services_per_client_summary.csv")

# ── Section 2: APS clinical picture ───────────────────────────────────────────

# Stack primary and secondary diagnoses into long format (shared by 2.1, 2.2, 7.3)
aps_long <- bind_rows(
  servicios_demo %>% select(country, year_month, age_band, perfil_migratorio,
                            diagnosis_code = dx_aps_1_code, diagnosis_label = dx_aps_1_label),
  servicios_demo %>% select(country, year_month, age_band, perfil_migratorio,
                            diagnosis_code = dx_aps_2_code, diagnosis_label = dx_aps_2_label)
) %>%
  filter(!is.na(diagnosis_code), !is.na(country))

# Chart 2.1 — Top APS diagnoses by country
agg_aps_diagnoses <- aps_long %>%
  count(country, diagnosis_code, diagnosis_label) %>%
  arrange(country, desc(n))

write_agg(agg_aps_diagnoses, "agg_aps_diagnoses.csv")

# Chart 2.2 — Top diagnoses by age band
agg_aps_by_age <- aps_long %>%
  filter(!is.na(age_band)) %>%
  count(country, age_band, diagnosis_code, diagnosis_label) %>%
  group_by(country, age_band) %>%
  slice_max(n, n = 5) %>%
  ungroup() %>%
  arrange(country, age_band, desc(n))

write_agg(agg_aps_by_age, "agg_aps_by_age.csv")

# Chart 2.3 — Chronic conditions prevalence
# Denominator = clients with any patologias_cronicas data (not those with "ninguna")
# pct = proportion of clients with data who have each condition
chronic_base <- registro %>%
  filter(!is.na(country), !is.na(patologias_cronicas)) %>%
  count(country, name = "n_with_data")

agg_chronic_conditions <- registro %>%
  filter(!is.na(country), !is.na(patologias_cronicas)) %>%
  separate_longer_delim(patologias_cronicas, delim = " ") %>%
  filter(patologias_cronicas != "ninguna") %>%
  count(country, condition = patologias_cronicas) %>%
  left_join(chronic_base, by = "country") %>%
  mutate(pct = n / n_with_data) %>%
  arrange(country, desc(n))

write_agg(agg_chronic_conditions, "agg_chronic_conditions.csv")

# Chart 7.3 — Top 5 APS diagnoses trend over time (top 5 across all countries)
top5_aps <- aps_long %>%
  count(diagnosis_code, diagnosis_label) %>%
  slice_max(n, n = 5) %>%
  pull(diagnosis_code)

agg_aps_trend <- aps_long %>%
  filter(diagnosis_code %in% top5_aps, !is.na(year_month)) %>%
  count(country, year_month, diagnosis_code, diagnosis_label)

write_agg(agg_aps_trend, "agg_aps_trend.csv")

# ── Section 3: Sexual and reproductive health ──────────────────────────────────

# Chart 3.1 — SSR service mix
agg_ssr_service_mix <- servicios %>%
  filter(str_detect(coalesce(servicio, ""), "ssr"), !is.na(ssr_tipo), !is.na(country)) %>%
  separate_longer_delim(ssr_tipo, delim = " ") %>%
  filter(ssr_tipo != "") %>%
  count(country, ssr_tipo) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup() %>%
  arrange(country, desc(n))

write_agg(agg_ssr_service_mix, "agg_ssr_service_mix.csv")

# Chart 3.2 / 7.2 — ITS testing and positivity
its_long <- historia_demo %>%
  select(country, year_month, case_id, perfil_migratorio,
         sifilis = sifilis_resultado,
         vih = vih_resultado,
         hepatitis = hepatitis_resultado) %>%
  pivot_longer(c(sifilis, vih, hepatitis), names_to = "condition", values_to = "resultado") %>%
  filter(!is.na(resultado), !is.na(country)) %>%
  mutate(
    tested = resultado != "no_se_le_aplico",
    positive = resultado == "reactivo"
  ) %>%
  filter(tested)

agg_its_results <- its_long %>%
  group_by(country, condition) %>%
  summarise(n_tested = n(), n_positive = sum(positive), .groups = "drop") %>%
  mutate(positivity_rate = n_positive / n_tested)

write_agg(agg_its_results, "agg_its_results.csv")

agg_its_by_month <- its_long %>%
  filter(!is.na(year_month)) %>%
  group_by(country, condition, year_month) %>%
  summarise(n_tested = n(), n_positive = sum(positive), .groups = "drop") %>%
  mutate(positivity_rate = n_positive / n_tested)

write_agg(agg_its_by_month, "agg_its_by_month.csv")

# Chart 3.3 — Family planning method mix
agg_fp_methods <- bind_rows(
  servicios %>%
    filter(!is.na(fp_corta), !is.na(country)) %>%
    separate_longer_delim(fp_corta, delim = " ") %>%
    filter(fp_corta != "") %>%
    transmute(country, duration = "corta_duracion", method = fp_corta),
  servicios %>%
    filter(!is.na(fp_larga), !is.na(country)) %>%
    separate_longer_delim(fp_larga, delim = " ") %>%
    filter(fp_larga != "") %>%
    transmute(country, duration = "larga_duracion", method = fp_larga)
) %>%
  count(country, duration, method) %>%
  arrange(country, duration, desc(n))

write_agg(agg_fp_methods, "agg_fp_methods.csv")

# Chart 3.4 — Prenatal clients by age band
agg_prenatal_age <- servicios_demo %>%
  filter(str_detect(coalesce(servicio, ""), "ssr"), !is.na(prenatal), !is.na(country)) %>%
  count(country, age_band) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup()

write_agg(agg_prenatal_age, "agg_prenatal_age.csv")

# Chart 3.5 — CACU screening stat callout
agg_cacu_screening <- historia %>%
  filter(!is.na(ivaa_resultado), !is.na(country)) %>%
  group_by(country) %>%
  summarise(
    n_screened_ivaa = n(),
    n_ivaa_positive = sum(ivaa_resultado %in% c("positivo", "positiva", "anormal"), na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(ivaa_positivity_rate = n_ivaa_positive / n_screened_ivaa)

write_agg(agg_cacu_screening, "agg_cacu_screening.csv")

# Chart 6.3 — Pregnant <18 by population group
agg_prenatal_by_population <- servicios_demo %>%
  filter(
    str_detect(coalesce(servicio, ""), "ssr"), !is.na(prenatal),
    !is.na(country), !is.na(perfil_migratorio), !is.na(age_band)
  ) %>%
  mutate(
    population_group = if_else(
      perfil_migratorio == "poblacion_acogida", "Host community", "Migrant / refugee"
    ),
    under_18 = age_band %in% c("0-5", "6-11", "12-17")
  ) %>%
  group_by(country, population_group) %>%
  summarise(
    n_prenatal  = n(),
    n_under_18  = sum(under_18),
    pct_under_18 = n_under_18 / n_prenatal,
    .groups = "drop"
  )

write_agg(agg_prenatal_by_population, "agg_prenatal_by_population.csv")

# Chart 7.4 — Pregnant <18 proportion over time
agg_prenatal_trend <- servicios_demo %>%
  filter(
    str_detect(coalesce(servicio, ""), "ssr"), !is.na(prenatal),
    !is.na(country), !is.na(year_month), !is.na(age_band)
  ) %>%
  mutate(under_18 = age_band %in% c("0-5", "6-11", "12-17")) %>%
  group_by(country, year_month) %>%
  summarise(
    n_prenatal   = n(),
    n_under_18   = sum(under_18),
    pct_under_18 = n_under_18 / n_prenatal,
    .groups = "drop"
  )

write_agg(agg_prenatal_trend, "agg_prenatal_trend.csv")

# ── Section 4: Mental health ───────────────────────────────────────────────────

# Chart 4.1 — Mental health service type
agg_mh_service_type <- servicios %>%
  filter(str_detect(coalesce(servicio, ""), "sm"), !is.na(sm_tipo), !is.na(country)) %>%
  separate_longer_delim(sm_tipo, delim = " ") %>%
  filter(sm_tipo != "") %>%
  count(country, service_type = sm_tipo) %>%
  group_by(country) %>%
  mutate(pct = n / sum(n)) %>%
  ungroup() %>%
  arrange(country, desc(n))

write_agg(agg_mh_service_type, "agg_mh_service_type.csv")

# Chart 4.2 — Top mental health diagnoses
sm_long <- bind_rows(
  servicios %>% select(country, year_month, diagnosis_code = dx_sm_1_code, diagnosis_label = dx_sm_1_label),
  servicios %>% select(country, year_month, diagnosis_code = dx_sm_2_code, diagnosis_label = dx_sm_2_label)
) %>%
  filter(!is.na(diagnosis_code), !is.na(country))

agg_mh_diagnoses <- sm_long %>%
  count(country, diagnosis_code, diagnosis_label) %>%
  arrange(country, desc(n))

write_agg(agg_mh_diagnoses, "agg_mh_diagnoses.csv")

# Chart 4.3 — Mental health referrals
agg_referrals <- servicios %>%
  filter(str_detect(coalesce(servicio, ""), "sm"), !is.na(country)) %>%
  group_by(country) %>%
  summarise(
    n_consultations = n(),
    n_referred = sum(referido == "si", na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(referral_rate = n_referred / n_consultations)

write_agg(agg_referrals, "agg_referrals.csv")

# ── Section 6: Equity lens ────────────────────────────────────────────────────

# Chart 6.1 — Top diagnoses: migrant vs local
agg_equity_diagnoses <- aps_long %>%
  filter(!is.na(perfil_migratorio)) %>%
  mutate(population_group = if_else(
    perfil_migratorio == "poblacion_acogida",
    "local_host",
    "migrant_refugee"
  )) %>%
  count(country, population_group, diagnosis_code, diagnosis_label) %>%
  group_by(country, population_group) %>%
  slice_max(n, n = 5) %>%
  ungroup() %>%
  arrange(country, population_group, desc(n))

write_agg(agg_equity_diagnoses, "agg_equity_diagnoses.csv")

# Chart 6.2 — ITS positivity by population group
agg_its_by_population <- its_long %>%
  filter(!is.na(perfil_migratorio)) %>%
  mutate(population_group = if_else(
    perfil_migratorio == "poblacion_acogida",
    "local_host",
    "migrant_refugee"
  )) %>%
  group_by(country, condition, population_group) %>%
  summarise(n_tested = n(), n_positive = sum(positive), .groups = "drop") %>%
  mutate(positivity_rate = n_positive / n_tested)

write_agg(agg_its_by_population, "agg_its_by_population.csv")

# ── Section 7: Trends ─────────────────────────────────────────────────────────

# Chart 7.1 — Migration profile over time
agg_migration_by_month <- registro %>%
  filter(!is.na(perfil_migratorio), !is.na(year_month), !is.na(country)) %>%
  count(country, year_month, migration_profile = perfil_migratorio)

write_agg(agg_migration_by_month, "agg_migration_by_month.csv")

# Chart 7.5 — Mental health caseload over time
agg_mh_by_month <- servicios %>%
  filter(str_detect(coalesce(servicio, ""), "sm"), !is.na(year_month), !is.na(country)) %>%
  count(country, year_month, name = "n_mh_consultations")

write_agg(agg_mh_by_month, "agg_mh_by_month.csv")

# ── Chart 0.1: Location consultations (map) ───────────────────────────────────
agg_location_consultations <- registro %>%
  filter(!is.na(municipio), !is.na(country)) %>%
  count(country, municipio, name = "n_clients") %>%
  arrange(country, desc(n_clients))

write_agg(agg_location_consultations, "agg_location_consultations.csv")

# ── Metadata ──────────────────────────────────────────────────────────────────

writeLines(
  str_c("Data last updated: ", Sys.Date(), ". Source: CommCare EPR."),
  "data/last_updated.txt"
)

cat("\nDone.\n")
