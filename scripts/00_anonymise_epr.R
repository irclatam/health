# 00_anonymise_ecuador.R
# Run this on raw CommCare exports before sharing or committing.
# Place the downloaded XLSXs in offline_folder/data_raw/ then run this script.
# Output goes to data_anonymised/ with PII removed.

library(tidyverse)
library(readxl)

# ── Configuration ─────────────────────────────────────────────────────────────

# Update these filenames to match whatever CommCare gives you
file_registro <- "/Users/philipblue/Documents/RStudio/offline_folder/data_raw/ecuador_registro_de_cliente.xlsx"
file_servicios <- "/Users/philipblue/Documents/RStudio/offline_folder/data_raw/ecuador_agregar_servicios.xlsx"
file_historia <- "/Users/philipblue/Documents/RStudio/offline_folder/data_raw/ecuador_historia_clinica.xlsx"

out_registro <- "data_anonymised/ecuador_registro_clean.csv"
out_servicios <- "data_anonymised/ecuador_servicios_clean.csv"
out_historia <- "data_anonymised/ecuador_historia_clinica_clean.csv"

# ── PII patterns to blank ─────────────────────────────────────────────────────
# These match column names containing any of these strings (case-insensitive).
# CommCare exports use the full XPath as column name, so partial matching is
# safer than exact matching.

pii_patterns <- c(
  # Names
  "nombre",
  "apellido",
  "cuidador",           # caregiver name fields

  # Identity documents
  "documento",
  "cedula",
  "numero_doc",
  "identificacion",
  "codigo_cliente",     # may contain document-derived ID
  "identificacion_alfa",

  # Contact
  "telefono",
  "contacto",
  "notas_telefono",
  "numero_adicional",
  "pais_telefono",

  # Address (keep admin-level location, blank street address)
  "direccion",

  # Date of birth (age is already captured in cliente_edad)
  "fecha_de_nacimiento",
  "fecha_nacimiento",
  "cal_birthday",

  # Free-text clinical narrative — high re-identification risk
  "motivo_consulta",
  "motivo_de_consulta",
  "enfermedad_actual",
  "enfermedades_actuales",
  "antecedentes_personales",
  "antecedentes_familiares",
  "antecedentes_ocupacionales",
  "antecedentes_otros",
  # "antecedentes" omitted: too broad — matches the XPath prefix
  # antecedentes_personales_ecu.patologias_cronicas and blanks the coded
  # structured field. Specific sub-fields are listed above.
  "descripcion",
  "descripcin",         # Spanish encoding variant
  "nota_acompanado",
  "notas",
  "plan",               # clinical plan free text
  "hc_analisis",
  "observacion",
  "observación",
  "padecimiento",
  "padcimiento",        # typo variant in Mexico app, include for safety
  "historia_clinica_text",

  # Historia Clinica: doctor identity
  "medico",

  # Historia Clinica: physical exam free text (one field per body system)
  "neurologico",
  "neurolgico",
  "piel",
  "cabeza",
  "cardico",
  "torax",
  "abdomen",
  "genito",
  "extremidades",
  "organos_de_los_sentido",

  # Historia Clinica: clinical assessment / plan free text
  "procedimiento",
  "educacion",          # education notes free text
  "educacin",
  "analisis",           # HC_analisis / plan
  "acuerdo_teraputico",
  "acuerdo_terapeutico",

  # Historia Clinica: mental health narrative
  "condicion_actual",
  "descripcin_breve",
  "descripcion_breve",

  # Free-text "specify other" fields throughout the form
  "indique_cul_otro",
  "indique_cual_otro",
  "especifique",
  "otros_examenes",
  "cual_otro",

  # Obstetric dates (keep counts/numeric fields, blank exact dates)
  "fum",                # fecha última menstruación
  "fup",                # fecha último parto
  "fecha_probable_del_parto",

  # Free-text "other" / "specify" fields
  "cual_otra",
  "otra_etnia",
  "indique_otra",
  "otra_orientacion",

  # Staff / collaborator identity — pseudonymised separately, not blanked

  # Organisation name (narrows location)
  "centro_u_organizacin",

  # CommCare links and user metadata
  "form_link",
  "username",
  "owner_name",
  "cal_nombre"          # loaded display name
)

# ── Test / staff accounts to exclude ─────────────────────────────────────────

exclude_users <- c(
  "test",
  "test_peru",
  "test_ecuador",
  "irc2",
  "---",
  "jorge.jaramillo@rescue.org",
  "zahira.soraluz@rescue.org",
  "leticia.lopera@rescue.org",
  "taraneh.missaghian@rescue.org",
  "angela.pajuelo@rescue.org",
  "hebert.delgado@rescue.org",
  "belen.agurto@rescue.org"
)

# ── Helper ────────────────────────────────────────────────────────────────────

