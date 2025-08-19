# Finding closest sentences

source(file.path("scripts", "paths_and_packages.R"))
p_load(text2vec)
representative_vectors <- read_feather(here::here(data_path, "representative_vectors.feather"))

# --- CONFIG ---
# 1) Folder that contains per-year sentence embedding files
emb_dir <- here::here(jstor_raw_data, "sentences_embeddings")               # e.g., "data/embeddings/"
# Files are named like: sentence_embeddings_1886.rds / .csv / .parquet
sentence_files <- list.files(emb_dir)

existing_sentence_file <- list.files(data_path) %>% 
  .[str_detect(., "closest_sentences_\\d.\\d_rationality_score.rds")]
if(length(existing_sentence_file) > 0){
  list_sentences <- readRDS(here::here(data_path, existing_sentence_file))
  years_done <- names(compact(list_sentences))
  years_to_do <- representative_vectors$year[!representative_vectors$year %in% years_done]
} else {
  list_sentences <- vector("list", length(representative_vectors$year))
  names(list_sentences) <- representative_vectors$year
  years_to_do <- representative_vectors$year
  }

for(year in years_to_do){
  cli::cli_alert_info("Processing year {year}...")
representative_vector <- representative_vectors %>% 
  filter(year == !!year) %>% 
  pull(embedding_by_year_centered) %>% 
  unlist()

sentence_embeddings <- read_feather(here::here(emb_dir, glue("sentence_embeddings_{year}.feather")))
emb_matrix <- do.call(rbind, sentence_embeddings$embedding)
# compute cosine similarity between representative vector and all sentences
sims <- sim2(emb_matrix, matrix(representative_vector, nrow = 1), method = "cosine", norm = "l2")
rm(emb_matrix)

list_sentences[[paste(year)]] <- sentence_embeddings %>% 
  mutate(similarity = sims,
         mean_year_similarity = mean(similarity)) %>% 
  arrange(desc(similarity)) %>% 
  select(-embedding) %>% 
  filter(similarity > quantile(sims, 0.99))

rm(sentence_embeddings)
gc()

saveRDS(list_sentences, here::here(data_path, glue("closest_sentences_0.1_rationality_score.rds")))
}
