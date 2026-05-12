#' Rank sentence drivers for a year pair by projection onto the year-to-year drift
#'
#' @title Rank driver sentences for a year pair
#'
#' @description
#' For a consecutive year pair (t, t+1) compute the unit change direction
#' between representative vectors in `mat`, project sentence embeddings from
#' each year onto that direction and return the top driving sentences from the
#' earlier and later year (those that most strongly project against or with the
#' direction).
#'
#' @param mat numeric matrix. Representative vectors with rows = years and
#'   columns = embedding dimensions. Row names must be character year labels
#'   (e.g. `"2000"`). `mat` must be finite numeric; rows with `NA` or
#'   inconsistent lengths are not accepted.
#' @param year_t integer scalar. Start year `t` for the pair `(t, t+1)`.
#'   Coerced to integer. Error if either `t` or `t+1` is not present in
#'   `rownames(mat)`.
#' @param data_path character scalar or NULL. Base path where per-year sentence
#'   feather files live under `sentences_embeddings/`. If `NULL` the option
#'   `ejhet.data_path` is consulted and, if missing, `here::here()` is used.
#'   Files are expected at `file.path(data_path, "sentences_embeddings",
#'   glue::glue("sentence_embeddings_{yr}.feather"))`.
#' @param year_col character scalar. Column name in the per-year files that
#'   contains the year identifier. Default: `"year"`. Must exist
#'   in the feather files; values are used to filter rows for the requested year.
#' @param embedding_col character scalar. Name of the list-column holding numeric
#'   embedding vectors (each element a numeric vector of length `ncol(mat)`).
#'   Default: `"embedding"`. Missing or non-list columns cause an error.
#' @param top_n integer scalar >= 1. Number of top drivers to return from each
#'   year. If fewer rows are available the function returns all available rows.
#'   Default: `50L`. Non-integer values are coerced with `as.integer()`.
#' @param normalize_rows logical scalar. If `TRUE` sentence embeddings are
#'   row-normalised (L2) before projection; zero-length rows are left as zeros
#'   (their norm treated as 1 to avoid division-by-zero). Default: `TRUE`.
#' @param chunk_threshold integer scalar. When a year's sentence table contains
#'   more than this many rows, processing is done in on-disk chunks of this
#'   size to bound memory. Default: `200000L`. Must be positive.
#'
#' @return A tibble with the top driver rows from the earlier (`type = "old"`)
#'   and later (`type = "new"`) year. Columns retained (when present in the
#'   source files) include `id` (same type as in files), the year column named
#'   by `year_col` (returned as `year`), `sentence` (character),
#'   and `projection_score` (numeric). The tibble has an attribute `"dir_vec"`
#'   containing the numeric unit direction vector used for projection (length =
#'   `ncol(mat)`). If no drift is detected the function returns a tibble with
#'   zero rows and `attr(..., "dir_vec")` set to a numeric `NA` vector of the
#'   appropriate length; in this case `projection_score` values would be `NA`.
#'
#' @details
#' The function identifies which sentences best explain the change from year
#' `t` to `t+1` by projecting sentence embeddings onto the direction vector
#' between the two representative vectors. It reads per-year embedding files on
#' disk (Feather via `arrow::read_feather()`), computes projection scores with
#' a matrix multiply (fast and memory-efficient), and returns the top scoring
#' sentences from each year.
#'
#' Implementation notes:
#' - Major steps in the implementation:
#'   1. Validate `mat` and that both `t` and `t+1` are present in `rownames(mat)`.
#'   2. Compute the change vector Δ = rep_{t+1} - rep_{t} and its L2 norm.
#'      If the norm is zero or not finite the function emits a warning and
#'      returns an empty result with `dir_vec` set to `NA_real_`.
#'   3. Build a numeric matrix of sentence embeddings for a year by unlisting
#'      the `embedding_col` and reshaping into a matrix (`matrix(..., byrow = TRUE)`).
#'      The helper `build_matrix()` validates embedding lengths and optionally
#'      normalises rows. Zero-length sentence embeddings are protected by
#'      replacing zero norms with 1 before division so they remain zero vectors.
#'   4. Score sentences by computing `scores = embeddings_matrix %*% dir_vec`.
#'      Using a single matrix multiplication per chunk is considerably faster
#'      than iterating per row.
#'   5. When a year's table is large (`nrow > chunk_threshold`) the file's rows
#'      are processed in chunks; per-chunk top candidates are kept and merged
#'      to maintain only the `top_n` best rows (streaming top-k).
#'   6. Combine the top `old` and `new` drivers, attach `dir_vec` as an
#'      attribute and return the result.
#'
#' - Important assumptions and preconditions:
#'   * Each element in the `embedding_col` list-column is a numeric vector of
#'     length equal to `ncol(mat)`. Inconsistent lengths raise an error.
#'   * The per-year Feather files exist and contain the requested columns.
#'   * The function relies on `arrow`, `here`, `glue`, `dplyr`, `tibble`, and
#'     `rlang` being available at runtime.
#'
#' - Edge-case handling & failure modes:
#'   * Missing files or missing columns cause an immediate error with a
#'     descriptive message.
#'   * Identical representative vectors (zero Δ) cause an early warning and an
#'     empty tibble return (with `dir_vec = NA`).
#'   * If rows contain `NA` projection scores they are filtered out before
#'     ranking.
#'   * If `top_n` exceeds available rows the function returns all available
#'     rows (no padding).
#'
#' - Trade-offs:
#'   * The implementation favours streaming and chunking to limit peak memory at
#'     the cost of repeated matrix multiplies when chunking is necessary.
#'   * Normalising sentence rows improves comparability to unit-direction vectors
#'     but may be skipped by setting `normalize_rows = FALSE`.
#'
#' @implementation
#' Vectorised projection pipeline:
#' - Compute `dir_vec` = (rep_{t+1} - rep_t) / ||...||.
#' - For each year: read feather file, filter rows for that year, convert the
#'   embedding list-column to a numeric matrix, optionally normalize rows,
#'   compute `scores = emb_mat %*% dir_vec`, and keep top-K by sorting.
#' - For large tables, process sequential chunks, keep per-chunk top-K and
#'   merge to retain global top-K (streaming top-k).
#'
#' @examples
#' # Minimal runnable example
#' data_path <- tempdir()
#' dir.create(file.path(data_path, "sentences_embeddings"), showWarnings = FALSE)
#' df2000 <- tibble::tibble(
#'   id = 1L,
#'   year = 2000L,
#'   sentence = "old sense",
#'   embedding = list(c(0, 0, 1))
#' )
#' df2001 <- tibble::tibble(
#'   id = 2L,
#'   year = 2001L,
#'   sentence = "new sense",
#'   embedding = list(c(0, 1, 0))
#' )
#' arrow::write_feather(df2000, file.path(data_path, "sentences_embeddings",
#'                                        "sentence_embeddings_2000.feather"))
#' arrow::write_feather(df2001, file.path(data_path, "sentences_embeddings",
#'                                        "sentence_embeddings_2001.feather"))
#' mat <- matrix(c(0, 0, 1, 0, 1, 0), nrow = 2, byrow = TRUE)
#' rownames(mat) <- c("2000", "2001")
#' res <- rank_drivers_for_year_pair(mat, 2000, data_path = data_path,
#'                                   year_col = "year",
#'                                   embedding_col = "embedding", top_n = 1)
#' res
#'
#' @seealso compute_apd_by_years, proto_distance_matrix, plot_semantic_drift,
#'   arrow::read_feather, here::here, glue::glue
#' @keywords utilities drivers
#' @export
#' @author Your Name
rank_drivers_for_year_pair <- function(
  mat,
  year_t,
  data_path = NULL,
  year_col = "year",
  embedding_col = "embedding",
  top_n = 50L,
  normalize_rows = TRUE,
  chunk_threshold = 200000L
) {
  # validate inputs
  if (!is.matrix(mat) && !is.data.frame(mat)) {
    rlang::abort(
      "`mat` must be a matrix or matrix-like object with rownames for years."
    )
  }
  rn <- rownames(mat)
  if (is.null(rn)) {
    rlang::abort("`mat` must have rownames representing years.")
  }
  year_t <- as.integer(year_t)
  year_next <- year_t + 1L
  if (!as.character(year_t) %in% rn || !as.character(year_next) %in% rn) {
    rlang::abort(glue::glue(
      "Years {year_t} or {year_next} not present in `mat` rownames"
    ))
  }

  # resolve data_path
  if (is.null(data_path)) {
    data_path <- getOption("ejhet.data_path", default = here::here())
  }

  cli::cli_inform(glue::glue("Processing year pair {year_t} → {year_next}"))

  # compute direction vector
  delta_t <- as.numeric(mat[as.character(year_next), , drop = TRUE]) -
    as.numeric(mat[as.character(year_t), , drop = TRUE])
  norm_delta <- sqrt(sum(delta_t^2))
  if (!is.finite(norm_delta) || norm_delta == 0) {
    cli::cli_alert_warning(glue::glue(
      "No drift detected between {year_t} and {year_next}"
    ))
    # return empty tibble with expected columns and NA dir_vec attribute
    empty_tbl <- tibble::tibble(
      id = integer(0),
      year = integer(0),
      sentence = character(0),
      projection_score = numeric(0),
      type = character(0)
    )
    attr(empty_tbl, "dir_vec") <- rep(NA_real_, length(delta_t))
    return(empty_tbl)
  }
  dir_vec <- delta_t / norm_delta
  d <- length(dir_vec)

  # helper: build numeric matrix (rows = sentences) from list-column
  build_matrix <- function(emb_list) {
    if (length(emb_list) == 0L) {
      return(matrix(numeric(0), nrow = 0L, ncol = d))
    }
    lens <- vapply(emb_list, length, integer(1))
    if (any(lens != d)) {
      rlang::abort(
        "Inconsistent embedding lengths or mismatch with representative vector dimension"
      )
    }
    # Build matrix by unlisting then shaping by row; this is fast and memory efficient.
    m <- matrix(unlist(emb_list, use.names = FALSE), ncol = d, byrow = TRUE)
    if (normalize_rows && nrow(m) > 0L) {
      # Compute row L2 norms and avoid division by zero by replacing zeros with 1.
      rnms <- sqrt(rowSums(m * m))
      rnms[rnms == 0] <- 1
      m <- m / rnms
    }
    m
  }

  # helper: read/process one year and return top candidates (keeps only requested columns)
  process_year <- function(
    yr,
    direction = c("old", "new"),
    top_n_local = top_n
  ) {
    direction <- match.arg(direction)
    path <- here::here(
      data_path,
      "sentences_embeddings",
      glue::glue("sentence_embeddings_{yr}.feather")
    )
    if (!file.exists(path)) {
      rlang::abort(glue::glue("No sentence file found for year {yr}: {path}"))
    }

    tbl <- arrow::read_feather(path)
    if (!year_col %in% colnames(tbl)) {
      rlang::abort(glue::glue(
        "Year column '{year_col}' not found in file for {yr}"
      ))
    }
    if (!embedding_col %in% colnames(tbl)) {
      rlang::abort(glue::glue(
        "Embedding column '{embedding_col}' not found in file for {yr}"
      ))
    }

    tbl <- tibble::as_tibble(tbl) |> dplyr::filter(.data[[year_col]] == yr)
    n_total <- nrow(tbl)
    if (n_total == 0L) {
      return(
        tbl |>
          dplyr::mutate(projection_score = numeric(0)) |>
          dplyr::slice_head(n = 0)
      )
    }

    score_and_select <- function(df_chunk) {
      emb_mat <- build_matrix(df_chunk[[embedding_col]])
      scores <- if (nrow(emb_mat) == 0L) {
        numeric(0)
      } else {
        # Matrix multiplication projects every row onto dir_vec in one fast operation.
        as.numeric(emb_mat %*% dir_vec)
      }
      df_chunk$projection_score <- scores
      df_chunk[[embedding_col]] <- NULL
      df_chunk |> dplyr::filter(!is.na(.data$projection_score))
    }

    if (n_total <= chunk_threshold) {
      out <- score_and_select(tbl)
      if (nrow(out) == 0L) {
        return(out |> dplyr::slice_head(n = 0))
      }
      if (direction == "old") {
        out <- out |>
          dplyr::arrange(projection_score) |>
          utils::head(top_n_local)
      } else {
        out <- out |>
          dplyr::arrange(dplyr::desc(projection_score)) |>
          utils::head(top_n_local)
      }
      return(out)
    }

    # large file: process in chunks and keep running top_n_local
    starts <- seq.int(1L, n_total, by = chunk_threshold)
    best_tbl <- NULL

    for (s in starts) {
      e <- min(s + chunk_threshold - 1L, n_total)
      chunk <- tbl[s:e, , drop = FALSE]
      scored <- score_and_select(chunk)
      if (nrow(scored) == 0L) {
        next
      }

      if (direction == "old") {
        scored_best <- scored |>
          dplyr::arrange(projection_score) |>
          utils::head(top_n_local)
      } else {
        scored_best <- scored |>
          dplyr::arrange(dplyr::desc(projection_score)) |>
          utils::head(top_n_local)
      }

      best_tbl <- if (is.null(best_tbl)) {
        scored_best
      } else {
        cand <- dplyr::bind_rows(best_tbl, scored_best)
        if (direction == "old") {
          cand |> dplyr::arrange(projection_score) |> utils::head(top_n_local)
        } else {
          cand |>
            dplyr::arrange(dplyr::desc(projection_score)) |>
            utils::head(top_n_local)
        }
      }
      rm(chunk, scored, scored_best)
      gc()
    }

    if (is.null(best_tbl)) {
      return(
        tbl |>
          dplyr::slice_head(n = 0) |>
          dplyr::mutate(projection_score = numeric(0))
      )
    }
    best_tbl
  }

  # process both years sequentially to limit memory
  tbl_t <- process_year(year_t, direction = "old", top_n_local = top_n)
  drivers_old <- tbl_t |>
    dplyr::arrange(projection_score) |>
    utils::head(top_n) |>
    dplyr::select(dplyr::any_of(c(
      "id",
      year_col,
      "sentence",
      "projection_score"
    ))) |>
    dplyr::rename(year = dplyr::any_of(year_col)) |>
    dplyr::mutate(type = "old")
  rm(tbl_t)
  gc()

  tbl_tp1 <- process_year(year_next, direction = "new", top_n_local = top_n)
  drivers_new <- tbl_tp1 |>
    dplyr::arrange(dplyr::desc(projection_score)) |>
    utils::head(top_n) |>
    dplyr::select(dplyr::any_of(c(
      "id",
      year_col,
      "sentence",
      "projection_score"
    ))) |>
    dplyr::rename(year = dplyr::any_of(year_col)) |>
    dplyr::mutate(type = "new")
  rm(tbl_tp1)
  gc()

  result <- dplyr::bind_rows(drivers_old, drivers_new)
  attr(result, "dir_vec") <- dir_vec
  result
}
