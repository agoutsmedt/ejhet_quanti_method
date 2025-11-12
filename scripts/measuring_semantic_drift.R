# The goal: using the representative vectors of sentence embeddings for each year to measure semantic drift over time
source(file.path("scripts", "paths_and_packages.R"))
source(file.path("scripts", "_functions.R"))
p_load(patchwork)

# Load per-year representative vectors (list-column: embedding_by_year_centered)
representative_vectors <- read_feather(here::here(
  data_path,
  "representative_vectors_window_5.feather"
)) |>
  filter(between(year, 1900, 2009)) |>
  select(year, embedding_by_year) |>
  unnest(embedding_by_year) |>
  mutate(dimension = row_number(), .by = year)

# Transform 3 columns table to matrix with xtabs
mat <- xtabs(
  formula = embedding_by_year ~ year + dimension,
  data = representative_vectors
)
mat <- as.matrix(mat)

# ---- usage ----
drift <- consecutive_proto_drift(mat) # year-to-year PRT drift

# Visualisations for year-to-year proto-distance (PRT) drift-------------

prt_drift <- plot_semantic_drift(drift, value_col = "prt", smooth = TRUE)
ggsave(
  filename = here::here(
    image_path_temp,
    "prt_representative_vectors_drift.png"
  ),
  width = 8,
  height = 5
)

# Heatmap of proto-distance matrix
dm <- proto_distance_matrix(mat)
prt_heatmap <- plot_distance_heatmap(dm)
ggsave(
  filename = here::here(
    image_path_temp,
    "prt_representative_vectors_heatmap.png"
  ),
  width = 8,
  height = 6
)

# Average Pairwise Distance on sentence embeddings------------------
## APD on top 1% closest sentences to "rationality" and "rational"-----------
bert_df <- read_rds(file.path(
  data_path,
  "closest_sentences_0.01_rationality_score_filtered_with_embeddings.rds"
)) %>%
  filter(between(publication_year, 1900, 2009))

apd_sentence_matrix <- compute_apd_by_years(
  bert_df,
  year_col = "publication_year",
  embeddings_col = "embedding",
  chunk_size = 5000L
)

# Persist to disk for downstream use (safe, reproducible path)
apd_output_path <- file.path(data_path, "apd_sentence_embeddings_years.rds")
saveRDS(apd_sentence_matrix, apd_output_path)

#' Load data if needed
#' `apd_sentence_matrix <- readRDS(file.path(data_path, "apd_sentence_embeddings_years.rds"))``

# plotting
years <- rownames(apd_sentence_matrix)
year_col <- years[-1]
year_prev_col <- years[-length(years)]

idx <- seq_len(length(years) - 1)
apd_vals <- as.numeric(apd_sentence_matrix[cbind(idx + 1, idx)])

# Return a tibble with the later year, previous year, and the proto-distance.
apd_drift <- tibble::tibble(
  year = year_col,
  year_prev = year_prev_col,
  apd = apd_vals
)

plot_semantic_drift(apd_drift, value_col = "apd", smooth = TRUE)
ggsave(
  filename = here::here(
    image_path_temp,
    "apd_sentence_embeddings_drift.png"
  ),
  width = 8,
  height = 5
)

plot_distance_heatmap(
  apd_sentence_matrix,
  legend_title = "Average Pairwise\nDistance"
)
ggsave(
  filename = here::here(
    image_path_temp,
    "apd_sentence_embeddings_heatmap.png"
  ),
  width = 8,
  height = 6
)

# Using anchor year
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

## APD on sentences with "rationality"------------
dataset <- open_dataset(
  file.path(data_path, "sentences_embeddings"),
  format = "feather"
)

rationality_sentences <- dataset %>%
  filter(
    between(publication_year, 1900, 2009),
    str_detect(sentence, regex("\\brationality\\b", ignore_case = TRUE))
  ) %>%
  collect()

rational_sentences <- dataset %>%
  filter(
    between(publication_year, 1900, 2009),
    str_detect(sentence, regex("\\brational\\b", ignore_case = TRUE))
  ) %>%
  collect()

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

# Drop years before 1910
apd_rationality_sentence_matrix <- apd_rationality_sentence_matrix[
  rownames(apd_rationality_sentence_matrix) >= "1920",
  colnames(apd_rationality_sentence_matrix) >= "1920"
]
apd_rational_sentence_matrix <- apd_rational_sentence_matrix[
  rownames(apd_rational_sentence_matrix) >= "1920",
  colnames(apd_rational_sentence_matrix) >= "1920"
]

