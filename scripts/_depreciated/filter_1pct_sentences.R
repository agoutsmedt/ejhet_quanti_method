source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(
  tidymodels,
  tidyclust, # Clustering tools
  irlba, # Fast PCA
  doParallel,
  see,
  data.table
) # Color scales

## Bert rational paragraph loading--------------------
bert_df <- arrow::read_feather(file.path(
  data_path,
  "top1pct_sentences_by_year.feather"
)) %>%
  filter(between(year, 1900, 2020)) %>%
  distinct(id, year, sentence, sentence_id, .keep_all = TRUE) %>%
  as.data.table()

# # Choosing thresholds for similarity----------------

# # 1) How many sentences per year if cutoff = 0.60 or 0.55
# #    Note: this counts within your kept subset (top 1%), not the full corpus.
# bert_df %>%
#   select(year, similarity_rv) %>%
#   summarise(min = min(similarity_rv), .by = year) %>%
#   ggplot(aes(year, min)) +
#   geom_point()

# counts <- bert_df[,
#   .(
#     prop_058 = mean(similarity_rv >= 0.58, na.rm = TRUE),
#     prop_055 = mean(similarity_rv >= 0.55, na.rm = TRUE),
#     prop_052 = mean(similarity_rv >= 0.52, na.rm = TRUE),
#     prop_050 = mean(similarity_rv >= 0.50, na.rm = TRUE),
#     kept = .N
#   ),
#   by = year
# ][order(year)]

# # Plot both thresholds
# counts_long <- melt(
#   counts,
#   id.vars = "year",
#   measure.vars = c("prop_058", "prop_055", "prop_052", "prop_050"),
#   variable.name = "cutoff",
#   value.name = "count"
# )

# ggplot(
#   counts_long,
#   aes(year, count, linetype = cutoff, color = cutoff)
# ) +
#   geom_point() +
#   geom_smooth(span = 0.3) +
#   scale_color_see_d() +
#   labs(x = "Year", y = "Count ≥ cutoff") +
#   theme_minimal()

# final_cutoff <- 0.52
# bert_df_f <- bert_df[similarity_rv > final_cutoff]

# inputs

bert_df_f <- bert_df
rm(bert_df)

emb_dir <- here(embeddings_data)
files <- fs::dir_ls(emb_dir, recurse = TRUE, glob = "*.feather")
dataset <- open_dataset(files, format = "feather", unify_schemas = TRUE)

data_query <- dataset %>%
  filter(
    id %in%
      unique(bert_df_f$id) &
      sentence_id %in% unique(bert_df_f$sentence_id)
  ) %>%
  collect() %>%
  distinct(id, sentence_id, year, .keep_all = TRUE)

bert_df_f <- merge(
  bert_df_f,
  data_query %>% select(id, sentence_id, year, embedding),
  by = c("id", "sentence_id", "year"),
  all.x = TRUE
) %>%
  as_tibble() %>%
  unique()

arrow::write_feather(
  bert_df_f,
  file.path(
    data_path,
    "closest_sentences_0.01_rationality_score_filtered_with_embeddings.feather"
  )
)
