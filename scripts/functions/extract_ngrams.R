#: Method for text analysis-------------------------

#' Extract n-grams from text with basic filtering and grouping
#'
#' @title Extract n-grams from text
#' @description Tokenise text into n-grams (unigrams, bigrams, etc.) per group, remove
#'   tokens containing digits or stop words, and return a compact data.table of tokens.
#'
#' @param df data.frame or data.table containing the input rows. Must include the columns named
#'   in `grouping_cols` and `text_col`. Note: the function calls `data.table::setDT(df)` and
#'   therefore will convert and mutate `df` by reference; pass `data.table::copy(df)` if you
#'   want to avoid in-place modification.
#' @param ngrams integer scalar or integer vector. If scalar (e.g. `2L`) it is interpreted
#'   as `1:ngrams` (i.e. all n from 1 to that value). If a vector (e.g. `c(1L,2L)`), those
#'   exact n values are used. Values are coerced to integers.
#' @param grouping_cols character vector of column names to keep as grouping keys.
#' These columns are preserved in the output and used to group token rows.
#' @param text_col character scalar. Name of the text column containing sentences to tokenise
#'   (default: `"sentence"`). NA values in the text column are handled as empty input to the
#'   tokenizer (they will not produce tokens).
#' @param min_nchar integer scalar. Minimum number of characters a token must have to be kept.
#'   Defaults to `2L`. Tokens shorter than this are removed.
#' @param stop_words NULL or character vector of words to treat as stop words. If `NULL`
#'   the function uses `tidytext::stop_words$word`. Matching is case-insensitive: all
#'   stop words are lower-cased before comparison.
#'
#' @return A data.table with columns:
#'   - the `grouping_cols` (in the same order as provided),
#'   - `token` (character scalar; multi-word tokens have internal spaces replaced with `_`),
#'   - `ngram` (integer scalar).
#'   Returns an empty data.table with those columns if no tokens survive filtering.
#'   The function throws an error if required packages are missing or if required columns
#'   are not present in `df`.
#'
#' @details This function produces n-grams per row of `df`, preserves the grouping columns,
#'   filters tokens that contain digits or any stop word, and normalises multi-word tokens by
#'   replacing spaces with underscores. It is intended for downstream term-frequency and
#'   TF-IDF computations on grouped text.
#'
#' Implementation notes:
#' - Steps:
#'   1. Validate required namespaces (`tokenizers`, `tidytext`, `stringr`) are available.
#'   2. Convert `df` to a `data.table` in-place (fast, but mutates `df`).
#'   3. Compute the set of `ngram` sizes to generate (either `1:ngrams` when scalar or the
#'      provided vector).
#'   4. For each `n`, call `tokenizers::tokenize_ngrams()` to obtain a list-column of tokens,
#'      then unnest to one token per row.
#'   5. Remove tokens shorter than `min_nchar`, tokens containing digits, or tokens that
#'      contain any stop word component (checked per token word).
#'   6. Replace internal spaces with underscores for multi-word tokens and return a data.table.
#' - Assumptions and preconditions:
#'   - `df` contains the named grouping and text columns.
#'   - `tokenizers::tokenize_ngrams()` returns a list of character vectors per row.
#' - Edge-case handling and failure modes:
#'   - If required packages are not installed the function stops with an informative message.
#'   - If required columns are missing the function stops listing the missing names.
#'   - If no tokens survive filtering the function returns an empty data.table with the
#'     expected column set rather than `NULL`.
#' - Trade-offs:
#'   - The function uses `data.table` for speed and memory efficiency; this also means the
#'     input `df` is modified by reference which can be surprising — callers should copy if
#'     needed.
#' - Dependencies: `tokenizers`, `tidytext`, `stringr`, `data.table`.
#'
#' @implementation Uses `tokenizers::tokenize_ngrams()` for token generation and `data.table`
#'   operations for efficient unnesting and filtering. Stop words are lower-cased and matched
#'   at the component-word level; digits are detected using a simple `grepl("[0-9]", ...)`.
#'
#' @examples
#' # minimal example
#' df <- data.frame(
#'   year_pair_start = c("1900", "1910"),
#'   type = c("new", "old"),
#'   sentence = c("Rationality matters", "A new rational method"),
#'   stringsAsFactors = FALSE
#' )
#' # extract unigrams and bigrams
#' if (requireNamespace("tokenizers", quietly = TRUE)) {
#'   out <- extract_ngrams(df, ngrams = 2L, grouping_cols = c("year_pair_start", "type"))
#'   head(out)
#' }
#'
#' # edge-case: tokens with digits are removed
#' df2 <- data.frame(
#'   year_pair_start = "2000",
#'   type = "new",
#'   sentence = "Model 42 predicts 8 outcomes",
#'   stringsAsFactors = FALSE
#' )
#' if (requireNamespace("tokenizers", quietly = TRUE)) {
#'   extract_ngrams(df2, ngrams = 1L)
#' }
#'
#' @keywords internal
#' @seealso tokenizers::tokenize_ngrams, tidytext::stop_words
#' @author Your Name
extract_ngrams <- function(
  df,
  ngrams = 2L,
  grouping_cols = NULL,
  text_col = "text",
  min_nchar = 2L,
  stop_words = NULL
) {
  # Ensure required packages are available before doing any in-place changes
  if (!requireNamespace("tokenizers", quietly = TRUE)) {
    stop("Please install the 'tokenizers' package.")
  }
  if (!requireNamespace("tidytext", quietly = TRUE)) {
    stop("Please install the 'tidytext' package.")
  }
  if (!requireNamespace("stringr", quietly = TRUE)) {
    stop("Please install the 'stringr' package.")
  }

  # Convert to data.table in-place for performance. This mutates `df` by reference.
  # If the caller wants to preserve the original, they should call data.table::copy(df).
  data.table::setDT(df)

  # Default stop words from tidytext if none provided; normalise to lower-case
  if (is.null(stop_words)) {
    stop_words <- unique(tidytext::stop_words$word)
  }
  stop_words <- tolower(stop_words)

  # Validate required columns exist
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

  # For each requested ngram size generate a temporary data.table with a list-column `token`
  token_list <- lapply(ng_range, function(n) {
    # copy only needed columns to keep memory use low (grouping + text)
    tmp <- df[, c(grouping_cols, text_col), with = FALSE]

    # tokenizers::tokenize_ngrams returns a list of character vectors (one element per row).
    # Use get() to refer to the text column by name inside data.table's environment.
    tmp[,
      token := tokenizers::tokenize_ngrams(
        get(text_col),
        n = as.integer(n),
        lowercase = TRUE,
      )
    ]

    # remove the original text column (we only need grouping + token list)
    tmp[, (text_col) := NULL]

    # record the ngram size for later filtering/analysis
    tmp[, ngram := as.integer(n)]

    tmp
  })

  # Stack all ngram tables into one
  tokens <- data.table::rbindlist(token_list, use.names = TRUE, fill = TRUE)

  # Unnest the list-column of tokens into one token per row, preserving grouping + ngram
  # `unlist()` flattens each element. The by= ensures grouping columns remain as columns.
  tokens <- tokens[, .(token = unlist(token)), by = c(grouping_cols, "ngram")]

  # Filter out tokens that are too short
  tokens <- tokens[nchar(token) >= as.integer(min_nchar), ]

  # faster vectorised splitting (stringi is much quicker than base strsplit)
  word_columns <- stringr::str_c("word_", seq_len(max(ng_range)))
  tokens[, (word_columns) := tstrsplit(token, " ", fixed = TRUE)]

  # detect digits in any component word (NA -> FALSE)
  tokens[,
    has_digit := Reduce(
      `|`,
      lapply(.SD, function(x) {
        xi <- as.character(x)
        !is.na(xi) & grepl("[0-9]", xi)
      })
    ),
    .SDcols = word_columns
  ]

  # detect stop words in any component word (stop_words assumed lower-case)
  tokens[,
    has_stop := Reduce(
      `|`,
      lapply(.SD, function(x) {
        xi <- as.character(x)
        !is.na(xi) & (xi %in% stop_words)
      })
    ),
    .SDcols = word_columns
  ]

  # Keep only tokens without digits and without stop words
  tokens <- tokens[!has_digit & !has_stop]

  # Keep only the requested output columns; replace spaces with underscores in multi-word tokens
  tokens <- tokens[, c(grouping_cols, "token", "ngram"), with = FALSE]
  tokens[, token := stringr::str_replace_all(token, " ", "_")]

  # Return the result as a data.table (tokens[] ensures printing semantics in interactive use)
  tokens[]
}