# plotting
years <- rownames(apd_rationality_sentence_matrix)
year_col <- years[-1]
year_prev_col <- years[-length(years)]
idx <- seq_len(length(years) - 1)
apd_rationality_vals <- as.numeric(apd_rationality_sentence_matrix[cbind(
  idx + 1,
  idx
)])
apd_rational_vals <- as.numeric(apd_rational_sentence_matrix[cbind(
  idx + 1,
  idx
)])
# Return a tibble with the later year, previous year, and the proto-distance.
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
  filename = here::here(
    image_path_temp,
    "apd_rationality_rational_drift.png"
  ),
  plot = combined_plot,
  width = 10,
  height = 5
)

# Heatmaps
# collect legends from both plots and place a single legend at the bottom
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

# return the combined plot object and (optionally) save it
ggsave(
  filename = here::here(
    image_path_temp,
    "apd_rationality_rational_heatmaps_shared_legend.png"
  ),
  plot = combined_heatmap,
  width = 12,
  height = 6
)

# Anchor plots
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

# Analysing drift in specific dimensions------------------
# Example usage of rank_drivers_for_year_pair (sequential, disk-backed to avoid memory growth)
output_dir <- file.path(data_path, "top_sentence_drivers_year_pairs")
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
}

years_already_processed <- list.files(
  output_dir,
  pattern = "^drivers_\\d{4}\\.rds$",
  full.names = FALSE
) %>%
  str_extract("\\d{4}") %>%
  as.integer()

years_to_process <- 1900:2008L |>
  setdiff(years_already_processed)
processed_files <- character(0)

for (yr in years_to_process) {
  cli::cli_inform(glue::glue("Starting year {yr}"))
  out_path <- file.path(output_dir, glue::glue("drivers_{yr}.rds"))

  if (file.exists(out_path)) {
    cli::cli_inform(glue::glue("Skipping {yr} — output exists at {out_path}"))
    processed_files <- c(processed_files, out_path)
    next
  }

  res <- tryCatch(
    {
      rank_drivers_for_year_pair(
        mat = mat,
        year_t = yr,
        year_col = "publication_year",
        embedding_col = "embedding",
        top_n = 200L,
        normalize_rows = TRUE,
        chunk_threshold = 200000L,
        data_path = data_path
      )
    },
    error = function(e) {
      cli::cli_alert_danger(glue::glue("Error processing {yr}: {e$message}"))
      NULL
    },
    warning = function(w) {
      cli::cli_alert_warning(glue::glue("Warning processing {yr}: {w$message}"))
      invokeRestart("muffleWarning")
    }
  )

  if (is.null(res)) {
    next
  }

  saveRDS(res, out_path) # small object per year
  processed_files <- c(processed_files, out_path)

  # free memory promptly
  rm(res)
  gc()
  cli::cli_inform(glue::glue("Saved results for {yr} → {out_path}"))
}

# Optionally: combine all per-year files into a single list and persist once (small).
combined_path <- file.path(data_path, "top_sentence_drivers_all_years.rds")
if (!file.exists(combined_path) && length(processed_files) > 0) {
  all_processed_files <- list.files(
    output_dir,
    pattern = "^drivers_\\d{4}\\.rds$",
    full.names = TRUE
  )
  years_processed <- all_processed_files %>%
    str_extract("\\d{4}") %>%
    as.integer()
  all_list <- purrr::map(all_processed_files, readRDS)
  names(all_list) <- paste0(years_processed)
  all_list <- bind_rows(all_list, .id = "year_pair_start")
  saveRDS(all_list, combined_path)
  cli::cli_inform(glue::glue("Combined file written to {combined_path}"))
}

