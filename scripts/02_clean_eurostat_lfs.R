# MECP301 Project: Dataset B (Eurostat Human Capital Dependent Variable) Pipeline
# Version 3: Formatted for Blind Ingestion to Bypass Structural Schema Clashes

library(readr)
library(dplyr)
library(stringr)
library(tidyr)

# 1. Establish Absolute Paths
raw_file_path    <- "C:/Users/anind/carbon-pricing-human-capital/data/raw/eurostat_lfs_lfsa_eisn2_raw.csv"
output_file_path <- "C:/Users/anind/carbon-pricing-human-capital/data/processed/eurostat_lfs_clean.csv"

# Project Scope
target_countries <- c("DE", "AT", "CH", "NO", "FI", "SE")
target_years     <- as.character(2015:2025)

cat("🚀 Step 1: Blindly importing raw Eurostat CSV matrix as character lines...\n")
# col_names = FALSE skips column parsing completely and assigns X1, X2, X3 automatically
df_raw <- read_csv(raw_file_path, col_names = FALSE, col_types = cols(.default = col_character()), show_col_types = FALSE)

# 2. Extract and Isolate the Real Year Column Labels from the First Row
header_row <- as.character(df_raw[1, ])
# Clean whitespace out of header values
header_row <- str_trim(header_row)

# 3. Clean Out Explanatory or Commentary Rows from Data Matrix
df_data_rows <- df_raw %>%
  filter(!str_detect(X1, "Data last updated|Metadata|LAST UPDATE|freq|unit"))

# Re-apply the manually processed header row array onto our clean data rows
colnames(df_data_rows) <- header_row

# Dynamically locate the messy metadata first column name
metadata_col <- colnames(df_data_rows)[1]

cat("🔄 Step 2: Melting time-series columns using character safety mapping...\n")
df_long <- df_data_rows %>%
  pivot_longer(
    cols = -all_of(metadata_col), 
    names_to = "Year", 
    values_to = "Employment_Count"
  ) %>%
  filter(Year %in% target_years)

cat("🧩 Step 3: Unpacking comma-separated metadata indices...\n")
# Standard Eurostat layout: breaks metadata column into separate dimensions
df_unpacked <- df_long %>%
  separate(
    col = all_of(metadata_col),
    into = c("freq", "unit", "isco08", "nace_r2", "sex", "Country"),
    sep = ","
  ) %>%
  # Strip any unexpected characters or trailing whitespaces from codes
  mutate(Country = str_trim(Country)) %>%
  filter(Country %in% target_countries)

# 4. Clean Numeric Values and Convert special character symbols (":")
df_cleaned <- df_unpacked %>%
  mutate(
    Employment_Count = str_replace_all(Employment_Count, " ", ""),
    Employment_Count = str_replace_all(Employment_Count, "[a-zA-Z]", ""), # Drops data flags
    Employment_Count = na_if(Employment_Count, ":"),
    Employment_Count = as.numeric(Employment_Count),
    Employment_Count = ifelse(is.na(Employment_Count), 0.0, Employment_Count),
    Year = as.integer(Year)
  )

# 5. Execute Research Grouping Classifications
cat("📊 Step 4: Applying Industry and Skill economic groupings...\n")
df_classified <- df_cleaned %>%
  mutate(
    Sector_Type = case_when(
      nace_r2 == "C" ~ "High-Emission", 
      nace_r2 == "D" ~ "High-Emission", 
      nace_r2 == "H" ~ "High-Emission", 
      nace_r2 %in% c("J", "G", "I", "K", "L", "M", "N", 
                     "O", "P", "Q", "R", "S", "T", "U") ~ "Low-Emission", 
      TRUE ~ "Other-Sectors"
    ),
    Skill_Level = case_when(
      isco08 %in% c("OC1", "OC2", "OC3") ~ "High-Skill", 
      isco08 %in% c("OC8", "OC9")        ~ "Low-Skill", 
      TRUE ~ "Other-Skills"
    )
  ) %>%
  filter(Sector_Type != "Other-Sectors" & Skill_Level != "Other-Skills")

# 6. Sum Observations Across Dimensions
cat("降低 Step 5: Aggregating structural rows matrix...\n")
df_panel <- df_classified %>%
  group_by(Country, Year, Sector_Type, Skill_Level) %>%
  summarize(Employment_Count = sum(Employment_Count, na.rm = TRUE), .groups = 'drop') %>%
  arrange(Country, Year, Sector_Type, Skill_Level)

# Standardize country codes to match full string names
df_panel <- df_panel %>%
  mutate(Country = case_when(
    Country == "DE" ~ "Germany",
    Country == "AT" ~ "Austria",
    Country == "CH" ~ "Switzerland",
    Country == "NO" ~ "Norway",
    Country == "FI" ~ "Finland",
    Country == "SE" ~ "Sweden"
  ))

# 7. Write clean dataset back into project directory structure
cat(paste0("💾 Step 6: Saving processed labor file to: ", output_file_path, "\n"))
write_csv(df_panel, output_file_path)
cat("✅ Eurostat R structural parsing pipeline successfully completed!\n")
