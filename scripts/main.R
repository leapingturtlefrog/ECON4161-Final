# Ensures the data and scripts exist and then runs all associated scripts.
# Enter the command 'source("main.R") while in this directory to run.

cat('\014')
rm(list=ls())

required_packages <- c("dplyr", "modelsummary", "AER", "ggplot2",
                       "cluster", "ggcorrplot")
scripts <- c("Visualization.R", "Inference.R", "Replication.R")

# Ensure data, scripts, and report (output directory) exist
if (!requireNamespace("here", quiet = T)) {
  install.packages("here")
}
library(here)
if (!file.exists(here("data", "401k.csv"))) {
  stop("Ensure data/401k.csv exists in relation to the project root directory")
}
script_paths <- file.path(here("scripts", scripts))
missing_scripts <- script_paths[!file.exists(here(script_paths))]
if (length(missing_scripts) > 0) {
  stop(paste("Missing scripts:", paste(missing_scripts, collapse = ", ")))
}
dir.create(here("report"), showWarnings = FALSE)

# Install packages and run scripts
cat("Installing required packages...\n")
for (pkg in required_packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg)
  }
}
cat("Running scripts...\n")
for (script in scripts) {
  cat("\n\nRUNNING", script, "\n\n")
  source(here("scripts", script))
}