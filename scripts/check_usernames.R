library(tidyverse)
library(readxl)
library(janitor)

file_registro  <- "/Users/philipblue/Documents/RStudio/offline_folder/data_raw/ecuador_registro_de_cliente.xlsx"
file_servicios <- "/Users/philipblue/Documents/RStudio/offline_folder/data_raw/ecuador_agregar_servicios.xlsx"
file_historia  <- "/Users/philipblue/Documents/RStudio/offline_folder/data_raw/ecuador_historia_clinica.xlsx"

registro  <- read_excel(file_registro)  |> select(hq_user) |> mutate(source = "registro")
servicios <- read_excel(file_servicios) |> select(hq_user) |> mutate(source = "servicios")
historia  <- read_excel(file_historia)  |> select(hq_user) |> mutate(source = "historia")

all_users <- bind_rows(registro, servicios, historia)

cat("=== All usernames across all three forms ===\n")
all_users |>
  tabyl(hq_user) |>
  arrange(desc(n)) |>
  adorn_totals() |>
  print(n = Inf)

cat("\n=== By form ===\n")
all_users |>
  count(source, hq_user) |>
  pivot_wider(names_from = source, values_from = n, values_fill = 0) |>
  mutate(total = registro + servicios + historia) |>
  arrange(desc(total)) |>
  print(n = Inf)
