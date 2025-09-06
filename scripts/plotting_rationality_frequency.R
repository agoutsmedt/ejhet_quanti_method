# paths and packages
source(file.path("scripts", "paths_and_packages.R"))

library(scales) # pour breaks/labels si besoin

REL_FREQ_PARQUET <- "relative_freq_merged_by_year.parquet"
df <- read_parquet(file.path(data_path, REL_FREQ_PARQUET))

# check the columns types
df <- df |>
  mutate(
    year = as.integer(year),
    token = as.character(token)
  )

plot_unigram <- function(df, token_query) {
  query <- tolower(token_query)

  df <- df %>%
    mutate(token_lower = str_to_lower(token)) %>%
    filter(token_lower == query) %>%
    arrange(year)

  if (nrow(df) == 0) {
    message(sprintf("❌ Token '%s' not found.", tq))
    return(invisible(NULL))
  }

  yr_min <- min(df$year, na.rm = TRUE)
  yr_max <- max(df$year, na.rm = TRUE)

  p <- ggplot(df, aes(x = year, y = relative_freq)) +
    geom_point() +
    labs(
      title = sprintf("Relative Frequency of '%s' over Time", query),
      x = "Year",
      y = "Relative Frequency"
    ) +
    scale_x_continuous(breaks = seq(yr_min, yr_max, by = 5)) +
    theme_minimal()

  print(p)
  invisible(p)
}

# Exemple
plot_unigram(df = df, token_query = "rationality")

# plot and save a search query of "rationality" and "rational" in a same graph

df_filtered <- df |>
  mutate(token_lower = str_to_lower(token)) |>
  filter(token_lower == "rational" | token_lower == "rationality")


df_filtered |>
  ggplot(aes(x = as.integer(year), y = relative_freq, color = token_lower)) +
  geom_point() +
  geom_smooth(method = "loess", se = FALSE, size = 1) +
  labs(
    x = NULL,
    y = "Relative Frequency",
    color = NULL,
  ) +
  ggsci::scale_color_npg() +
  scale_y_continuous(labels = scales::percent_format()) +
  scale_x_continuous(breaks = seq(1880, max(df$year), by = 20)) +
  theme_light(base_size = 20) +
  theme(legend.position = "bottom")

# Save the plot

ggsave(
  file.path(image_path, "relative_freq_rationality_and_rational.png"),
  width = 8,
  height = 9
)
