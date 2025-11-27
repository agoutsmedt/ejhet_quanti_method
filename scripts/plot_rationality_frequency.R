# paths and packages
source(file.path("scripts", "paths_and_packages.R"))

library(scales) # pour breaks/labels si besoin


df <- arrow::read_parquet(file.path(
  embeddings_data,
  "vocab_embeddings.parquet"
))

# check the columns types
df <- df %>%
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
      x = NULL,
      y = "Relative Frequency"
    ) +
    scale_x_continuous(breaks = seq(yr_min, yr_max, by = 5)) +
    theme_minimal()

  print(p)
  invisible(p)
}

# Exemple
plot_unigram(df = df, token_query = "colonies")

# plot and save a search query of "rationality" and "rational" in a same graph

df_filtered <- df %>%
  mutate(token_lower = str_to_lower(token)) %>%
  filter(token_lower %in% c("rationality", "rational")) %>%
  filter(year %in% c(1900:2010))

# positions de labels = fin de série, alignées sur la courbe loess (pas les points bruyants)
label_pos <- df_filtered %>%
  group_by(token_lower) %>%
  summarise(
    x = max(year, na.rm = TRUE),
    y = {
      d <- cur_data_all()
      fit <- loess(relative_freq ~ year, data = d, span = 0.75)
      as.numeric(predict(fit, newdata = data.frame(year = x)))
    },
    .groups = "drop"
  )


p <- ggplot(
  df_filtered,
  aes(
    x = as.integer(year),
    y = relative_freq,
    color = token_lower,
    shape = token_lower
  )
) +
  geom_point(alpha = 0.35) +
  geom_smooth(method = "loess", se = FALSE, linewidth = 1) +
  ggrepel::geom_label_repel(
    data = label_pos,
    aes(
      x = x,
      y = y,
      label = stringr::str_to_title(token_lower),
      color = token_lower
    ),
    size = 5,
    inherit.aes = FALSE,
    direction = "y",
    nudge_x = 5, # pousse les labels vers la droite
    hjust = 0,
    box.padding = 0.2,
    point.padding = 0.1,
    min.segment.length = 0,
    segment.alpha = 0.5
  ) +
  labs(
    x = NULL,
    y = "Relative Frequency"
  ) +
  ggsci::scale_color_npg() +
  scale_x_continuous(
    breaks = seq(1900, max(df_filtered$year, na.rm = TRUE), by = 20),
    limits = c(1900, max(df_filtered$year, na.rm = TRUE) + 10) # marge pour les labels
  ) +
  theme_light(base_size = 25) +
  theme(legend.position = "none", plot.margin = margin(5.5, 30, 5.5, 5.5)) +
  coord_cartesian(clip = "off") # autorise le débordement des labels à droite

print(p)

# Save the plot

ggsave(
  file.path(image_path, "relative_freq_rationality_and_rational.png"),
  width = 12,
  height = 9
)
