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


emb_dir <- here(embeddings_data)
files <- fs::dir_ls(emb_dir, recurse = TRUE, glob = "*.feather")
dataset <- open_dataset(files, format = "feather", unify_schemas = TRUE)

data_query <- dataset %>%
  filter(
    id %in%
      unique(bert_df$id) &
      sentence_id %in% unique(bert_df$sentence_id)
  ) %>%
  collect() %>%
  distinct(id, sentence_id, year, .keep_all = TRUE)

bert_df <- merge(
  bert_df,
  data_query %>% select(id, sentence_id, year, embedding),
  by = c("id", "sentence_id", "year"),
  all.x = TRUE
) %>%
  as_tibble() %>%
  unique()

arrow::write_feather(
  bert_df,
  file.path(
    data_path,
    "closest_sentences_0.01_rationality_score_filtered_with_embeddings.feather"
  )
)
