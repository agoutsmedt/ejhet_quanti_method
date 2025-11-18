#: Measuring semantic drift ---------
#
# Script goals:
# - Compute and visualise semantic drift over time using sentence embedding centroids.
# - Produce year-to-year proto-distance (PRT) drift, average pairwise distance (APD)
#   series and heatmaps, and identify candidate driver tokens contributing to drift.
#
# Setup Instructions:
# - This script expects `scripts/paths_and_packages.R` to set `data_path`,
#   `image_path_temp`, `jstor_data_path` and to load commonly used packages
#   (arrow, dplyr, purrr, tibble, here, stringr, ggplot2, etc.). Source that
#   file before running this script (done below). Also source `scripts/_functions.R`
#   which contains the helper functions used here.
#
# How it works (high-level):
# 1) Load representative vectors per year and build a year x dimension matrix.
# 2) Compute year-to-year proto-distance drift and visualise (line + heatmap).
# 3) Compute Average Pairwise Distance (APD) across sentence embeddings by year
#    for several sentence sets (top-1% closest to query, sentences containing
#    "rationality" or "rational"). Visualise APD drift and heatmaps.
# 4) Build per-year centroid matrices for token-specific sentence sets and run
#    a driver extraction pipeline that identifies candidate n-grams driving drift.
#
# Note: This file focuses on readability and documentation. It does not change
# the computational logic; all edits are refactors, variable renames, and
# explanatory comments.

source(file.path("scripts", "paths_and_packages.R"))
source(file.path("scripts", "_functions.R"))
p_load(patchwork)

#: Load representative vectors and prepare matrix ---------
# Load a feather file containing per-year representative vectors. The file is
# expected to have a list-column `embedding_by_year` (one numeric vector per year).
# We filter for the target year range, unnest the vector column and add a
# `dimension` index so we can pivot into a matrix (rows = year, cols = dimension).
rep_vectors_by_year <- read_feather(here::here(
  data_path,
  "representative_vectors_window_5.feather"
)) |>
  dplyr::filter(between(year, 1900, 2009)) |>
  dplyr::select(year, embedding_by_year) |>
  tidyr::unnest(embedding_by_year) |>
  dplyr::mutate(dimension = row_number(), .by = year)

##: Build a numeric matrix (year x embedding dimension)
# xtabs pivots long -> wide; as.matrix converts it to a plain numeric matrix
# expected by downstream functions.
rep_mat <- xtabs(
  formula = embedding_by_year ~ year + dimension,
  data = rep_vectors_by_year
)
rep_mat <- as.matrix(rep_mat)

#: Compute proto-distance (PRT) drift ---------
# `consecutive_proto_drift()` computes year-to-year proto-distance using the
# provided numeric matrix (rows = years). The result is suitable for plotting.
drift <- consecutive_proto_drift(rep_mat) # year-to-year PRT drift

#: Visualise PRT drift ---------
prt_drift <- plot_semantic_drift(drift, value_col = "prt", smooth = TRUE)
ggsave(
  filename = here::here(
    image_path_temp,
    "prt_representative_vectors_drift.png"
  ),
  width = 8,
  height = 5
)

#: Heatmap of proto-distance matrix ---------
prt_dm <- proto_distance_matrix(rep_mat)
prt_heatmap <- plot_distance_heatmap(prt_dm)
ggsave(
  filename = here::here(
    image_path_temp,
    "prt_representative_vectors_heatmap.png"
  ),
  width = 8,
  height = 6
)

#: APD on top 1% closest sentences to "rationality" ---------
# Load a precomputed RDS with the top-1% closest sentences (to a query) and
# their embeddings. We restrict to the analysis years and compute APD by year.
top1pct_bert_df <- read_rds(file.path(
  data_path,
  "closest_sentences_0.01_rationality_score_filtered_with_embeddings.rds"
)) |>
  dplyr::filter(between(publication_year, 1900, 2009))

apd_sentence_matrix <- compute_apd_by_years(
  top1pct_bert_df,
  year_col = "publication_year",
  embeddings_col = "embedding",
  chunk_size = 5000L
)

# Persist results for reproducibility
apd_output_path <- file.path(data_path, "apd_sentence_embeddings_years.rds")
saveRDS(apd_sentence_matrix, apd_output_path)

