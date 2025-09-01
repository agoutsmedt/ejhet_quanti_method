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
    x = "Year",
    y = "Number of documents"
  ) +
  theme_light(base_size = 20)

ggsave(
  plot = gg,
  file.path(image_path, "documents_distribution_fulltext_database.png"),
  width = 8,
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
    x = "Languages",
    y = ""
  ) +
  theme_light(base_size = 20)

# save the plot
ggsave(
  plot = gg,
  file.path(image_path, "language_distribution_fulltext_database.png"),
  width = 8,
  height = 9
)
