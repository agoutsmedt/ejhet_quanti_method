source(here::here("scripts", "paths_and_packages.R"))

# --- Load data ---
top1pct <- read_feather(
  file.path(data_path, "top1pct_sentences_by_year.feather"),
  col_select = c("id", "sentence_id", "year")
)

fulltexts <- read_feather(
  file.path(data_path, "fulltexts_cosine_sim_with_rv.feather"),
  col_select = c("id", "cosine_doc_with_rv")
)

top10pct_ids <- fulltexts %>%
  slice_max(cosine_doc_with_rv, prop = 0.1, with_ties = FALSE) %>%
  distinct(id)

# --- Compute statistics ---
n_sentences_corpus_articles  <- n_distinct(top1pct$id)
n_sentences_corpus_sentences <- nrow(top1pct)

n_articles_corpus <- nrow(top10pct_ids)

n_overlap <- inner_join(distinct(top1pct, id), top10pct_ids, by = "id") %>% nrow()

n_overlap_sentences <- top1pct %>%
  semi_join(top10pct_ids, by = "id") %>%
  nrow()

# --- Save raw stats ---
overlap_stats <- list(
  n_sentences_corpus_articles  = n_sentences_corpus_articles,
  n_sentences_corpus_sentences = n_sentences_corpus_sentences,
  n_articles_corpus            = n_articles_corpus,
  n_overlap_articles           = n_overlap,
  n_overlap_sentences          = n_overlap_sentences,
  pct_overlap_in_sentences_corpus = round(100 * n_overlap / n_sentences_corpus_articles, 1),
  pct_overlap_in_articles_corpus  = round(100 * n_overlap / n_articles_corpus, 1),
  pct_overlap_sentences           = round(100 * n_overlap_sentences / n_sentences_corpus_sentences, 1)
)

saveRDS(overlap_stats, file.path(data_path, "corpus_overlap_stats.rds"))
message("Saved: corpus_overlap_stats.rds")
