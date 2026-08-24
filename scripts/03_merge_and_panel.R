# Project: Master Structural Panel Dataset Integration Engine
# Task: Executing Left Join with Explicit Type Alignment on Primary Keys

library(readr)
library(dplyr)

# 1. Direct paths to the tracked repository data nodes
pricing_file   <- "C:/Users/anind/carbon-pricing-human-capital/data/processed/carbon_prices_clean.csv"
employment_file <- "C:/Users/anind/carbon-pricing-human-capital/data/processed/eurostat_lfs_clean.csv"
master_panel_file <- "C:/Users/anind/carbon-pricing-human-capital/data/processed/master_structural_panel.csv"

cat("Loading processed dataset files from main repository...\n")
df_pricing    <- read_csv(pricing_file, show_col_types = FALSE)
df_employment <- read_csv(employment_file, show_col_types = FALSE)

cat("Aligning data types for key variables to ensure compatibility...\n")
# Force both vectors to integers so they align flawlessly
df_employment <- df_employment %>% mutate(Year = as.integer(Year))
df_pricing    <- df_pricing    %>% mutate(Year = as.integer(Year))

cat("Executing left join on composite primary keys (Country and Year)...\n")
df_master <- df_employment %>%
  left_join(df_pricing, by = c("Country", "Year")) %>%
  # Fill missing pricing nodes with 0.0 (safeguard for non-tax baseline intervals)
  mutate(Total_Carbon_Price_EUR = coalesce(Total_Carbon_Price_EUR, 0.0)) %>%
  arrange(Country, Year, Sector_Type, Skill_Level)

cat("\n--- Final Master Research Panel Framework Verification ---\n")
print(head(df_master, 12))

cat(paste0("\n Exporting complete PhD-ready panel matrix to: ", master_panel_file, "\n"))
write_csv(df_master, master_panel_file)
cat("Dataset compilation fully complete! Ready for econometric modeling.\n")
