#' Compute TF-IDF (optionally weighted) for tokens per document
#'
#' @title Compute TF-IDF for tokenized data
#' @description
#' Calculate term-frequency (TF), inverse document frequency (IDF) and TF-IDF
#' for tokens across one or more document identifiers. Supports optional
#' per-occurrence numeric `weight_col` to produce weighted TF values.
#'
#' @param df data.frame or data.table. Token-level table where each row
#'   represents a token occurrence. The function coercively copies `df` to a
#'   data.table and does not mutate the caller's object.
#' @param token_col character scalar. Name of the column containing token
#'   strings (single-word or multi-word tokens). Default: `"token"`.
#'   Must be present in `df`. Token values are treated as character.
#' @param document_col character scalar or character vector. Column name(s)
#'   that together identify a document (e.g. `"doc_id"` or `c("year","id")`).
#'   Values are coerced to character and concatenated with a `"\r"` separator
#'   internally when multiple columns are provided. Returned result restores
#'   the original document columns.
#' @param weight_col character scalar or NULL. Optional column name in `df`
#'   containing numeric per-occurrence weights (e.g. token importance). If
#'   provided, values are coerced to numeric, `NA`s are replaced with `0`
#'   (with a single warning), and absolute values are used. Default: `NULL`
#'   (each token occurrence counts as weight = 1).
#'
#' @return A data.table with one row per (token, document) pair and these
#'   columns (names may vary slightly when multiple `document_col` are used):
#'   - token (character): the token (name preserved as `token_col`).
#'   - <document_col(s)>: restored document identifier columns (character or integer-like).
#'   - corpus_tf (integer): total number of occurrences of `token` across the corpus
#'     (unweighted count of rows that contained the token).
#'   - nb_doc_word (numeric): total weight of all tokens in the given document.
#'   - df (integer): number of distinct documents containing the token.
#'   - idf (numeric): inverse document frequency computed as `log(total_docs / df)`.
#'   - tf or weighted_tf (numeric): per-document term frequency; named `weighted_tf`
#'     when `weight_col` was provided (equals token_doc_weight / nb_doc_word).
#'   - tf_idf (numeric): product of `tf` (or `weighted_tf`) and `idf`.
#'
#'   The function returns a `data.table` (visible in examples). If a division by
#'   zero occurs for `nb_doc_word == 0` the resulting `tf` will be `NaN` for that row.
#'
#' @details
#' High-level behaviour:
#' - The input `df` is copied and coerced to `data.table` for efficient grouping.
#' - If multiple `document_col` values are supplied they are combined into a
#'   temporary composite key (separator `"\r"`) for grouping and later split back
#'   into original columns in the result.
#' - When `weight_col` is given the function builds a positive weight `.weight`
#'   from `abs(weight_col)` and treats `NA` as `0` (with a warning). Otherwise
#'   each occurrence contributes weight `1.0`.
#' - Corpus-level frequency `corpus_tf` is computed as the (unweighted) count
#'   of occurrences of each token in `df`.
#' - Per-document weighted sums and document totals are computed and used to
#'   derive `tf`, `idf`, and `tf_idf` where `idf = log(total_docs / df)`.
#'
#' Implementation notes:
#' - Steps implemented in code:
#'   1. Validate presence of `token_col` and `document_col` and coerce types.
#'   2. Create a safe temporary composite document key when multiple document
#'      columns are provided; choose a helper name that does not collide.
#'   3. Standardise the token column to the name `token` internally to simplify
#'      data.table expressions, restoring the original name before returning.
#'   4. Compute `corpus_tf` by token, then compute per-(token,document)
#'      weighted sums (`token_doc_weight`) and per-document totals (`nb_doc_word`).
#'   5. Compute `tf = token_doc_weight / nb_doc_word` (may be NaN if denominator 0),
#'      `df` (number of documents containing token), `idf = log(total_docs / df)`,
#'      and `tf_idf = tf * idf`.
#'   6. Clean helper columns, restore original column names, and return the table.
#'
#' - Assumptions and preconditions:
#'   * `token_col` and all `document_col` names exist in `df`.
#'   * If provided, `weight_col` is coercible to numeric.
#'   * `token_col` must be distinct from every `document_col`.
#'
#' - Edge cases and failure modes:
#'   * Missing required columns triggers an informative `stop()`.
#'   * `weight_col` NA values are replaced with `0` (warning); negative weights
#'     are made positive via `abs()`.
#'   * If `nb_doc_word == 0` for a document the computed `tf` will be `NaN`;
#'     callers should filter these rows if needed.
#'   * If multiple `document_col` are provided, the composite separator `"\r"`
#'     is used; unusual document values containing `"\r"` may lead to unexpected
#'     splitting but this separator was chosen to minimise collisions.
#'
#' - Trade-offs:
#'   * Uses `data.table` for speed and memory efficiency. The function copies the
#'     input to avoid mutating caller data at the cost of an extra allocation.
#'
#' @implementation
#' The implementation relies on grouping operations in `data.table`:
#' compute corpus counts, aggregate per-(token,document) weights, merge
#' document totals, derive TF/IDF, and restore original column names. Weighting
#' is optional and sign-agnostic (absolute values taken).
#'
#' @examples
#' # normal case: simple corpus, unweighted
#' df <- data.frame(
#'   doc_id = c("a", "a", "b", "b", "b"),
#'   token = c("x", "y", "x", "x", "z"),
#'   stringsAsFactors = FALSE
#' )
#' compute_tf_idf(df, document_col = "doc_id", token_col = "token")
#'
#' # weighted example: per-occurrence weights (NA treated as 0)
#' df2 <- data.frame(
#'   doc = c("d1", "d1", "d2"),
#'   token = c("t", "t", "t"),
#'   w = c(2, NA, 1)
#' )
#' compute_tf_idf(df2, document_col = "doc", token_col = "token", weight_col = "w")
#'
#' @keywords internal
#' @author Your Name
compute_tf_idf <- function(
  df,
  token_col = "token",
  document_col = "document",
  weight_col = NULL
) {
  # Coerce to data.table and operate on a copy to avoid mutating caller data.
  df <- data.table::as.data.table(df)
  df <- data.table::copy(df)

  # Ensure inputs are character vectors
  document_col <- as.character(document_col)
  token_col <- as.character(token_col)

  # Validate required columns exist; provide a clear error if not.
  if (!all(document_col %in% colnames(df))) {
    stop(
      "Input must contain document column(s): ",
      paste(document_col, collapse = ", "),
      call. = FALSE
    )
  }
  if (!token_col %in% colnames(df)) {
    stop("Input must contain token column: ", token_col, call. = FALSE)
  }

  # Capture original classes / metadata for document columns so we can restore types later
  orig_classes <- vapply(
    document_col,
    function(col) {
      cl <- class(df[[col]])[1L]
      if (is.null(cl)) "character" else cl
    },
    character(1),
    USE.NAMES = TRUE
  )

  orig_levels <- lapply(document_col, function(col) {
    if (is.factor(df[[col]])) levels(df[[col]]) else NULL
  })
  names(orig_levels) <- document_col
  orig_tzone <- lapply(document_col, function(col) {
    if (inherits(df[[col]], "POSIXt")) attr(df[[col]], "tzone") else NULL
  })
  names(orig_tzone) <- document_col

  # Validate weight column if provided
  if (!is.null(weight_col)) {
    weight_col <- as.character(weight_col)
    if (!weight_col %in% colnames(df)) {
      stop("weight_col '", weight_col, "' not found in input", call. = FALSE)
    }
    # coerce to numeric and replace NA with 0 (warn once)
    if (!is.numeric(df[[weight_col]])) {
      df[, (weight_col) := as.numeric(.SD[[1]]), .SDcols = weight_col]
    }
    if (any(is.na(df[[weight_col]]))) {
      warning("NA values found in weight_col; treating as 0 for weighting")
      df[is.na(get(weight_col)), (weight_col) := 0]
    }
    df[, .weight := abs(df[[weight_col]])] # use absolute value to avoid negative weights
  } else {
    # default unweighted behaviour: weight = 1 per token occurrence (as before)
    df[, .weight := 1.0]
  }

  # Prevent collision: token_col must not be one of the document grouping columns
  if (token_col %in% document_col) {
    stop("`token_col` must be distinct from `document_col`", call. = FALSE)
  }

  # Create a temporary composite document key when multiple document columns are provided.
  # Use a name unlikely to collide with existing columns.
  doc_key <- ".document_tmp_key"
  i <- 1L
  while (doc_key %in% colnames(df)) {
    doc_key <- paste0(".document_tmp_key", i)
    i <- i + 1L
  }

  # Build composite key from the original values coerced to character for safe concatenation.
  if (length(document_col) == 1L) {
    # keep a character representation in doc_key but remember original class to restore later
    df[, (doc_key) := as.character(.SD[[1]]), .SDcols = document_col]
  } else {
    df[,
      (doc_key) := do.call(paste, c(lapply(.SD, as.character), sep = "\r")),
      .SDcols = document_col
    ]
  }

  # Temporarily standardise token column name to `token` to simplify expressions.
  if (token_col != "token") {
    data.table::setnames(df, token_col, "token")
    token_was_renamed <- TRUE
  } else {
    token_was_renamed <- FALSE
  }

  # corpus_tf: total (unweighted) count of appearances of token across all rows
  df[, corpus_tf := .N, by = "token"]

  # Compute per-document total weight (nb_doc_word) and per token-document weighted sum
  doc_totals <- df[, .(nb_doc_word = sum(.weight)), by = doc_key]
  token_doc <- df[,
    .(token_doc_weight = sum(.weight)),
    by = c("token", doc_key, "corpus_tf")
  ]

  # merge nb_doc_word into token_doc to compute tf
  token_doc <- merge(
    token_doc,
    doc_totals,
    by = doc_key,
    sort = FALSE,
    all.x = TRUE
  )

  # tf: weighted token frequency within document (token_doc_weight / nb_doc_word)
  # guard against division by zero (nb_doc_word == 0) — produce NaN which can be filtered downstream
  token_doc[, tf := token_doc_weight / nb_doc_word]

  # Document frequency: number of distinct documents containing each token
  df_dt <- token_doc[, .(df = .N), by = token]

  # total distinct documents
  total_docs <- uniqueN(token_doc[[doc_key]])

  # merge df into token_doc
  token_doc <- merge(token_doc, df_dt, by = "token", all.x = TRUE, sort = FALSE)

  # IDF and TF-IDF (natural log)
  token_doc[, idf := log(total_docs / df)]
  token_doc[, tf_idf := tf * idf]

  # Restore token original name
  if (token_was_renamed) {
    data.table::setnames(token_doc, "token", token_col)
  }

  # Restore original document columns with original types
  if (length(document_col) == 1L) {
    # single column: convert doc_key back to original class
    col <- document_col[1]
    typ <- orig_classes[col]
    if (typ == "integer") {
      token_doc[, (col) := as.integer(get(doc_key))]
    } else if (typ %in% c("numeric", "double")) {
      token_doc[, (col) := as.numeric(get(doc_key))]
    } else if (typ == "logical") {
      token_doc[, (col) := as.logical(get(doc_key))]
    } else if (typ == "factor") {
      token_doc[, (col) := factor(get(doc_key), levels = orig_levels[[col]])]
    } else if (typ == "Date") {
      token_doc[, (col) := as.Date(get(doc_key))]
    } else if (typ %in% c("POSIXct", "POSIXt")) {
      tz <- orig_tzone[[col]]
      token_doc[, (col) := as.POSIXct(get(doc_key), tz = tz)]
    } else {
      # fallback: character
      token_doc[, (col) := as.character(get(doc_key))]
    }
    token_doc[, (doc_key) := NULL]
  } else {
    # multiple columns: split then coerce each to its original class
    token_doc[,
      (document_col) := data.table::tstrsplit(get(doc_key), "\r", fixed = TRUE)
    ]
    token_doc[, (doc_key) := NULL]

    for (col in document_col) {
      typ <- orig_classes[col]
      if (typ == "integer") {
        token_doc[, (col) := as.integer(get(col))]
      } else if (typ %in% c("numeric", "double")) {
        token_doc[, (col) := as.numeric(get(col))]
      } else if (typ == "logical") {
        token_doc[, (col) := as.logical(get(col))]
      } else if (typ == "factor") {
        token_doc[, (col) := factor(get(col), levels = orig_levels[[col]])]
      } else if (typ == "Date") {
        token_doc[, (col) := as.Date(get(col))]
      } else if (typ %in% c("POSIXct", "POSIXt")) {
        tz <- orig_tzone[[col]]
        token_doc[, (col) := as.POSIXct(get(col), tz = tz)]
      } else {
        token_doc[, (col) := as.character(get(col))]
      }
    }
  }

  # Remove helper weight column from result if present
  token_doc[, c("token_doc_weight") := NULL]

  if (!is.null(weight_col)) {
    data.table::setnames(token_doc, "tf", "weighted_tf")
  }

  # Return the data.table with restored column types
  token_doc[]
}
