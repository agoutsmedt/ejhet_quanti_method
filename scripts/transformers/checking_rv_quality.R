# This script checks the quality of representative vectors for sentences

# paths and packages
source(file.path("scripts", "paths_and_packages.R"))

representative_vectors <- readRDS(here::here(data_path, "closest_sentences_0.01_rationality_score.rds"))

# check the distribution of similarity scores for sentences (with rv) that use the word "rational(ity)" and those that do not

df <- bind_rows(representative_vectors) %>%
    mutate(
      uses_rational = ifelse(str_detect(sentence, 
        regex("\\brational\\b|\\brationality\\b", ignore_case = TRUE)),
        "YES", "NO")) |> 
  mutate(
    decade = floor(publication_year / 10) * 10
  )


# plot the results

ggplot(df, aes(x = uses_rational, y = similarity, fill = uses_rational)) +
  geom_violin(trim = FALSE, alpha = 0.6, scale = "count") +
  # geom_boxplot(width = 0.15, outlier.shape = NA, alpha = 0.8) +
  # facet_wrap(~ decade, scales = "free_y") +
  guides(fill = "none") +
  labs(x = NULL, y = "Similarity", title = "Distribution of similarity and usage of 'rational(ity)'") +
  theme_light(base_size = 20)

ggsave(here::here("pictures", "similarity_distribution.png"), width = 10, height = 6, dpi = 300)
