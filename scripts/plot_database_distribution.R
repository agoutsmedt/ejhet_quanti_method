# Load libraries and data ---------------------------

source(file.path("scripts", "paths_and_packages.R"))

metadata <- read_feather(
  file.path(
    data_path,
    "metadata_all_texts.feather"
  )
)

metadata <- metadata |>
  filter(!is.na(year) & !is.na(title)) %>%
  filter(year %in% c(1900:2009))
# plot distribution overtime of articles

gg <- metadata %>%
  count(year) %>%
  ggplot(aes(x = year, y = n)) +
  # add blank points
  geom_line(linewidth = 1, color = color_roma_blue) +
  geom_point(
    color = color_roma_blue,
    size = 3.5,
    shape = 21,
    fill = "white",
    stroke = 1.5
  ) +
  scale_x_continuous(breaks = seq(1900, 2009, by = 20), expand = c(0.01, 0)) +
  scale_y_continuous(
    expand = c(0.01, 0),
    breaks = scales::pretty_breaks(n = 5)
  ) +
  labs(x = NULL, y = "Number of documents") +
  theme_custom(base_size = 25)

ggsave(
  plot = gg,
  file.path(image_path, "documents_distribution_fulltext_database.png"),
  width = 16,
  height = 10,
  units = "in",
  dpi = 300
)


# language distribution by year

gg <- metadata |>
  mutate(
    languages = str_extract(languages, "^[^,]+"),
    languages = ifelse(
      languages %in% c("eng", "ger", "fre", "ita"),
      languages,
      "other"
    ),
    languages = recode(
      languages,
      eng = "English",
      ger = "German",
      fre = "French",
      ita = "Italian",
      other = "Other"
    ),
    languages = factor(
      languages,
      levels = c("English", "German", "French", "Italian", "Other")
    ),
    decade = (year - (year %% 10))
  ) |>
  count(decade, languages) |>
  rename(count = n) |>
  group_by(decade) |>
  mutate(pct = count / sum(count) * 100) |>
  ungroup() |>
  ggplot(aes(x = decade, y = pct, fill = fct_rev(languages))) +
  geom_col(position = "fill") +
  scale_y_continuous(
    labels = scales::percent_format(scale = 100),
    expand = c(0.01, 0)
  ) +
  scale_x_continuous(breaks = seq(1900, 2009, by = 20), expand = c(0.01, 0)) +
  # ONLY BLACK AND WHITE
  scale_fill_manual(
    values = c(
      "English" = color_roma_blue,
      "German" = "#2c7fb8",
      "French" = "#41b6c4",
      "Italian" = "#a1dab4",
      "Other" = "#808080"
    )
  ) +
  labs(
    x = NULL,
    y = "Percentage of documents",
    fill = NULL
  ) +
  theme_custom(base_size = 25) +
  theme(legend.position = "bottom")


# save the plot
ggsave(
  plot = gg,
  file.path(image_path, "language_distribution_by_year_fulltext_database.png"),
  width = 16,
  height = 10,
  units = "in",
  dpi = 300
)
