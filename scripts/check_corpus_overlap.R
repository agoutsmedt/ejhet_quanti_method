source(here::here("scripts", "paths_and_packages.R"))

# --- Load top 1% sentences (id-level) ---
top1pct <- read_feather(
  file.path(data_path, "top1pct_sentences_by_year.feather"),
  col_select = c("id", "sentence_id", "year")
)

# --- Load fulltexts cosine sim and derive top 10% per year ---
fulltexts <- read_feather(
  file.path(data_path, "fulltexts_cosine_sim_with_rv.feather"),
  col_select = c("id", "year", "cosine_doc_with_rv")
)

top10pct_ids <- fulltexts %>%
  slice_max(cosine_doc_with_rv, prop = 0.1, with_ties = FALSE) %>%
  select(id) %>%
  distinct()

# --- Unique article IDs in each corpus ---
top1pct_article_ids <- top1pct %>% distinct(id)

n_top1pct_articles   <- nrow(top1pct_article_ids)
n_top10pct_articles  <- nrow(top10pct_ids)
n_top1pct_sentences  <- nrow(top1pct)

# --- Overlap at the article level ---
overlap_articles <- inner_join(top1pct_article_ids, top10pct_ids, by = "id")
n_overlap_articles <- nrow(overlap_articles)

# --- Overlap at the sentence level ---
# sentences whose parent article is in the top 10%
overlap_sentences <- top1pct %>%
  semi_join(top10pct_ids, by = "id")
n_overlap_sentences <- nrow(overlap_sentences)

# --- Report ---
cat("=== Corpus overlap report ===\n\n")

cat(glue("Top 1% sentences corpus:
  Articles  : {n_top1pct_articles}
  Sentences : {n_top1pct_sentences}\n\n"))

cat(glue("Top 10% articles corpus:
  Articles  : {n_top10pct_articles}\n\n"))

cat(glue("Overlap (articles in BOTH corpora):
  N         : {n_overlap_articles}
  % of top-1pct articles  : {round(100 * n_overlap_articles / n_top1pct_articles, 1)}%
  % of top-10pct articles : {round(100 * n_overlap_articles / n_top10pct_articles, 1)}%\n\n"))

cat(glue("Sentences from top-1pct whose article is also in top-10pct:
  N         : {n_overlap_sentences}
  % of top-1pct sentences : {round(100 * n_overlap_sentences / n_top1pct_sentences, 1)}%\n\n"))

# --- Per-year breakdown ---
overlap_by_year <- top1pct %>%
  semi_join(top10pct_ids, by = "id") %>%
  count(year, name = "n_overlap_sentences") %>%
  left_join(
    top1pct %>% count(year, name = "n_top1pct_sentences"),
    by = "year"
  ) %>%
  mutate(pct = round(100 * n_overlap_sentences / n_top1pct_sentences, 1)) %>%
  arrange(year)

cat("Per-year overlap (sentences):\n")
print(overlap_by_year, n = Inf)
