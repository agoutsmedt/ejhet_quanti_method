#' Compute Average Pairwise Distance (APD) matrix across years
#'
#' @title Compute APD matrix for sentence embeddings by year
#' @description
#' Build per-year embedding matrices from a sentence-level tibble and compute the
#' average pairwise distance (APD = mean(1 - cosine)) for every unordered pair of years.
#'
#' @param bert_df data.frame or tibble. Must contain a column named by `year_col`
#'   (one value per sentence row) and a list-column named by `embeddings_col`
#'   where each element is a numeric vector (embedding). One row represents one
#'   sentence. Rows with `NA` in the embedding column are filtered out prior to grouping.
#' @param year_col character scalar. Name of the column in `bert_df` that contains
#'   year labels. Default: `"year"`. Values are treated as grouping keys;
#'   they are coerced to `character` for matrix dimnames. NA year values are preserved
#'   as a group if present.
#' @param embeddings_col character scalar. Name of the list-column containing numeric
#'   embedding vectors. Default: `"embedding"`. Each list element must be a numeric
#'   vector of identical length for all embeddings within a year (and ideally across years).
#'   Inconsistent lengths trigger an error.
#' @param chunk_size integer scalar >= 1. Number of rows of `A` processed per block
#'   inside `apd_from_mats()` to limit peak memory usage. Default: `5000L`. Smaller
#'   values reduce memory at the cost of more matrix multiplies.
#'
#' @return numeric matrix (double) of shape (n_years x n_years) with row and column
#'   names set to the character representation of the grouped `year` values. The
#'   matrix is symmetric; off-diagonal entries are the APD between the corresponding
#'   years. Diagonal entries are `NA_real_` (not computed). If no years with embeddings
#'   are found the function returns a 0x0 numeric matrix. If fewer than two non-empty
#'   years exist the returned matrix contains `NA` values (no pairwise computations).
#'
#' @details
#' The function groups `bert_df` by `year_col`, coerces each year's list of embeddings
#' into a numeric matrix with rows = sentences and columns = embedding dimensions, and
#' then computes APD for every unordered pair of non-empty years using `apd_from_mats()`.
#'
#' Implementation notes:
#' - High-level sequence:
#'   1. Validate inputs and required columns early to provide clear errors.
#'   2. Filter out rows with missing embeddings, group by year, and build a list-column
#'      `emb_mat` where each element is a numeric matrix (rows = sentences).
#'   3. Return an empty 0x0 matrix if no years remain.
#'   4. Create an n_years x n_years result matrix `M` initialised with `NA_real_`.
#'   5. Identify non-empty years and compute APD only for unordered pairs of these years
#'      to avoid needless work; compute in a loop while updating a single progress bar.
#'   6. For each pair call `apd_from_mats(Ai, Bj, chunk_size)` which performs blocked
#'      matrix multiplication and returns the scalar APD; assign symmetrically in `M`.
#' - Assumptions and preconditions:
#'   - `bert_df` is a data.frame/tibble with the named columns.
#'   - Each list element in `embeddings_col` is a numeric vector; vectors within a year
#'     must share the same length. The function does not coerce non-numeric embeddings.
#' - Edge-case handling and failure modes:
#'   - Years with zero sentences produce empty matrices and are skipped for pairwise
#'     computation (entries remain `NA`).
#'   - If fewer than two non-empty years exist the function returns the `NA`-filled matrix.
#'   - If embedding lengths are inconsistent within a year the function errors.
#'   - If `apd_from_mats()` encounters zero-row inputs it returns `NA_real_`, which
#'     propagates to the result.
#' - Trade-offs:
#'   - The function avoids building a full (n_total_sentences)^2 similarity matrix
#'     by computing APD per-year-pair and using chunked multiplications inside `apd_from_mats()`.
#' - Dependencies and side-effects:
#'   - Uses `dplyr`, `tidyr`, `tibble`, `cli` and `utils` for grouping, shaping, and user feedback.
#'   - Does not mutate global state or write files.
#'
#' @implementation
#' The implementation materialises per-year matrices, enumerates unordered pairs via
#' `utils::combn()`, and computes each APD by calling `apd_from_mats()` which performs
#' blocked matrix multiplications (Ai %*% t(B)) and accumulates `sum(1 - similarity)`.
#' Progress is reported with a single `cli` progress bar. Result matrix `M` is symmetric.
#'
#' @examples
#' library(tibble)
#' # normal case: two years with two 3-d embeddings each
#' df <- tibble::tibble(
#'   year = c(2000, 2000, 2001, 2001),
#'   embedding = list(
#'     c(1, 0, 0),
#'     c(0, 1, 0),
#'     c(1, 1, 0),
#'     c(0, 0, 1)
#'   )
#' )
#' compute_apd_by_years(df, year_col = "year", embeddings_col = "embedding", chunk_size = 2L)
#'
#' # edge case: a year with no embeddings (row filtered out) -> returns matrix with NAs
#' df2 <- tibble::tibble(
#'   year = c(2000, 2001),
#'   embedding = list(NA, c(1, 0, 0))
#' )
#' compute_apd_by_years(df2, year_col = "year", embeddings_col = "embedding")
#'
#' @seealso apd_from_mats, proto_distance_matrix
#' @keywords similarity
#' @export
#' @author GitHub Copilot
#' @family similarity
compute_apd_by_years <- function(
  bert_df,
  year_col = "year",
  embeddings_col = "embedding",
  chunk_size = 5000L
) {
  # Basic validations
  if (!is.data.frame(bert_df)) {
    cli::cli_abort("`bert_df` must be a data.frame or tibble.")
  }
  if (!all(c(year_col, embeddings_col) %in% colnames(bert_df))) {
    cli::cli_abort(
      "`bert_df` must contain columns {year_col} and {embeddings_col}."
    )
  }

  # Build per-year embedding matrices: list of numeric matrices (n_sentences x dim)
  per_year <- bert_df |>
    dplyr::filter(!is.na(.data[[embeddings_col]])) |>
    dplyr::group_by(year = .data[[year_col]]) |>
    dplyr::summarise(
      emb_mat = list({
        # coerce list of numeric vectors -> numeric matrix (rows = sentences)
        vecs <- .data[[embeddings_col]]
        if (length(vecs) == 0L) {
          matrix(numeric(0), nrow = 0, ncol = 0)
        } else {
          # ensure all vectors have the same length
          lens <- vapply(vecs, length, integer(1))
          if (length(unique(lens)) != 1L) {
            cli::cli_abort(
              "Embeddings for year {unique(year)} have inconsistent dimensions."
            )
          }
          do.call(rbind, vecs)
        }
      }),
      n = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::arrange(year)

  # If no years remain, return empty matrix
  if (nrow(per_year) == 0L) {
    cli::cli_alert_info(
      "No years with embeddings found; returning empty matrix."
    )
    return(matrix(NA_real_, nrow = 0, ncol = 0))
  }

  years <- as.character(per_year$year)
  n_years <- length(years)
  M <- matrix(NA_real_, n_years, n_years, dimnames = list(years, years))

  total_sentences <- sum(per_year$n, na.rm = TRUE)
  n_empty_years <- sum(per_year$n == 0L)
  cli::cli_alert_info(
    "Found {n_years} years with a total of {total_sentences} sentences; {n_empty_years} empty years will be skipped for APD computation."
  )

  # Identify non-empty years to avoid unnecessary work / NA results
  non_empty_idx <- which(per_year$n > 0L)
  if (length(non_empty_idx) < 2L) {
    cli::cli_alert_info(
      "Not enough non-empty years ({length(non_empty_idx)}) to compute pairwise APD; returning matrix with NA diagonals."
    )
    return(M)
  }

  # Build list of unordered pairs to compute so we can show a single progress bar
  pairs_mat <- utils::combn(non_empty_idx, 2L)
  total_pairs <- ncol(pairs_mat)

  cli::cli_progress_bar("Computing APD across year pairs", total = total_pairs)
  on.exit(cli::cli_progress_done(), add = TRUE)

  # Loop over pairs (vectorized chunking handled inside apd_from_mats)
  for (k in seq_len(total_pairs)) {
    i <- pairs_mat[1L, k]
    j <- pairs_mat[2L, k]

    Ai <- per_year$emb_mat[[i]]
    Bj <- per_year$emb_mat[[j]]

    # defensive checks (shouldn't be necessary because we filtered non_empty_idx)
    if (nrow(Ai) == 0L || nrow(Bj) == 0L) {
      cli::cli_progress_update()
      next
    }

    val <- apd_from_mats(Ai, Bj, chunk_size = as.integer(chunk_size))
    M[i, j] <- val
    M[j, i] <- val

    cli::cli_progress_update()
  }

  cli::cli_alert_success("Computed APD for {total_pairs} year pairs.")

  M
}