# Quick helper: build a tidy drift tibble from the APD matrix for plotting
years_apd <- rownames(apd_sentence_matrix)
year_col <- years_apd[-1]
year_prev_col <- years_apd[-length(years_apd)]
idx <- seq_len(length(years_apd) - 1)
apd_vals <- as.numeric(apd_sentence_matrix[cbind(idx + 1, idx)])

apd_drift <- tibble::tibble(
  year = year_col,
  year_prev = year_prev_col,
  apd = apd_vals
)

plot_semantic_drift(apd_drift, value_col = "apd", smooth = TRUE)
ggsave(
  filename = here::here(image_path_temp, "apd_sentence_embeddings_drift.png"),
  width = 8,
  height = 5
)

plot_distance_heatmap(
  apd_sentence_matrix,
  legend_title = "Average Pairwise\nDistance"
)
ggsave(
  filename = here::here(image_path_temp, "apd_sentence_embeddings_heatmap.png"),
  width = 8,
  height = 6
)

#: Anchor plot — APD relative to anchor years ---------
apd_anchor_sentences <- plot_anchor(
  apd_sentence_matrix,
  anchors = seq(1920, 2000, by = 10),
  facet = TRUE,
  scales = "free_y"
) +
  ggplot2::ggtitle("APD of top 1% sentences to various anchor years")
ggsave(
  filename = here::here(
    image_path_temp,
    "apd_sentence_embeddings_anchors_facet.png"
  ),
  plot = apd_anchor_sentences,
  width = 12,
  height = 8
)

#: APD for sentences containing "rationality" / "rational" ---------
# Use arrow::open_dataset() to lazily filter the remote feather dataset, then
# collect matching sentences into memory for APD computation.
dataset <- open_dataset(
  file.path(jstor_data_path, "sentences_embeddings"),
  format = "feather"
)

rationality_sentences <- dataset |>
  dplyr::filter(
    between(publication_year, 1900, 2009),
    stringr::str_detect(
      sentence,
      regex("\\brationality\\b", ignore_case = TRUE)
    )
  ) |>
  dplyr::collect()

rational_sentences <- dataset |>
  dplyr::filter(
    between(publication_year, 1900, 2009),
    stringr::str_detect(sentence, regex("\\brational\\b", ignore_case = TRUE))
  ) |>
  dplyr::collect()

apd_rationality_sentence_matrix <- compute_apd_by_years(
  rationality_sentences,
  year_col = "publication_year",
  embeddings_col = "embedding",
  chunk_size = 5000L
)

apd_rational_sentence_matrix <- compute_apd_by_years(
  rational_sentences,
  year_col = "publication_year",
  embeddings_col = "embedding",
  chunk_size = 5000L
)

# Drop early years (pre-1920) where data are sparse to stabilise plots
apd_rationality_sentence_matrix <- apd_rationality_sentence_matrix[
  rownames(apd_rationality_sentence_matrix) >= "1920",
  colnames(apd_rationality_sentence_matrix) >= "1920"
]
apd_rational_sentence_matrix <- apd_rational_sentence_matrix[
  rownames(apd_rational_sentence_matrix) >= "1920",
  colnames(apd_rational_sentence_matrix) >= "1920"
]

years_rationality <- rownames(apd_rationality_sentence_matrix)
year_col <- years_rationality[-1]
year_prev_col <- years_rationality[-length(years_rationality)]
idx <- seq_len(length(years_rationality) - 1)
apd_rationality_vals <- as.numeric(apd_rationality_sentence_matrix[cbind(
  idx + 1,
  idx
)])
apd_rational_vals <- as.numeric(apd_rational_sentence_matrix[cbind(
  idx + 1,
  idx
)])

apd_rationality_drift <- tibble::tibble(
  year = year_col,
  year_prev = year_prev_col,
  apd_rationality = apd_rationality_vals,
  apd_rational = apd_rational_vals
)

plot_rationality_drift <- plot_semantic_drift(
  apd_rationality_drift,
  value_col = "apd_rationality",
  smooth = TRUE
)
plot_rational_drift <- plot_semantic_drift(
  apd_rationality_drift,
  value_col = "apd_rational",
  smooth = TRUE
)

combined_plot <- plot_rationality_drift + plot_rational_drift
ggsave(
  filename = here::here(image_path_temp, "apd_rationality_rational_drift.png"),
  plot = combined_plot,
  width = 10,
  height = 5
)

