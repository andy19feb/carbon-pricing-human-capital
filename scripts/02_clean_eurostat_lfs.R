# Project: Dataset B (Eurostat Human Capital Dependent Variable) Pipeline
# Version 8: Directly Targeting Standardized Schema Headers (TIME_PERIOD and OBS_VALUE)

library(readr)
library(dplyr)
library(stringr)

# 1. Establish Absolute Paths
raw_file_path    <- "C:/Users/anind/carbon-pricing-human-capital/data/raw/eurostat_lfs_lfsa_eisn2_raw.csv"
output_file_path <- "C:/Users/anind/carbon-pricing-human-capital/data/processed/eurostat_lfs_clean.csv"

# Project Scope Boundaries
target_countries <- c("DE", "AT", "CH", "NO", "FI", "SE")
target_years     <- 2015:2025

cat("Step 1: Ingesting natively structured Eurostat CSV dataset...\n")
# Load using standard numeric parsing for the target double column indicators
df_raw <- read_csv(raw_file_path, show_col_types = FALSE)

cat("Step 2: Isolating geographical target spaces and research timeline filters...\n")
df_filtered <- df_raw %>%
  # Filter out metadata lines if they accidentally replicate in row values
  filter(!is.na(geo) & !is.na(TIME_PERIOD)) %>%
  mutate(
    Country     = str_trim(as.character(geo)),
    Year        = as.integer(TIME_PERIOD),
    # Ensure employment metrics are strictly numeric doubles
    Employment  = as.numeric(OBS_VALUE)
  ) %>%
  filter(Country %in% target_countries) %>%
  filter(Year %in% target_years)

cat("Step 3: Mapping NACE Industry and ISCO Skill workforce blocks...\n")
df_classified <- df_filtered %>%
  mutate(
    # Industry Aggregations (NACE Rev. 2)
    Sector_Type = case_when(
      nace_r2 == "C" ~ "High-Emission",                         # Manufacturing
      nace_r2 == "D" ~ "High-Emission",                         # Utilities
      nace_r2 == "H" ~ "High-Emission",                         # Transport
      nace_r2 %in% c("J", "G", "I", "K", "L", "M", "N", 
                     "O", "P", "Q", "R", "S", "T", "U") ~ "Low-Emission", # Services/IT
      TRUE ~ "Other-Sectors"
    ),
    # Skill Aggregations (ISCO-08)
    Skill_Level = case_when(
      isco08 %in% c("OC1", "OC2", "OC3") ~ "High-Skill", # Managers, Professionals, Technicians
      isco08 %in% c("OC8", "OC9")        ~ "Low-Skill",  # Plant Operators, Elementary Trades
      TRUE ~ "Other-Skills"
    )
  ) %>%
  # Filter out general sector categories that fall outside your structural thesis groupings
  filter(Sector_Type != "Other-Sectors" & Skill_Level != "Other-Skills")

cat("Step 4: Consolidating and aggregating final absolute workforce counts...\n")
df_panel <- df_classified %>%
  group_by(Country, Year, Sector_Type, Skill_Level) %>%
  summarize(Employment_Count = sum(Employment, na.rm = TRUE), .groups = 'drop') %>%
  arrange(Country, Year, Sector_Type, Skill_Level)

# Map 2-letter uppercase region abbreviations to full string names
df_panel <- df_panel %>%
  mutate(Country = case_when(
    Country == "DE" ~ "Germany",
    Country == "AT" ~ "Austria",
    Country == "CH" ~ "Switzerland",
    Country == "NO" ~ "Norway",
    Country == "FI" ~ "Finland",
    Country == "SE" ~ "Sweden"
  ))

cat(paste0("Success! Rows processed for final compile: ", nrow(df_panel), "\n"))
cat("Sample check of cleaned aggregated data entries:\n")
print(head(df_panel, 6))

# 2. Export Snapshot Matrix back to local disk
write_csv(df_panel, output_file_path)
cat("Eurostat R structural parsing pipeline successfully completed!\n")
