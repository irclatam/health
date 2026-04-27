# 00_anonymise_ecuador_cases.R
# Anonymise the two CommCare case exports before sharing or committing.
# Place raw files outside the project (offline_folder), run this script,
# clean output goes to data_anonymised/.

library(tidyverse)
library(readxl)
library(janitor)

# ── Configuration ─────────────────────────────────────────────────────────────

file_clientes  <- "/Users/philipblue/Documents/RStudio/offline_folder/data_raw/ecuador_cliente_salud.xlsx"
file_servicios <- "/Users/philipblue/Documents/RStudio/offline_folder/data_raw/ecuador_servicios_salud_cases.xlsx"

out_clientes   <- "data_anonymised/ecuador_clientes_cases_clean.csv"
out_servicios  <- "data_anonymised/ecuador_servicios_cases_clean.csv"

# ── PII patterns ──────────────────────────────────────────────────────────────
# Same logic as 00_anonymise_ecuador.R — match against normalised column names.
# Case export column names are simpler (no XPath prefix) so fewer edge cases.

pii_patterns <- c(
  # Names
  "nombre",
  "apellido",
  "cuidador",
  "cal_nombre",

  # Identity documents
  "documento",
  "cedula",
  "identificacion",
  "codigo_cliente",
  "doc_identi",

  # Contact
  "telefono",
  "notas_telefono",
  "pais_telefono",
  "numero_adicional",

  # Address
  "direccion",

  # Dates of birth
  "fecha_de_nacimiento",
  "cal_birthday",
  "fecha_nacimiento",

  # Free-text clinical narrative
  "motivo_consulta",
  "enfermedad",
  "antecedentes",
  "condicion_actual",
  "hc_analisis",
  "plan",
  "procedimiento",
  "educacin",
  "educacion",
  "descripcin_breve",
  "descripcion_breve",
  "acuerdo_teraputico",
  "acuerdo_terapeutico",
  "cual_otro_cronico",
  "osiegd_otro",
  "etnia_otro",
  "otra_amenazas",
  "indique_otro",
  "otras_vulnerabilidad",
  "nota_acompanado",

  # Free-text "other diagnosis" fields in servicios_salud
  "otro_diagnostico",

  # Physical exam free text
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

  # Obstetric dates
  "fum",
  "fup",
  "fecha_probable_del_parto",
  "fecha_embarazada",

  # CommCare system fields
  "owner_id",
  "form_link"
)

# ── Test / staff accounts to exclude ─────────────────────────────────────────

exclude_users <- c(
  "test",
  "test_peru",
  "test_ecuador",
  "irc2",
  "jorge.jaramillo@rescue.org",
  "zahira.soraluz@rescue.org",
  "leticia.lopera@rescue.org",
  "taraneh.missaghian@rescue.org",
  "angela.pajuelo@rescue.org",
  "hebert.delgado@rescue.org",
  "belen.agurto@rescue.org"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

blank_pii <- function(df, patterns) {
  normalise    <- function(x) str_replace_all(str_to_lower(x), "\\s+", "_")
  pattern_regex <- str_c(normalise(patterns), collapse = "|")
  pii_cols      <- names(df)[str_detect(normalise(names(df)), pattern_regex)]

  # Also blank the CommCare 'name' property (contains client name),
  # but not 'service_name' or other compound names
  name_col <- names(df)[names(df) == "name"]
  pii_cols  <- union(pii_cols, name_col)

  cat("Blanking", length(pii_cols), "PII columns:\n")
  walk(pii_cols, ~ cat(" -", .x, "\n"))

  df %>% mutate(across(all_of(pii_cols), \(x) NA_character_))
}

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

# ── Process cliente_salud case export ─────────────────────────────────────────

cat("\n=== cliente_salud case export ===\n")

clientes_raw <- read_excel(file_clientes) %>%
  mutate(across(where(is.character), ~ na_if(.x, "---"))) %>%
  mutate(across(where(is.character), ~ na_if(.x, "N/A"))) %>%
  clean_names()

cat("Excluding test/staff users:", sum(clientes_raw$opened_by_username %in% exclude_users, na.rm = TRUE), "rows\n")

clientes_raw <- clientes_raw %>%
  filter(!coalesce(opened_by_username, "") %in% exclude_users)

cat("Rows:", nrow(clientes_raw), "| Cols:", ncol(clientes_raw), "\n\n")

clientes_clean <- clientes_raw %>%
  # slice_sample(n = min(1000, nrow(clientes_raw))) %>%
  blank_pii(pii_patterns) %>%
  pseudonymise_users("username") %>%
  pseudonymise_users("opened_by_username") %>%
  pseudonymise_users("colaborador")

write_csv(clientes_clean, out_clientes)
cat("\nWritten to", out_clientes, "\n")

# ── Process servicios_salud case export ───────────────────────────────────────

cat("\n=== servicios_salud case export ===\n")

servicios_raw <- read_excel(file_servicios) %>%
  mutate(across(where(is.character), ~ na_if(.x, "---"))) %>%
  mutate(across(where(is.character), ~ na_if(.x, "N/A"))) %>%
  clean_names()

cat("Excluding test/staff users:", sum(servicios_raw$opened_by_username %in% exclude_users, na.rm = TRUE), "rows\n")

servicios_raw <- servicios_raw %>%
  filter(!coalesce(opened_by_username, "") %in% exclude_users)

cat("Rows:", nrow(servicios_raw), "| Cols:", ncol(servicios_raw), "\n\n")

servicios_clean <- servicios_raw %>%
  # slice_sample(n = min(1000, nrow(servicios_raw))) %>%
  blank_pii(pii_patterns) %>%
  pseudonymise_users("opened_by_username")

write_csv(servicios_clean, out_servicios)
cat("\nWritten to", out_servicios, "\n")

# ── Sanity check ──────────────────────────────────────────────────────────────

cat("\n=== Sanity check: non-blank columns ===\n")

cat("\nclientes_salud:\n")
clientes_clean %>%
  select(where(\(x) !all(is.na(x)))) %>%
  names() %>%
  print()

cat("\nservicios_salud:\n")
servicios_clean %>%
  select(where(\(x) !all(is.na(x)))) %>%
  names() %>%
  print()