# Heatmaps: collect legends from both plots and place a single legend at the bottom
heatmap_rationality <- plot_distance_heatmap(
  apd_rationality_sentence_matrix,
  legend_title = "Average Pairwise\nDistance"
) +
  labs(title = "Rationality")
heatmap_rational <- plot_distance_heatmap(
  apd_rational_sentence_matrix,
  legend_title = "Average Pairwise\nDistance"
) +
  labs(title = "Rational")

combined_heatmap <- (heatmap_rationality + heatmap_rational) +
  plot_layout(guides = "collect") &
  theme(legend.position = "bottom")
ggsave(
  filename = here::here(
    image_path_temp,
    "apd_rationality_rational_heatmaps_shared_legend.png"
  ),
  plot = combined_heatmap,
  width = 12,
  height = 6
)

# Anchor plots for token-specific sets
apd_anchor_rationality <- plot_anchor(
  apd_rationality_sentence_matrix,
  anchors = seq(1930, 2000, by = 10),
  facet = TRUE
) +
  ggplot2::ggtitle(
    "APD of sentences with 'rationality' to various anchor years"
  )
ggsave(
  filename = here::here(
    image_path_temp,
    "apd_rationality_sentence_embeddings_anchors_facet.png"
  ),
  plot = apd_anchor_rationality,
  width = 12,
  height = 8
)

apd_anchor_rational <- plot_anchor(
  apd_rational_sentence_matrix,
  anchors = seq(1930, 2000, by = 10),
  facet = TRUE
) +
  ggplot2::ggtitle("APD of sentences with 'rational' to various anchor years")
ggsave(
  filename = here::here(
    image_path_temp,
    "apd_rational_sentence_embeddings_anchors_facet.png"
  ),
  plot = apd_anchor_rational,
  width = 12,
  height = 8
)

#: Build matrices for "rationality" and "rational" sentence sets ---------
# `top1pct_bert_df` contains the top-1% closest sentences to the query term and
# `rational_sentences`/`rationality_sentences` are the direct token matches.
mat_rationality <- build_year_centroid_mat(
  rationality_sentences,
  year_col = "publication_year",
  embedding_col = "embedding",
  years = 1900:2009
)

mat_rational <- build_year_centroid_mat(
  rational_sentences,
  year_col = "publication_year",
  embedding_col = "embedding",
  years = 1900:2009
)

#: Usage: supply named list of matrices to the driver pipeline ---------
matrices_to_process <- list(
  general = rep_mat,
  rational = mat_rational,
  rationality = mat_rationality
)

drivers_lists <- process_matrices_for_drivers(
  matrices = matrices_to_process,
  data_path = data_path,
  jstor_data_path = jstor_data_path,
  years_range = 1900:2008
)

# Loading previously computed combined results (optional)
load_drivers_lists <- TRUE
if (load_drivers_lists) {
  drivers_lists <- purrr::map(
    c("general", "rational", "rationality"),
    function(name) {
      read_rds(here::here(
        data_path,
        paste0("top_sentence_drivers_all_years_", name, ".rds")
      ))
    }
  )
  names(drivers_lists) <- c("general", "rational", "rationality")
}

#: Extract n-grams from driver sentence lists ---------
driver_tokens_list <- purrr::map(drivers_lists, function(df) {
  extract_ngrams(
    df,
    ngrams = 2L,
    grouping_cols = c(
      "sentence_id",
      "projection_score",
      "year_pair_start",
      "type"
    ),
    text_col = "sentence",
    min_nchar = 3L
  )
})

#: Create and save top-n driver plots per year and per decade ---------
# These functions save figures to `image_path_temp` and return the ggplot objects.
p_top2_new <- purrr::map2(
  driver_tokens_list,
  names(driver_tokens_list),
  ~ make_topn_driver_plot(
    driver_tokens = .x,
    top_n = 2L,
    min_corpus_tf = 20L,
    title_suffix = .y,
    out_file = here::here(
      image_path_temp,
      glue::glue("top2_new_drivers_per_year_{.y}.png")
    )
  )
)

p_topn_decade <- purrr::map2(
  driver_tokens_list,
  names(driver_tokens_list),
  ~ make_topn_driver_decade_plot(
    driver_tokens = .x,
    top_n = 6L,
    min_corpus_tf = 20L,
    title_suffix = .y,
    out_file = here::here(
      image_path_temp,
      glue::glue("topn_new_drivers_per_decade_{.y}.png")
    )
  )
)
