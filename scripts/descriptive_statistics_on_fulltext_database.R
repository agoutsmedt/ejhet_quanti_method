# Load libraries and data ---------------------------

source(file.path("scripts", "paths_and_packages.R"))

# load fulltext metadata
metadata <- read_rds(file.path(data_path, "full_metadata_journals_cleaned.rds"))

metadata |> distinct(refined_sub_type)

# plot distribution of language

metadata |>
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
  theme_light(base_size = 14)

# save the plot
ggsave(
  file.path(image_path_temp, "language_distribution_fulltext_database.png"),
  width = 9
)