pseudonymise_users <- function(df, col) {
  if (!col %in% names(df)) return(df)
  lookup <- tibble(real = unique(df[[col]])) %>%
    filter(!is.na(real)) %>%
    mutate(dummy = str_c("user_", str_pad(row_number(), width = 2, pad = "0")))
  df %>%
    left_join(lookup, by = setNames("real", col)) %>%
    mutate(!!col := dummy) %>%
    select(-dummy)
}

blank_pii <- function(df, patterns) {
  # Normalise both column names and patterns to underscores before matching
  # so that "codigo_cliente" matches "CODIGO CLIENTE" etc.
  normalise <- function(x) str_replace_all(str_to_lower(x), "\\s+", "_")
  cols_normalised <- normalise(names(df))
  pattern_regex   <- str_c(normalise(patterns), collapse = "|")
  pii_cols        <- names(df)[str_detect(cols_normalised, pattern_regex)]

  cat("Blanking", length(pii_cols), "PII columns:\n")
  walk(pii_cols, ~ cat(" -", .x, "\n"))

  df %>% mutate(across(all_of(pii_cols), \(x) NA_character_))
}

# Collapse consultation date to month-year (reduces re-identification risk
# while preserving everything the dashboard needs)
round_date_to_month <- function(df, date_col) {
  if (!date_col %in% names(df)) return(df)
  df %>%
    mutate(across(
      all_of(date_col),
      \(x) format(as.Date(x), "%Y-%m")
    ))
}

# ── Process Registro de Cliente ───────────────────────────────────────────────

cat("\n=== Registro de Cliente ===\n")

registro_raw <- read_excel(file_registro)
cat("Rows:", nrow(registro_raw), "| Cols:", ncol(registro_raw), "\n\n")
cat("Excluding test/staff users:", sum(registro_raw$hq_user %in% exclude_users, na.rm = TRUE), "rows\n\n")

registro_clean <- registro_raw %>%
  filter(!hq_user %in% exclude_users) %>%
  # slice_sample(n = min(1000, nrow(registro_raw))) %>%
  blank_pii(pii_patterns) %>%
  pseudonymise_users("hq_user") %>%
  round_date_to_month("fecha_de_registro")

write_csv(registro_clean, out_registro)
cat("\nWritten to", out_registro, "\n")

# ── Process Agregar Servicios ─────────────────────────────────────────────────

cat("\n=== Agregar Servicios ===\n")

servicios_raw <- read_excel(file_servicios)
cat("Rows:", nrow(servicios_raw), "| Cols:", ncol(servicios_raw), "\n\n")
cat("Excluding test/staff users:", sum(servicios_raw$hq_user %in% exclude_users, na.rm = TRUE), "rows\n\n")

servicios_clean <- servicios_raw %>%
  filter(!hq_user %in% exclude_users) %>%
  # slice_sample(n = min(1000, nrow(servicios_raw))) %>%
  blank_pii(pii_patterns) %>%
  pseudonymise_users("hq_user") %>%
  round_date_to_month("fecha_de_atencion")

write_csv(servicios_clean, out_servicios)
cat("\nWritten to", out_servicios, "\n")

# ── Process Historia Clinica ──────────────────────────────────────────────────

cat("\n=== Historia Clinica ===\n")

historia_raw <- read_excel(file_historia)
cat("Rows:", nrow(historia_raw), "| Cols:", ncol(historia_raw), "\n\n")
cat("Excluding test/staff users:", sum(historia_raw$hq_user %in% exclude_users, na.rm = TRUE), "rows\n\n")

historia_clean <- historia_raw %>%
  filter(!hq_user %in% exclude_users) %>%
  # slice_sample(n = min(1000, nrow(historia_raw))) %>%
  blank_pii(pii_patterns) %>%
  pseudonymise_users("hq_user") %>%
  pseudonymise_users("form.historia_clinica.inicio_hc.historia_clinica_aps_ssr.resultados_examenes.colaborador") %>%
  pseudonymise_users("form.historia_clinica.inicio_hc.historia_clinica_salud_mental.colaborador_sm") %>%
  round_date_to_month("fecha_de_atencion")

write_csv(historia_clean, out_historia)
cat("\nWritten to", out_historia, "\n")

# ── Sanity check ──────────────────────────────────────────────────────────────

cat("\n=== Sanity check: columns remaining with data ===\n")
cat("\nRegistro — non-blank columns:\n")
registro_clean %>%
  select(where(\(x) !all(is.na(x)))) %>%
  names() %>%
  print()

cat("\nServicios — non-blank columns:\n")
servicios_clean %>%
  select(where(\(x) !all(is.na(x)))) %>%
  names() %>%
  print()

cat("\nHistoria Clinica — non-blank columns:\n")
historia_clean %>%
  select(where(\(x) !all(is.na(x)))) %>%
  names() %>%
  print()
