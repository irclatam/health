# run_all.R
# Source all pipeline scripts in order.
# Run from project root: source("scripts/run_all.R")

cat("=== 00_anonymise_epr.R ===\n")
source("scripts/00_anonymise_epr.R")

cat("\n=== 00_anonymise_mx.R ===\n")
source("scripts/00_anonymise_mx.R")

cat("\n=== 01_pipeline_epr.R ===\n")
source("scripts/01_pipeline_epr.R")

cat("\n=== 01_pipeline_mx.R ===\n")
source("scripts/01_pipeline_mx.R")

cat("\n=== 02_combine.R ===\n")
source("scripts/02_combine.R")

cat("\n=== All done. ===\n")
