# Load libraries and data ---------------------------

source(file.path("scripts", "paths_and_packages.R"))

# load fulltext metadata
metadata <- read_rds(file.path(data_path, "full_metadata_journals_cleaned.rds")) 

# plot distribution of language

metadata |> 
  mutate(language = str_extract(language, "^[^,]+"),
         language = ifelse(language %in% c("eng", "ger", "fre", "ita"), language, "other")) |>
  count(language) |> 
  mutate(pct = n / sum(n) * 100) |> 
  ggplot(aes(x = reorder(language, pct), y = pct)) +
  geom_col() +
  # y axis in percentage
  scale_y_continuous(labels = scales::percent_format(scale = 1)) +
  labs(
    title = "Distribution of languages in the JSTOR fulltext Database",
    x = "Languages",
    y = "") +
  theme_minimal()

# save the plot
ggsave(file.path(image_path, "language_distribution_fulltext_database.png"), width = 8, height = 6)

