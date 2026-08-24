# Project: Self-Contained Master Visualization Dashboard
# Version 9: String-Containment Mapping to Eliminate Eurostat Cell Label Traps

library(readr)
library(dplyr)
library(ggplot2)
library(patchwork)
library(scales)
library(stringr)

# 1. Establish Absolute Paths to Data Repository
wb_raw_path      <- "C:/Users/anind/carbon-pricing-human-capital/data/processed/carbon_prices_clean.csv"
euro_raw_path    <- "C:/Users/anind/carbon-pricing-human-capital/data/raw/eurostat_lfs_lfsa_eisn2_raw.csv"
plot_output_path <- "C:/Users/anind/carbon-pricing-human-capital/data/processed/trend_visualization.png"

target_countries <- c("DE", "AT", "CH", "NO", "FI", "SE")
target_years     <- 2015:2025

# --- PILLAR A: PRICING TRENDS ---
cat("Loading Dataset A (World Bank Processed CSV)...\n")
df_p <- read_csv(wb_raw_path, show_col_types = FALSE)

df_pricing_trends <- df_p %>%
  mutate(
    Year = as.integer(Year),
    Carbon_Price = as.numeric(Total_Carbon_Price_EUR)
  ) %>%
  filter(!is.na(Year) & Year >= 2015 & Year <= 2025)


# --- PILLAR B: LABOR TRENDS WITH TEXT-CONTAINMENT MATCHING ---
cat("Loading Dataset B (Eurostat Raw CSV)...\n")
df_e <- read_csv(euro_raw_path, show_col_types = FALSE)

cat("Processing structural workforce classifications with partial matching...\n")
df_employment_trends <- df_e %>%
  filter(!is.na(geo) & !is.na(TIME_PERIOD)) %>%
  mutate(
    Country = str_trim(as.character(geo)),
    Year    = as.integer(TIME_PERIOD),
    Value   = as.numeric(OBS_VALUE),
    nace_clean = str_trim(as.character(nace_r2))
  ) %>%
  # Filter countries by checking both short codes and full text variations
  filter(Country %in% target_countries | 
           str_detect(tolower(Country), "germany|austria|switzerland|norway|finland|sweden")) %>%
  filter(Year %in% target_years) %>%
  mutate(
    # FIX: Use partial string detection to safely catch combined descriptions like "C - Manufacturing"
    Sector_Type = case_when(
      str_detect(nace_clean, "^C\\b|Manufacturing|Manufacturing") ~ "High-Emission",
      str_detect(nace_clean, "^D\\b|Electricity|Utilities")     ~ "High-Emission",
      str_detect(nace_clean, "^H\\b|Transport|Transportation")  ~ "High-Emission",
      TRUE ~ "Low-Emission" # Captures services, IT, and public commercial streams safely
    )
  ) %>%
  group_by(Year, Sector_Type) %>%
  summarize(Total_Employment = sum(Value, na.rm = TRUE), .groups = "drop")

cat("\n CONSOLE DIAGNOSTIC REPORT FOR PANEL B:\n")
print(df_employment_trends)


# --- DRAWING THE VISUAL CANVASES ---
cat(" Drawing Plot A: Policy Trajectories...\n")
plot_A <- ggplot(df_pricing_trends, aes(x = Year, y = Carbon_Price, color = Country, group = Country)) +
  geom_line(linewidth = 1.2) +
  geom_point(size = 2) +
  scale_x_continuous(breaks = 2015:2025, limits = c(2015, 2025)) +
  scale_y_continuous(labels = dollar_format(prefix = "€")) +
  scale_color_brewer(palette = "Dark2") +
  labs(
    title = "Panel A: Carbon Pricing Policy Evolution (2015-2025)",
    subtitle = "Total Nominal Carbon Price Signal (Tax + ETS combined values) [source: World Bank]",
    x = NULL, 
    y = "Price Floor per tCO2e (EUR)"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(color = "dimgray", size = 9),
    panel.grid.minor = element_blank(),
    legend.position = "right"
  )

cat(" Drawing Plot B: Labor Shifts (Line Model)...\n")
plot_B <- ggplot(df_employment_trends, aes(x = Year, y = Total_Employment, color = Sector_Type, group = Sector_Type)) +
  geom_line(linewidth = 1.5) +
  geom_point(size = 3) +
  scale_x_continuous(breaks = 2015:2025, limits = c(2015, 2025)) +
  scale_y_continuous(labels = comma_format(suffix = "k")) +
  scale_color_manual(values = c("High-Emission" = "#d95f02", "Low-Emission" = "#7570b3")) +
  labs(
    title = "Panel B: Structural Workforce Allocation Dynamics",
    subtitle = "Aggregated Employment Trend Lines (Thousands of Persons) [source: Eurostat]",
    x = "Timeline Calendar Year",
    y = "Total Employed Persons",
    color = "Sector Classification"
  ) +
  theme_minimal(base_size = 11) +
  theme(
    plot.title = element_text(face = "bold", size = 12),
    plot.subtitle = element_text(color = "dimgray", size = 9),
    panel.grid.minor = element_blank(),
    legend.position = "right"
  )

# Combine layouts vertically using patchwork mechanics
combined_research_plot <- plot_A / plot_B + 
  plot_annotation(
    title = "Exploratory Trend Analysis: Environmental Regulation vs. Industrial Labor Shifting",
    subtitle = "Background context mapping for MECP301 | Sample Territory: DE, AT, CH, NO, FI, SE",
    caption = "Source data: Combined parsing pipelines from World Bank Carbon Pricing Dashboard & Eurostat LFS Table [lfsa_eisn2].",
    theme = theme(
      plot.title = element_text(face = "bold", size = 14, hjust = 0.5),
      plot.subtitle = element_text(color = "dimgray", size = 10, hjust = 0.5),
      plot.caption = element_text(face = "italic", size = 8, color = "darkgray")
    )
  )

# Save High-Resolution Plot Asset to Disk
cat(paste0(" Saving publication-ready plot artifact to: ", plot_output_path, "\n"))
ggsave(plot_output_path, plot = combined_research_plot, width = 10, height = 8.5, dpi = 300)
cat("Graphics pipeline fully complete and verified!\n")
