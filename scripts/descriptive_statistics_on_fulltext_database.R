# Load libraries and data ---------------------------

source(file.path("scripts", "paths_and_packages.R"))

# load fulltext metadata
metadata <- read_rds(file.path(data_path, "full_metadata_journals_cleaned.rds"))

# plot distribution overtime of articles

gg <- metadata |>
  rename(year = publication_year) |>
  count(year) |>
  ggplot(aes(x = year)) +
  geom_point(aes(y = n)) +
  labs(
    x = NULL,
    y = "Number of documents"
  ) +
  theme_light(base_size = 25)

ggsave(
  plot = gg,
  file.path(image_path, "documents_distribution_fulltext_database.png"),
  width = 12,
  height = 9
)

# plot distribution of language

gg <- metadata |>
  mutate(
    language = str_extract(language, "^[^,]+"),
    language = ifelse(
      language %in% c("eng", "ger", "fre", "ita"),
      language,
      "other"
    ),
    language = recode(
      language,
      eng = "English",
      ger = "German",
      fre = "French",
      ita = "Italian",
      other = "Other"
    )
  ) |>
  count(language) |>
  mutate(pct = n / sum(n) * 100) |>
  ggplot(aes(x = reorder(language, pct, decreasing = TRUE), y = pct)) +
  geom_col() +
  # y axis in percentage
  scale_y_continuous(labels = scales::percent_format(scale = 1)) +
  labs(
    x = NULL,
    y = "Percentage of documents"
  ) +
  theme_light(base_size = 25)

# save the plot
ggsave(
  plot = gg,
  file.path(image_path, "language_distribution_fulltext_database.png"),
  width = 12,
  height = 9
)


# language distribution by year 


gg <- metadata |>
  mutate(
    language = str_extract(language, "^[^,]+"),
    language = ifelse(
      language %in% c("eng", "ger", "fre", "ita"),
      language,
      "other"
    ),
    language = recode(
      language,
      eng = "English",
      ger = "German",
      fre = "French",
      ita = "Italian",
      other = "Other"
    )
  ) |>
  rename(year = publication_year) |>
  count(year, language) |>
  group_by(year) |>
  mutate(pct = n / sum(n) * 100) |>
  ungroup() |>
  ggplot(aes(x = year, y = pct, fill = language)) +
  geom_col(position = "fill") +
  scale_fill_brewer(palette = "Set2") +
  scale_y_continuous(labels = scales::percent_format(scale = 100)) +
  labs(
    x = NULL,
    y = "Percentage of documents",
    fill = NULL,
  ) +
  theme_light(base_size = 25)


# save the plot 
ggsave(
  plot = gg,
  file.path(image_path, "language_distribution_by_year_fulltext_database.png"),
  width = 12,
  height = 9
)