# Visualising results
setDT(all_list, key = "id")
# Updated: support arbitrary n-grams (scalar max or vector of n values)
extract_ngrams <- function(
  df,
  ngrams = c(1L, 2L), # either integer scalar (max n) or integer vector of n values
  grouping_cols = c(
    "year_pair_start",
    "type"
  ),
  text_col = "sentence",
  min_nchar = 2L,
  stop_words = NULL
) {
  if (!requireNamespace("tokenizers", quietly = TRUE)) {
    stop("Please install the 'tokenizers' package.")
  }
  if (!requireNamespace("tidytext", quietly = TRUE)) {
    stop("Please install the 'tidytext' package.")
  }
  if (!requireNamespace("stringr", quietly = TRUE)) {
    stop("Please install the 'stringr' package.")
  }
  data.table::setDT(df)

  if (is.null(stop_words)) {
    stop_words <- unique(tidytext::stop_words$word)
  }
  stop_words <- tolower(stop_words)

  required_cols <- unique(c(
    grouping_cols,
    text_col
  ))
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(
      "Missing required columns in df: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  # Normalize ngrams input: if scalar -> 1:max, else use provided vector
  if (length(ngrams) == 1L) {
    ng_range <- seq_len(as.integer(ngrams))
  } else {
    ng_range <- as.integer(ngrams)
  }

  # generate token data.tables for each ngram and rbind
  token_list <- lapply(ng_range, function(n) {
    tmp <- df[, c(grouping_cols, text_col), with = FALSE]
    tmp[,
      token := tokenizers::tokenize_ngrams(
        get(text_col),
        n = as.integer(n),
        lowercase = TRUE
      )
    ]
    tmp[, (text_col) := NULL]
    tmp[, ngram := as.integer(n)]
    tmp
  })

  tokens <- data.table::rbindlist(token_list, use.names = TRUE, fill = TRUE)

  # unnest list-column of tokens into rows, grouped by desired grouping columns + ngram
  tokens <- tokens[, .(token = unlist(token)), by = c(grouping_cols, "ngram")]

  # filter short tokens
  tokens <- tokens[nchar(token) >= as.integer(min_nchar), ]

  # split token into words (list column) to enable multi-word checks
  tokens[, words := strsplit(token, " ", fixed = TRUE)]

  # remove tokens containing digits in any part
  tokens[,
    has_digit := vapply(words, function(ws) any(grepl("[0-9]", ws)), logical(1))
  ]

  # remove tokens containing stopwords in any part
  tokens[,
    has_stop := vapply(words, function(ws) any(ws %in% stop_words), logical(1))
  ]

  tokens <- tokens[!has_digit & !has_stop]

  # keep grouping columns + token, replace spaces with underscores for multi-word tokens
  tokens <- tokens[, c(grouping_cols, "token", "ngram"), with = FALSE]
  tokens[, token := stringr::str_replace_all(token, " ", "_")]

  # return result (data.table)
  tokens[]
}
all_list[, sentence_id := .I]

driver_tokens <- all_list |>
  extract_ngrams(
    ngrams = 2L,
    grouping_cols = c("year_pair_start", "type"),
    text_col = "sentence",
    min_nchar = 3L
  )

tf_idf_drivers <- driver_tokens %>%
  compute_tf_idf(document_col = c("year_pair_start", "type"))
tf_idf_drivers <- tf_idf_drivers[absolute_tf > 10, ]

# Plot of top 2 per year
# Keep only 'new' drivers, select top 2 by tf_idf per year, and build a plot with years on x-axis
top2_new_per_year <- tf_idf_drivers |>
  filter(type == "new") |>
  group_by(year_pair_start) |>
  slice_max(tf_idf, n = 2, with_ties = FALSE) |>
  ungroup() |>
  mutate(
    year = as.integer(year_pair_start),
    token = as.character(token)
  )

yr_seq <- seq(min(top2_new_per_year$year), max(top2_new_per_year$year), by = 5)

p_top2_new <- ggplot(
  top2_new_per_year,
  aes(x = year, y = tf_idf, group = token)
) +
  geom_text_repel(
    aes(label = token),
    angle = 90,
    hjust = 0,
    vjust = 0.5,
    show.legend = FALSE,
    na.rm = TRUE,
    direction = "y", # only repel vertically
    force = 6, # increase repulsive force -> larger displacement
    box.padding = 0.6, # space around label boxes
    point.padding = 0.25, # padding around the data point
    segment.size = 0,
    max.iter = 5000, # allow more iterations for placement
    seed = 42
  ) +
  scale_x_continuous(breaks = yr_seq) +
  scale_y_continuous(expand = expansion(mult = c(0.02, 0.5))) + # give extra headroom
  coord_cartesian(clip = "off") + # let labels extend outside panel
  labs(
    title = "Top 2 'new' drivers per year (by TF-IDF)",
    x = NULL,
    y = "TF-IDF",
    colour = "Token"
  ) +
  theme_minimal() +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "none",
    plot.margin = ggplot2::margin(t = 5, r = 60, b = 5, l = 5, unit = "pt") # space for long labels
  )

p_top2_new
