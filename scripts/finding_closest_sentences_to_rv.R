# Finding closest sentences -----------------------------------------------------

# Load paths and packages defined elsewhere
source(file.path("scripts", "paths_and_packages.R"))

# Ensure text2vec is available (for cosine similarity)
p_load(text2vec)

# Load per-year representative vectors (list-column: embedding_by_year_centered)
representative_vectors <- read_feather(here::here(
  data_path,
  "representative_vectors_window_5.feather"
))

# Load sentences to delete
sentences_to_delete <- read_feather(here::here(
  data_path,
  "sentences_to_delete.feather"
))


# --- CONFIG -------------------------------------------------------------------
# Directory that holds per-year sentence embeddings as Feather files:
#   expected names: sentence_embeddings_<YEAR>.feather
emb_dir <- here::here(jstor_raw_data, "sentences_embeddings")

# Optional: list the files in the embeddings directory (not used below)
sentence_files <- list.files(emb_dir)

# --- RESUME LOGIC -------------------------------------------------------------
# If a previous results file exists, resume from it; otherwise initialize a list
existing_sentence_file <- list.files(data_path) %>%
  .[str_detect(
    .,
    "^closest_sentences_\\d+\\.\\d+_filtered_rationality_score_window_5\\.rds$"
  )] # NOTE: stricter regex

if (length(existing_sentence_file) > 0) {
  list_sentences <- readRDS(here::here(data_path, existing_sentence_file))
  # years_done: names with a non-empty data.frame/tibble entry
  years_done <- names(compact(list_sentences))
  years_to_do <- representative_vectors$year[
    !representative_vectors$year %in% years_done
  ]
} else {
  list_sentences <- vector("list", length(representative_vectors$year))
  names(list_sentences) <- representative_vectors$year
  years_to_do <- representative_vectors$year
}

# --- MAIN LOOP ---------------------------------------------------------------
for (year in years_to_do) {
  cli::cli_alert_info("Processing year {year}...")

  # 1) Representative vector for this year (numeric length == embedding dim)
  representative_vector <- representative_vectors %>%
    filter(year == !!year) %>%
    pull(embedding_by_year_centered) %>%
    unlist() %>%
    as.numeric()

  # 2) Load that year's sentence embeddings: tibble with list-col `embedding`
  sentence_embeddings <- read_feather(
    here::here(emb_dir, glue("sentence_embeddings_{year}.feather"))
  )

  # filter out sentences to delete
  sentences_year_to_delete <- sentences_to_delete %>%
    filter(year == !!year) %>%
    pull(sentence)

  sentence_embeddings <- sentence_embeddings %>%
    filter(!sentence %in% sentences_year_to_delete)

  # 3) Build an embedding matrix (rows = sentences, cols = embedding dims)
  #    NOTE: do.call(rbind, ...) allocates once; OK if per-year file fits RAM
  emb_matrix <- do.call(rbind, sentence_embeddings$embedding)

  # 4) Cosine similarity between all sentences and the representative vector
  #    text2vec::sim2 returns a matrix; coerce to numeric vector for safety
  sims_mat <- sim2(
    emb_matrix,
    matrix(representative_vector, nrow = 1),
    method = "cosine",
    norm = "l2"
  )
  sims <- as.numeric(sims_mat[, 1]) # NOTE: avoid matrix recycling pitfalls

  # 5) Keep top 1% within the year; attach mean(similarity) for that year
  #    NOTE: quantile over numeric vector (not matrix) for clarity
  cutoff <- stats::quantile(sims, 0.99, na.rm = TRUE)

  list_sentences[[as.character(year)]] <- sentence_embeddings %>%
    mutate(
      similarity = sims,
      mean_year_similarity = mean(similarity, na.rm = TRUE)
    ) %>%
    arrange(dplyr::desc(similarity)) %>%
    select(-embedding) %>%
    filter(similarity > cutoff)

  # 6) Free memory used by large objects before next iteration
  rm(
    sentence_embeddings,
    emb_matrix,
    sims_mat,
    sims,
    cutoff,
    sentences_year_to_delete
  )
  gc()

  # 7) Persist progress after each year (robust to crashes)
  saveRDS(
    list_sentences,
    here::here(
      data_path,
      glue::glue(
        "closest_sentences_0.01_filtered_rationality_score_window_5.rds"
      )
    )
  )
}


# load the results
closest_sentences <- readRDS(here::here(
  data_path,
  "closest_sentences_0.01_filtered_rationality_score.rds"
))

df_closed_sentences <- bind_rows(closest_sentences)

# plot distribution of sentences by year

df_closed_sentences %>%
  filter(publication_year < 2020) %>%
  count(publication_year) %>%
  ggplot(aes(x = publication_year, y = n)) +
  geom_point() +
  labs(
    x = "Year",
    y = "Number of sentences"
  ) +
  theme_light(base_size = 12)

# save the results
ggsave(
  filename = here::here(
    image_path_temp,
    "distribution_closest_sentences_by_year.png"
  ),
  width = 10,
  height = 6,
  units = "in",
  dpi = 300
)
