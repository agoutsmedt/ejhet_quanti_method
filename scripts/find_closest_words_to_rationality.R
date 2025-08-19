#' Find words "closest" to "rationality" and "rational", based on our extracted
#' paragraphs, using TF-IDF
#'
#' This script:
#' \itemize{
#'   \item Tokenizes paragraphs (unigrams + bigrams) around target words.
#'   \item Cleans tokens (min length, digits, stopwords, non-ASCII).
#'   \item Aggregates by time windows (e.g., 1990s → "1990s").
#'   \item Computes TF-IDF by time window.
#'   \item Plots top tokens overall and by target ("rationality", "rational").
#' }

source(file.path("scripts", "paths_and_packages.R"))
paragraphs <- read_parquet(here::here(jstor_raw_data, "paragraphs_with_target_word.parquet"))
setDT(paragraphs)

# --- Time windows (ensure character for str_replace) ---
paragraphs[, time_window := stringr::str_replace(as.character(publication_year), "\\d$", "0s")]

# --- Tokenization: unigrams & bigrams ---
# NOTE: use !"window" to drop the column in data.table
unigrams <- paragraphs[, .(id, window, time_window, target_word)
][, token := tokenizers::tokenize_words(window, strip_numeric = TRUE, lowercase = TRUE)
][, !"window"]

bigrams <- paragraphs[, .(id, window, time_window, target_word)
][, token := tokenizers::tokenize_ngrams(window, n = 2, lowercase = TRUE)
][, !"window"]

tokens <- rbind(unigrams, bigrams)
tokens <- tokens[, .(token = unlist(token)), by = .(time_window, target_word)]

# --- Basic cleanup ---
tokens <- tokens[nchar(token) >= 3]
tokens[, c("word_1", "word_2") := tstrsplit(token, " ")]

# Stopword filtering (either part of bigram cannot be a stopword)
stop_words <- unique(tidytext::stop_words$word)
tokens <- tokens[
  # Remove any digits in either word
  !grepl("[0-9]", word_1) & (is.na(word_2) | !grepl("[0-9]", word_2)) &
    # Remove stopwords in either word
    !(word_1 %in% stop_words) &
    (is.na(word_2) | !(word_2 %in% stop_words))
]

# Remove non-ASCII (e.g., 𝒫, greek letters...)
tokens <- tokens[!stringr::str_detect(token, "[^\\p{ASCII}]")]

#' Plot top TF-IDF tokens from tokenized data
#'
#' Computes TF-IDF via \code{compute_tf_idf()}, filters top tokens per document group,
#' and produces a faceted bar chart; optionally saves to disk.
#'
#' @param data \code{data.table} with at least \code{token_col}, \code{document_col};
#'   may include \code{target_word} used for filtering.
#' @param filter_expr Optional character expression evaluated in \code{data} (e.g., \code{"target_word == 'rationality'"}).
#' @param token_col Name of the token column (default: \code{"token"}).
#' @param document_col Name of the document group column (default: \code{"time_window"}).
#' @param abs_tf_thresh Keep tokens with \code{absolute_tf} greater than this (default: 20).
#' @param max_tokens Number of top tokens per facet (default: 20).
#' @param exclude_time_pattern Regex to exclude document groups (default: \code{"^18|^202"}).
#' @param title Plot title.
#' @param filename Optional path to save PNG with \code{ggsave()}.
#'
#' @return Invisibly prints the ggplot and saves if \code{filename} is provided.
#' @examples
#' # plot_tf_idf_from_tokens(tokens, filter_expr = "target_word == 'rationality'")
plot_tf_idf_from_tokens <- function(
    data,
    filter_expr = NULL,
    token_col = "token",
    document_col = "time_window",
    abs_tf_thresh = 20,
    max_tokens = 20,
    exclude_time_pattern = "^18|^202",
    title = "TF-IDF Plot",
    filename = NULL
) {
  # Optional filter on target_word or others
  if (!is.null(filter_expr)) {
    data <- data[eval(parse(text = filter_expr))]
  }
  
  # Drop target_word before TF-IDF if present (not needed by compute_tf_idf)
  if ("target_word" %in% names(data)) {
    data <- data[, !"target_word"]
  }
  
  # Compute TF-IDF (requires your compute_tf_idf() in scope)
  tfidf_dt <- compute_tf_idf(data, token_col = token_col, document_col = document_col)
  
  # Get top tokens per document group
  top_terms <- tfidf_dt[
    absolute_tf > abs_tf_thresh &
      !stringr::str_detect(get(document_col), exclude_time_pattern)
  ][order(-tf_idf), head(.SD, max_tokens), by = get(document_col)]
  
  # Plot
  p <- top_terms %>%
    dplyr::mutate(
      !!token_col := tidytext::reorder_within(.data[[token_col]], tf_idf, .data[[document_col]])
    ) %>%
    ggplot2::ggplot(ggplot2::aes(x = .data[[token_col]], y = tf_idf)) +
    ggplot2::geom_col(fill = "#2C77B8") +
    ggplot2::facet_wrap(stats::as.formula(paste("~", document_col)), scales = "free") +
    ggplot2::coord_flip() +
    tidytext::scale_x_reordered() +
    ggplot2::labs(title = title, x = "Token", y = "TF-IDF") +
    ggplot2::theme_minimal(base_size = 20)
  
  print(p)
  
  if (!is.null(filename)) {
    ggplot2::ggsave(filename, plot = p, width = 60, height = 40, units = "cm", dpi = 300)
  }
  
  invisible(p)
}

# --- Global plot (all paragraphs containing either target) ---
plot_tf_idf_from_tokens(
  data = tokens,
  abs_tf_thresh = 20,
  filename = "pictures/tf_idf_closest_words_to_rational_rationality.png",
  title = "Top TF-IDF Tokens in Rational and Rationality paragraphs"
)

# --- Separate plots per target ---
for (target in c("rationality", "rational")) {
  plot_tf_idf_from_tokens(
    data = tokens,
    abs_tf_thresh = 20,
    filter_expr = glue::glue("target_word == '{target}'"),
    filename = glue::glue("pictures/tf_idf_closest_words_to_{target}.png"),
    title = glue::glue("Top TF-IDF Tokens in {target} paragraphs")
  )
}
