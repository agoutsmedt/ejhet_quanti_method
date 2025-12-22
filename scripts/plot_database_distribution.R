# Load libraries and data ---------------------------

source(file.path("scripts", "paths_and_packages.R"))

# load fulltext metadata
metadata_jstor <- read_rds(file.path(
  jstor_data_path,
  "jstor_constellate_merged_metadata.rds"
)) %>%
  filter(
    refined_sub_type == "research-article",
    publication_year < 2010,
    to_keep,
  ) %>%
  select(
    id = url,
    journal = is_part_of,
    title,
    authors = creators_string,
    year = publication_year,
    ID_Art = id_wos_matched,
    languages
  ) %>%
  mutate(url = str_c("https://", id)) |>
  arrange(year)

# same for scopus metadata
metadata_scopus <- read_rds(file.path(
  elsevier_data_path,
  "scopus_economics_articles.rds"
)) %>%
  mutate(
    year = as.integer(str_sub(prism_cover_date, 1, 4)),
    url = str_c("https://doi.org/", prism_doi)
  ) %>%
  filter(
    full_text == TRUE,
    subtype_description == "Article",
    year < 2010
  ) %>%
  select(
    id = scopus_id,
    title = dc_title,
    authors = dc_creator,
    journal = prism_publication_name,
    year,
    url,
    ID_Art = id_wos_matched
  ) %>%
  mutate(languages = "eng")

metadata <- bind_rows(metadata_jstor, metadata_scopus) |>
  filter(!is.na(year) & !is.na(title)) %>%
  filter(year %in% c(1900:2009))
# plot distribution overtime of articles

gg <- metadata %>%
  count(year) %>%
  ggplot(aes(x = year, y = n)) +
  geom_col(fill = "grey70", colour = "black", width = 0.8) +
  scale_x_continuous(breaks = seq(1900, 2009, by = 20), expand = c(0.01, 0)) +
  scale_y_continuous(expand = c(0.01, 0)) +
  labs(x = NULL, y = "Number of documents") +
  theme_light(base_size = 25)

ggsave(
  plot = gg,
  file.path(image_path, "documents_distribution_fulltext_database.png"),
  width = 16,
  height = 10
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
  group_by(decade) |>
  mutate(pct = n / sum(n) * 100) |>
  ungroup() |>
  ggplot(aes(x = decade, y = pct, fill = fct_rev(languages))) +
  geom_col(position = "fill") +
  scale_fill_grey(start = 0.8, end = 0.1) +
  scale_y_continuous(
    labels = scales::percent_format(scale = 100),
    expand = c(0.01, 0)
  ) +
  scale_x_continuous(breaks = seq(1900, 2009, by = 20), expand = c(0.01, 0)) +
  labs(
    x = NULL,
    y = "Percentage of documents",
    fill = NULL
  ) +
  theme_light(base_size = 25)


# save the plot
ggsave(
  plot = gg,
  file.path(image_path, "language_distribution_by_year_fulltext_database.png"),
  width = 16,
  height = 10
)
