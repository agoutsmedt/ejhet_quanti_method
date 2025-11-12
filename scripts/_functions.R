p_load(docstring)

#: Calculating semantic drift metrics-----------------------
#' Normalize rows of a numeric matrix-like object to unit Euclidean length
#'
#' @title Row-wise L2 normalization of a matrix
#' @description
#' Scale each row of a numeric matrix (or matrix-like object) to have unit
#' Euclidean (L2) norm. Rows with zero length are removed because they cannot be
#' rescaled.
#'
#' @param mat Numeric matrix-like object. Accepts a numeric `matrix`, a
#'   `data.frame` of numeric columns (will be coerced to a matrix), or other
#'   matrix-like objects that inherit from the `"mat"` class. Rows represent
#'   vectors to be normalized. Input must be finite and numeric; rows containing
#'   `NA` or non-numeric columns will cause an error.
#'
#' @return A numeric matrix with the same number of columns as `mat` where each
#'   returned row has Euclidean norm 1. Row names from the input are preserved
#'   for the kept rows. Rows whose norm is exactly (or numerically) zero are
#'   dropped; if no rows remain the function returns a numeric matrix with
#'   zero rows and the original number of columns.
#'
#' @details
#' This helper performs a standard row-wise L2 normalization used before
#' computing cosine similarities. It has no side effects and does not modify
#' global state.
#'
#' Implementation notes:
#' - Coerce `data.frame` inputs to a numeric matrix to allow uniform vectorized
#'   operations.
#' - Validate that the input is numeric. Non-numeric inputs produce an error via
#'   `cli::cli_abort()`.
#' - Compute row norms with `sqrt(rowSums(mat * mat))` and identify rows with
#'   norm > 0. A strict `> 0` test is used (rather than `!= 0`) to avoid
#'   floating-point equality issues.
#' - Drop zero-length rows and divide each remaining row by its corresponding
#'   norm. Division uses column-wise recycling (R's native recycling rules) so
#'   `mat[keep, , drop = FALSE] / nrms[keep]` efficiently scales each row by
#'   its scalar norm.
#' - The function does not attempt to impute or tolerate `NA`s; rows containing
#'   `NA` will cause validation to fail.
#'
#' Edge cases and failure modes:
#' - If `mat` is not numeric an informative error is raised.
#' - If all rows have zero norm, the returned object is a zero-row numeric
#'   matrix with the same number of columns.
#' - Rows with `NA` values produce an error (no silent coercion).
#'
#' Alternatives and trade-offs:
#' - This implementation favors clarity and vectorized base R arithmetic over
#'   per-row loops for speed. For extremely large matrices, specialized C-backed
#'   implementations or BLAS-accelerated libraries may be faster.
#'
#' @implementation
#' Vectorized algorithm:
#' 1. Coerce `data.frame` -> `matrix`.
#' 2. Validate numeric type.
#' 3. Compute per-row L2 norms.
#' 4. Keep rows with norm > 0 and divide each row by its norm using recycling.
#'
#' @seealso `rowSums()`, base `scale()` for column scaling
#' @examples
#' # normal case: matrix input
#' m <- matrix(c(3, 4, 0, 0, 0, 2), nrow = 3, byrow = TRUE)
#' row_normalize(m)
#'
#' # data.frame input coerced to matrix
#' df <- data.frame(x = c(3, 0), y = c(4, 0))
#' row_normalize(df)
#'
#' # edge case: rows of zeros are removed -> returns a 0-row matrix
#' m_zero <- matrix(c(0, 0, 0, 0), nrow = 2)
#' row_normalize(m_zero)
#'
#' @keywords internal
#' @author Your Name
#' @export
row_normalize <- function(mat) {
  # Accept data.frames by coercing to a matrix to enable vectorized ops
  if (is.data.frame(mat)) {
    mat <- as.matrix(mat)
  }

  # Ensure we have a matrix-like numeric object.
  # Allow objects that explicitly inherit from a "mat" class as a convenience.
  if (!is.matrix(mat) && !inherits(mat, "mat")) {
    cli::cli_abort("`mat` must be a mat-like numeric object")
  }
  if (!is.numeric(mat)) {
    cli::cli_abort("`mat` must be numeric")
  }

  # Compute L2 norms for each row: sqrt(sum(row^2)).
  nrms <- sqrt(rowSums(mat * mat))

  # Keep rows whose norm is strictly positive (guards against floating point
  # near-zero values and prevents division-by-zero).
  keep <- nrms > 0

  # Subset kept rows and divide each row by its scalar norm.
  # Division by a vector of length nrows uses R's column-wise recycling so each
  # row i is divided by nrms[i], which is efficient and vectorized.
  norm_mat <- mat[keep, , drop = FALSE] / nrms[keep]

  norm_mat
}

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
#'   year labels. Default: `"publication_year"`. Values are treated as grouping keys;
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
#'   publication_year = c(2000, 2000, 2001, 2001),
#'   embedding = list(
#'     c(1, 0, 0),
#'     c(0, 1, 0),
#'     c(1, 1, 0),
#'     c(0, 0, 1)
#'   )
#' )
#' compute_apd_by_years(df, year_col = "publication_year", embeddings_col = "embedding", chunk_size = 2L)
#'
#' # edge case: a year with no embeddings (row filtered out) -> returns matrix with NAs
#' df2 <- tibble::tibble(
#'   publication_year = c(2000, 2001),
#'   embedding = list(NA, c(1, 0, 0))
#' )
#' compute_apd_by_years(df2, year_col = "publication_year", embeddings_col = "embedding")
#'
#' @seealso apd_from_mats, proto_distance_matrix
#' @keywords similarity
#' @export
compute_apd_by_years <- function(
  bert_df,
  year_col = "publication_year",
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

# Mean pairwise cosine distance between rows of A and B, vectorized
#' @title Average Pairwise Distance (APD) between two sets of row-vectors
#' @description
#' Compute the average pairwise distance (APD) between the rows of two numeric
#' matrices based on cosine similarity. APD is defined as the mean of
#' (1 - cosine_similarity) over all row pairs (one row from `A`, one row from `B`).
#'
#' @param A numeric matrix with rows representing vectors (embedding matrix).
#'   Expected shape: numeric matrix with `ncol(A) = d` (d >= 1) and `nrow(A) >= 0`.
#'   Rows may contain zeros; behavior for zero-norm rows depends on the helper
#'   `.row_normalize` (see Implementation notes). NA values in `A` will typically
#'   propagate to the result or produce errors during normalization/multiplication.
#' @param B numeric matrix with rows representing vectors (embedding matrix).
#'   Expected shape: numeric matrix with `ncol(B) = d` (must match `ncol(A)`)
#'   and `nrow(B) >= 0`. See `A` for NA/zero-handling notes.
#' @param chunk_size integer scalar (positive) controlling the number of rows of
#'   `A` processed per block when computing similarities. Default `5000L`.
#'   Must be a positive integer; non-positive or non-integer values will cause
#'   underlying functions (e.g. `seq.int`) to error. Chunking trades memory
#'   for repeated matrix multiplies (smaller `chunk_size` uses less memory).
#'
#' @return
#' Numeric scalar (double) equal to the APD:
#' the mean value of `1 - cosine(a_i, b_j)` across all `i=1..nrow(A)`,
#' `j=1..nrow(B)`. If either `A` or `B` has zero rows (`nrow(...) == 0`),
#' the function returns `NA_real_` because the APD is undefined in that case.
#' If matrix dimensions are incompatible (different `ncol`), the function will
#' error when attempting matrix multiplication.
#'
#' @details
#' At a high level, this function:
#' - row-normalizes `A` and `B` so each row has unit (or defined) norm,
#' - computes cosine similarities between rows of `A` and `B` in memory-bounded
#'   chunks, and
#' - returns the average of `1 - cosine_similarity` across all cross-pairs.
#'
#' The APD computed is:
#' \deqn{APD(A,B) = \frac{1}{|A||B|} \sum_{i=1}^{|A|}\sum_{j=1}^{|B|} \left[1 - \cos(a_i, b_j)\right],}
#' where \eqn{\cos(a_i, b_j)} is the cosine similarity between row vectors
#' `a_i` (from `A`) and `b_j` (from `B`).
#'
#' Implementation notes:
#' - High-level algorithm and major steps:
#'   1. Call `row_normalize(A)` and `row_normalize(B)` to (attempt to)
#'      normalize each row to unit length. The function relies on this helper
#'      to handle zero-norm rows or to signal errors for invalid input.
#'   2. If either matrix has zero rows after normalization (`nrow(A) == 0` or
#'      `nrow(B) == 0`), return `NA_real_` because no pairwise distances exist.
#'   3. Iterate over `A` in blocks of `chunk_size` rows. For each block `Ai`,
#'      compute `S_chunk <- Ai %*% t(B)` which yields pairwise cosine
#'      similarities for that block vs all rows of `B`. Accumulate
#'      `sum(1 - S_chunk)` across blocks and divide by `nrow(A) * nrow(B)` at the end.
#' - Memory and performance:
#'   - The chunking strategy bounds memory by materializing only one similarity
#'     block at a time (size `min(chunk_size, nrow(A)) x nrow(B)`).
#'   - Time complexity is O(nrow(A) * nrow(B) * d) where `d = ncol(A)`.
#'   - Choosing `chunk_size` trades memory (larger = fewer matrix multiplies)
#'     for peak memory usage.
#' - Assumptions and preconditions:
#'   - `A` and `B` are numeric matrices with the same number of columns.
#'   - `.row_normalize` is available in the environment and performs row-wise
#'     normalization (it must not silently drop rows; it should preserve row
#'     counts or the function's NA check will not behave as intended).
#' - Edge-case handling and failure modes:
#'   - Returns `NA_real_` if either matrix has zero rows (undefined APD).
#'   - If `A` or `B` contains rows with zero norm, the result depends on
#'     `row_normalize`'s behavior (e.g. it may return zero rows, `NaN`s, or
#'     error). If `row_normalize` produces non-finite values, matrix
#'     multiplication and the sum will propagate them.
#'   - If `ncol(A) != ncol(B)` the `%*%` operation will error.
#' - Alternatives and trade-offs:
#'   - One could compute full similarity matrix in-memory when data is small,
#'     avoiding repeated multiplications; chunking is chosen here for
#'     scalability to larger datasets.
#' - Dependencies and side-effects:
#'   - Uses base R matrix multiplication. Requires a `row_normalize` helper
#'     function to exist in scope. The function does not mutate global state
#'     or write files.
#'
#' @implementation
#' Blocked matrix multiplication over `A` rows: normalize rows -> iterate blocks
#' of `A` -> compute `Ai %*% t(B)` -> accumulate `sum(1 - similarities)` ->
#' divide by total number of pairs. This minimizes peak memory while remaining
#' straightforward and numerically stable for typical dense numeric matrices.
#'
#' @examples
#' # normal case: small random matrices (rows are vectors)
#' set.seed(1)
#' A <- matrix(rnorm(6), nrow = 2) # 2 x 3
#' B <- matrix(rnorm(9), nrow = 3) # 3 x 3
#' # assume .row_normalize exists and normalizes rows; for example:
#' .row_normalize <- function(m) {
#'   if (nrow(m) == 0) return(m)
#'   norms <- sqrt(rowSums(m * m))
#'   # avoid division by zero: leave zero rows as zeros
#'   nz <- norms > 0
#'   m[nz, , drop = FALSE] <- m[nz, , drop = FALSE] / norms[nz]
#'   m
#' }
#' apd_from_mats(A, B, chunk_size = 1L)
#'
#' # edge case: one input has zero rows -> returns NA_real_
#' A0 <- matrix(numeric(0), nrow = 0, ncol = 3)
#' apd_from_mats(A0, B)
#'
#' # edge case: zero-norm row (depends on .row_normalize handling)
#' A_zero <- rbind(c(0, 0, 0), c(1, 0, 0))
#' apd_from_mats(A_zero, B, chunk_size = 2L)
#'
#' @author GitHub Copilot
#' @keywords internal
#' @family similarity
#' @seealso base::`%*%`, stats::`dist`
apd_from_mats <- function(A, B, chunk_size = 5000L) {
  A <- row_normalize(A)
  B <- row_normalize(B)
  nA <- nrow(A)
  nB <- nrow(B)
  if (nA == 0L || nB == 0L) {
    return(NA_real_)
  } # undefined if any side empty or all-zero

  # Chunk over the larger side to bound memory of the similarity matrix
  # Computes mean(1 - S) without materializing all chunks at once
  total_pairs <- as.double(nA) * as.double(nB)
  sum_one_minus_cos <- 0.0

  # choose chunking on A
  idx_starts <- seq.int(1L, nA, by = chunk_size)
  for (s in idx_starts) {
    e <- min(s + chunk_size - 1L, nA) # end index for this chunk
    Ai <- A[s:e, , drop = FALSE]
    S_chunk <- Ai %*% t(B) # cosine similarities
    sum_one_minus_cos <- sum_one_minus_cos + sum(1 - S_chunk)
  }
  sum_one_minus_cos / total_pairs
}

#' Compute a pairwise proto-distance matrix (1 - cosine similarity) for yearly prototypes
#'
#' @title Pairwise proto-distance matrix from yearly prototype vectors
#' @description
#' Compute a square matrix of proto-distances between yearly representative
#' vectors using cosine similarity. The function expects `mat` to have rownames
#' that represent integer-like years (e.g. `"1900"`). It normalizes rows to
#' unit length, computes pairwise cosine similarities, converts them to
#' distances via `1 - cosine`, and sets the diagonal to `NA` to exclude
#' trivial self-distance.
#'
#' @param mat Numeric matrix-like object with rows representing years and
#'   columns representing embedding dimensions. Rows must have names corresponding
#'   to integer-like years (character rownames such as `"1900"`). `NA` values
#'   are not allowed; if rows contain only zeros they are removed during
#'   normalization (see details).
#'
#' @return A numeric square matrix (n_kept x n_kept) of proto-distances with
#'   dimnames equal to the kept row names (years). Values are `1 - cosine`,
#'   which lies in the interval [-1, 2] in general; for typical unit-normalized
#'   embeddings distances fall in [0, 2]. The diagonal entries are `NA`.
#'   If no rows remain after normalization the function returns a 0 x 0 numeric
#'   matrix with `dimnames = list(character(0), character(0))`.
#'
#' @details
#' This function is designed to measure pairwise differences between yearly
#' prototype vectors (e.g. sentence-embedding centroids). It:
#' - Requires row names that encode integer-like years; it aborts if rownames
#'   are missing or not integer-like.
#' - Sorts rows by year to ensure deterministic ordering.
#' - Row-normalizes vectors with `row_normalize()` (which drops exact zero
#'   rows). Year labels for removed rows are not present in the output.
#' - Computes cosine similarities via matrix multiplication and converts them to
#'   distances using `1 - cosine`.
#'
#' Implementation notes:
#' - Algorithmic steps:
#'   1. Validate that `mat` has rownames and that they parse as integer-like years.
#'   2. Order rows by year and coerce to deterministic ordering.
#'   3. Row-normalize with `row_normalize()`; this may drop rows that are exact
#'      zero vectors (they cannot be scaled).
#'   4. Compute the dense cosine similarity matrix via `mat_norm %*% t(mat_norm)`.
#'   5. Convert to distances `1 - cosine` and set the diagonal to `NA`.
#' - Assumptions and preconditions: `mat` is numeric, finite, and rownames are
#'   integer-like year labels. Rows containing `NA` will cause the underlying
#'   `row_normalize()` validation to fail.
#' - Edge cases & failure modes:
#'   * If rownames are missing or not integer-like, the function aborts with an
#'     informative error.
#'   * If `row_normalize()` removes all rows, the result is a 0x0 numeric
#'     matrix (no error).
#'   * If some rows are zero vectors, they are simply dropped and corresponding
#'     years are absent from the returned matrix.
#' - Trade-offs: The implementation uses dense matrix multiplication which is
#'   simple and efficient for moderate sizes but uses O(n^2) memory and time;
#'   for very large year counts a block-wise or approximate approach may be
#'   preferable.
#' - Dependencies: calls `row_normalize()` (local helper) and `cli::cli_abort()`.
#'
#' @implementation
#' Vectorized, BLAS-friendly approach:
#' - Normalise rows (L2) with `row_normalize()` to produce unit vectors.
#' - Compute all pairwise cosines with a single matrix product.
#' - Convert to distances and mask the diagonal with `NA`.
#'
#' @examples
#' # Normal case: two yearly prototype vectors
#' m <- matrix(c(1, 0, 0, 1), nrow = 2, byrow = TRUE)
#' rownames(m) <- c("1900", "1901")
#' proto_distance_matrix(m)
#'
#' # Edge case: zero rows are removed by normalization -> fewer rows in output
#' m2 <- matrix(c(0, 0, 1, 0), nrow = 2, byrow = TRUE)
#' rownames(m2) <- c("1900", "1901")
#' proto_distance_matrix(m2)
#'
#' @seealso row_normalize(), consecutive_proto_drift()
#' @keywords internal
#' @author Your Name
#' @family proto-distance functions
proto_distance_matrix <- function(mat) {
  # Require row names that represent years
  if (is.null(rownames(mat))) {
    cli::cli_abort("Input matrix must have rownames representing years.")
  }

  # Try to interpret row names as integer-like years; abort if parsing fails.
  yrs <- suppressWarnings(as.integer(rownames(mat)))
  if (any(is.na(yrs))) {
    cli::cli_abort("Row names must be integer-like years (e.g. '1900').")
  }

  # Ensure rows are sorted by year for deterministic output
  ord <- order(yrs)
  mat <- mat[ord, , drop = FALSE]
  yrs <- yrs[ord]

  # Normalize rows to unit length; this may drop exact-zero rows.
  # row_normalize() preserves rownames for kept rows.
  mat_norm <- row_normalize(mat)

  # Capture the (character) row names of the kept rows after normalization.
  # Using character rownames is safe for dimnames assignment.
  yrs_kept <- rownames(mat_norm)

  # Compute cosine similarity via a single matrix multiplication.
  # For normalized rows, (mat_norm %*% t(mat_norm))_ij == cosine(vec_i, vec_j).
  cosine_matrix <- as.matrix(mat_norm %*% t(mat_norm))

  # Convert similarity to distance (1 - cosine). This yields values typically
  # in [0, 2] (0 identical, 2 opposite).
  distance_matrix <- 1 - cosine_matrix

  # Mask self-distance as NA since self-comparisons are not informative for drift.
  diag(distance_matrix) <- NA_real_

  # Attach dimnames corresponding to the kept years (may be character).
  dimnames(distance_matrix) <- list(yrs_kept, yrs_kept)

  distance_matrix
}

#' Consecutive year-to-year proto-distance (PRT) drift
#'
#' @title Consecutive proto-distance (year-to-year) drift
#' @description
#' Compute year-to-year proto-distance (PRT) values from a matrix of yearly
#' prototype vectors. The function delegates validation and normalization to
#' `proto_distance_matrix()` and then extracts the off-diagonal elements that
#' correspond to consecutive-year distances (row i vs row i-1).
#'
#' @param mat Numeric matrix-like object with rows = years and columns =
#'   embedding dimensions. Rows must have names that represent years (e.g.
#'   `"1900"`). Accepts a numeric `matrix` or other matrix-like objects; `NA`
#'   values are not allowed (validation happens in `proto_distance_matrix()`).
#'
#' @return A tibble with three columns:
#'   - `year`: integer (if row names parse as integer-like years) or character
#'     (if row names are not integer-like) giving the later year in each
#'     consecutive pair. For the zero-row edge case this is `integer(0)`.
#'   - `year_prev`: same type as `year`, representing the previous year.
#'   - `prt`: numeric vector of proto-distances (values are `1 - cosine`).
#'   If no consecutive pairs exist (fewer than 2 rows after normalization)
#'   the function returns a zero-row tibble with column types shown above.
#'
#' @details
#' The function computes year-to-year drift by:
#' - Calling `proto_distance_matrix(mat)` to validate row names, sort rows by
#'   year, normalize vectors, and compute a full pairwise distance matrix
#'   (1 - cosine similarity). That helper may drop exact-zero rows.
#' - Extracting the (i, i-1) off-diagonal entries from the distance matrix
#'   which represent the distance from each year to the previous year.
#'
#' Implementation notes:
#' - Steps:
#'   1. Ensure `mat` has rownames; `proto_distance_matrix()` will error if not.
#'   2. Compute the full square distance matrix (may have fewer rows than the
#'      input if zero vectors were removed).
#'   3. If fewer than 2 rows remain, return an empty tibble with predictable
#'      column types.
#'   4. Parse row names as integers when possible; otherwise warn and keep
#'      character labels.
#'   5. Extract consecutive-year distances using a vectorized index `cbind()`
#'      on the matrix (fast and avoids explicit loops).
#' - Assumptions and preconditions:
#'   * `mat` is numeric and has row names meaningful as year labels.
#'   * `proto_distance_matrix()` enforces that rows do not contain `NA`s.
#' - Edge cases & failure modes:
#'   * Missing row names -> error (handled by this function / helper).
#'   * Non-integer row names -> function returns character `year`/`year_prev`
#'     and emits a warning.
#'   * Exact-zero prototype rows are removed by normalization; corresponding
#'     years will be absent from the output.
#'   * If fewer than two rows remain after normalization, an empty tibble is
#'     returned instead of an error.
#' - Trade-offs: extraction of consecutive entries uses dense matrix memory
#'   returned by `proto_distance_matrix()`; for extremely large year counts a
#'   streaming or block approach could be used.
#' - Dependencies: calls `proto_distance_matrix()` and `cli::cli_warn()` /
#'   `cli::cli_abort()`; returns a tibble (requires `tibble`).
#'
#' @implementation
#' Vectorized approach:
#' - Build full pairwise distance matrix via `proto_distance_matrix()`.
#' - Use a single `cbind()` index to extract consecutive off-diagonal entries
#'   (i, i-1) into a numeric vector.
#'
#' @examples
#' # Normal case: two yearly prototype vectors
#' m <- matrix(c(1, 0, 0, 1), nrow = 2, byrow = TRUE)
#' rownames(m) <- c("1900", "1901")
#' consecutive_proto_drift(m)
#'
#' # Edge case: only one year remains -> zero-row tibble
#' m_single <- matrix(c(1, 2), nrow = 1)
#' rownames(m_single) <- "1900"
#' consecutive_proto_drift(m_single)
#'
#' # Non-integer row names -> warning and character year columns
#' m_chr <- matrix(c(1, 0, 0, 1), nrow = 2, byrow = TRUE)
#' rownames(m_chr) <- c("a", "b")
#' consecutive_proto_drift(m_chr)
#'
#' @seealso proto_distance_matrix(), row_normalize()
#' @keywords internal
#' @family proto-distance functions
#' @author Your Name
consecutive_proto_drift <- function(mat) {
  # Ensure rownames exist; proto_distance_matrix() also checks this but we give
  # an early, specific error message for this precondition.
  if (is.null(rownames(mat))) {
    cli::cli_abort("Input must have rownames representing years.")
  }

  # Compute the full pairwise distance matrix (validates, sorts, normalizes).
  distance_matrix <- proto_distance_matrix(mat)

  # Keep the (character) row names of the (possibly reduced) distance matrix.
  yrs_chr <- rownames(distance_matrix)
  n <- nrow(distance_matrix)

  # If fewer than two rows remain there are no consecutive pairs -> return a
  # predictable zero-row tibble (use integer(0) for year cols for consistency).
  if (n < 2) {
    return(tibble::tibble(
      year = integer(0),
      year_prev = integer(0),
      prt = numeric(0)
    ))
  }

  # Try to interpret the retained rownames as integer-like years. We suppress
  # warnings from as.integer() and handle parse failure with a user warning.
  yrs_int <- suppressWarnings(as.integer(yrs_chr))
  if (any(is.na(yrs_int))) {
    # Non-integer labels: warn user and keep character year labels in output.
    cli::cli_warn(
      "Row names are not integer-like years; returning year labels as character."
    )
    year_col <- yrs_chr[-1] # later year in each consecutive pair
    year_prev_col <- yrs_chr[-n] # previous year for each pair
  } else {
    # Integer-like labels: return integer columns for years.
    year_col <- yrs_int[-1]
    year_prev_col <- yrs_int[-n]
  }

  # Vectorized extraction of consecutive off-diagonal entries:
  # For n rows, consecutive pairs correspond to (2,1), (3,2), ..., (n, n-1).
  # Build index matrix with cbind(row_indices, col_indices) and subset the matrix.
  idx <- seq_len(n - 1)
  prt_vals <- as.numeric(distance_matrix[cbind(idx + 1, idx)])

  # Return a tibble with the later year, previous year, and the proto-distance.
  tibble::tibble(
    year = year_col,
    year_prev = year_prev_col,
    prt = prt_vals
  )
}

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
#'   year labels. Default: `"publication_year"`. Values are treated as grouping keys;
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
#'   publication_year = c(2000, 2000, 2001, 2001),
#'   embedding = list(
#'     c(1, 0, 0),
#'     c(0, 1, 0),
#'     c(1, 1, 0),
#'     c(0, 0, 1)
#'   )
#' )
#' compute_apd_by_years(df, year_col = "publication_year", embeddings_col = "embedding", chunk_size = 2L)
#'
#' # edge case: a year with no embeddings (row filtered out) -> returns matrix with NAs
#' df2 <- tibble::tibble(
#'   publication_year = c(2000, 2001),
#'   embedding = list(NA, c(1, 0, 0))
#' )
#' compute_apd_by_years(df2, year_col = "publication_year", embeddings_col = "embedding")
#'
#' @seealso apd_from_mats, proto_distance_matrix
#' @keywords similarity
#' @export
#' @author GitHub Copilot
#' @family similarity
compute_apd_by_years <- function(
  bert_df,
  year_col = "publication_year",
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

# Mean pairwise cosine distance between rows of A and B, vectorized
#' @title Average Pairwise Distance (APD) between two sets of row-vectors
#' @description
#' Compute the average pairwise distance (APD) between the rows of two numeric
#' matrices based on cosine similarity. APD is defined as the mean of
#' (1 - cosine_similarity) over all row pairs (one row from `A`, one row from `B`).
#'
#' @param A numeric matrix with rows representing vectors (embedding matrix).
#'   Expected shape: numeric matrix with `ncol(A) = d` (d >= 1) and `nrow(A) >= 0`.
#'   Rows may contain zeros; behavior for zero-norm rows depends on the helper
#'   `.row_normalize` (see Implementation notes). NA values in `A` will typically
#'   propagate to the result or produce errors during normalization/multiplication.
#' @param B numeric matrix with rows representing vectors (embedding matrix).
#'   Expected shape: numeric matrix with `ncol(B) = d` (must match `ncol(A)`)
#'   and `nrow(B) >= 0`. See `A` for NA/zero-handling notes.
#' @param chunk_size integer scalar (positive) controlling the number of rows of
#'   `A` processed per block when computing similarities. Default `5000L`.
#'   Must be a positive integer; non-positive or non-integer values will cause
#'   underlying functions (e.g. `seq.int`) to error. Chunking trades memory
#'   for repeated matrix multiplies (smaller `chunk_size` uses less memory).
#'
#' @return
#' Numeric scalar (double) equal to the APD:
#' the mean value of `1 - cosine(a_i, b_j)` across all `i=1..nrow(A)`,
#' `j=1..nrow(B)`. If either `A` or `B` has zero rows (`nrow(...) == 0`),
#' the function returns `NA_real_` because the APD is undefined in that case.
#' If matrix dimensions are incompatible (different `ncol`), the function will
#' error when attempting matrix multiplication.
#'
#' @details
#' At a high level, this function:
#' - row-normalizes `A` and `B` so each row has unit (or defined) norm,
#' - computes cosine similarities between rows of `A` and `B` in memory-bounded
#'   chunks, and
#' - returns the average of `1 - cosine_similarity` across all cross-pairs.
#'
#' The APD computed is:
#' \deqn{APD(A,B) = \frac{1}{|A||B|} \sum_{i=1}^{|A|}\sum_{j=1}^{|B|} \left[1 - \cos(a_i, b_j)\right],}
#' where \eqn{\cos(a_i, b_j)} is the cosine similarity between row vectors
#' `a_i` (from `A`) and `b_j` (from `B`).
#'
#' Implementation notes:
#' - High-level algorithm and major steps:
#'   1. Call `row_normalize(A)` and `row_normalize(B)` to (attempt to)
#'      normalize each row to unit length. The function relies on this helper
#'      to handle zero-norm rows or to signal errors for invalid input.
#'   2. If either matrix has zero rows after normalization (`nrow(A) == 0` or
#'      `nrow(B) == 0`), return `NA_real_` because no pairwise distances exist.
#'   3. Iterate over `A` in blocks of `chunk_size` rows. For each block `Ai`,
#'      compute `S_chunk <- Ai %*% t(B)` which yields pairwise cosine
#'      similarities for that block vs all rows of `B`. Accumulate
#'      `sum(1 - S_chunk)` across blocks and divide by `nrow(A) * nrow(B)` at the end.
#' - Memory and performance:
#'   - The chunking strategy bounds memory by materializing only one similarity
#'     block at a time (size `min(chunk_size, nrow(A)) x nrow(B)`).
#'   - Time complexity is O(nrow(A) * nrow(B) * d) where `d = ncol(A)`.
#'   - Choosing `chunk_size` trades memory (larger = fewer matrix multiplies)
#'     for peak memory usage.
#' - Assumptions and preconditions:
#'   - `A` and `B` are numeric matrices with the same number of columns.
#'   - `.row_normalize` is available in the environment and performs row-wise
#'     normalization (it must not silently drop rows; it should preserve row
#'     counts or the function's NA check will not behave as intended).
#' - Edge-case handling and failure modes:
#'   - Returns `NA_real_` if either matrix has zero rows (undefined APD).
#'   - If `A` or `B` contains rows with zero norm, the result depends on
#'     `row_normalize`'s behavior (e.g. it may return zero rows, `NaN`s, or
#'     error). If `row_normalize` produces non-finite values, matrix
#'     multiplication and the sum will propagate them.
#'   - If `ncol(A) != ncol(B)` the `%*%` operation will error.
#' - Alternatives and trade-offs:
#'   - One could compute full similarity matrix in-memory when data is small,
#'     avoiding repeated multiplications; chunking is chosen here for
#'     scalability to larger datasets.
#' - Dependencies and side-effects:
#'   - Uses base R matrix multiplication. Requires a `row_normalize` helper
#'     function to exist in scope. The function does not mutate global state
#'     or write files.
#'
#' @implementation
#' Blocked matrix multiplication over `A` rows: normalize rows -> iterate blocks
#' of `A` -> compute `Ai %*% t(B)` -> accumulate `sum(1 - similarities)` ->
#' divide by total number of pairs. This minimizes peak memory while remaining
#' straightforward and numerically stable for typical dense numeric matrices.
#'
#' @examples
#' # normal case: small random matrices (rows are vectors)
#' set.seed(1)
#' A <- matrix(rnorm(6), nrow = 2) # 2 x 3
#' B <- matrix(rnorm(9), nrow = 3) # 3 x 3
#' # assume .row_normalize exists and normalizes rows; for example:
#' .row_normalize <- function(m) {
#'   if (nrow(m) == 0) return(m)
#'   norms <- sqrt(rowSums(m * m))
#'   # avoid division by zero: leave zero rows as zeros
#'   nz <- norms > 0
#'   m[nz, , drop = FALSE] <- m[nz, , drop = FALSE] / norms[nz]
#'   m
#' }
#' apd_from_mats(A, B, chunk_size = 1L)
#'
#' # edge case: one input has zero rows -> returns NA_real_
#' A0 <- matrix(numeric(0), nrow = 0, ncol = 3)
#' apd_from_mats(A0, B)
#'
#' # edge case: zero-norm row (depends on .row_normalize handling)
#' A_zero <- rbind(c(0, 0, 0), c(1, 0, 0))
#' apd_from_mats(A_zero, B, chunk_size = 2L)
#'
#' @author GitHub Copilot
#' @keywords internal
#' @family similarity
#' @seealso base::`%*%`, stats::`dist`
apd_from_mats <- function(A, B, chunk_size = 5000L) {
  A <- row_normalize(A)
  B <- row_normalize(B)
  nA <- nrow(A)
  nB <- nrow(B)
  if (nA == 0L || nB == 0L) {
    return(NA_real_)
  } # undefined if any side empty or all-zero

  # Chunk over the larger side to bound memory of the similarity matrix
  # Computes mean(1 - S) without materializing all chunks at once
  total_pairs <- as.double(nA) * as.double(nB)
  sum_one_minus_cos <- 0.0

  # choose chunking on A
  idx_starts <- seq.int(1L, nA, by = chunk_size)
  for (s in idx_starts) {
    e <- min(s + chunk_size - 1L, nA) # end index for this chunk
    Ai <- A[s:e, , drop = FALSE]
    S_chunk <- Ai %*% t(B) # cosine similarities
    sum_one_minus_cos <- sum_one_minus_cos + sum(1 - S_chunk)
  }
  sum_one_minus_cos / total_pairs
}

#' Extract APD series for a given anchor year
#'
#' @title Anchor series from APD matrix
#' @description
#' Extracts the Average Pairwise Distance (APD) values comparing every year
#' in an APD matrix to a specified anchor year, returning a tidy two-column
#' tibble of `year` and `apd`.
#'
#' @param APD numeric matrix. A matrix (usually square) whose row names and
#'   column names are years (character). Rows represent source years and
#'   columns represent target/anchor years. NA values are allowed.
#' @param anchor_year integer scalar or character scalar. Year to use as the
#'   anchor (e.g. `1920` or `"1920"`). Must match a row name (or a row name
#'   coercible to integer). If not found the function errors.
#'
#' @return A tibble with two columns:
#'   - `year` (integer): the compared year,
#'   - `apd` (numeric): APD between `year` and `anchor_year`.
#'   Rows with `NA` APD are removed and the anchor year itself is omitted.
#'   If all comparisons to the anchor are `NA` the function returns a zero-row
#'   tibble with the correct columns.
#'
#' @details
#' The function looks up the anchor along both rows and columns of `APD` and
#' coalesces the row-wise and column-wise comparisons so it works when the
#' matrix stores comparisons in either orientation or is non-square.
#'
#' Implementation notes:
#' - Validate that `APD` has row names and that `anchor_year` is present (or
#'   coercible to a present row name). The function errors early with a clear
#'   message if these preconditions are unmet.
#' - Coerce `anchor_year` to character for lookup; extract the anchor row (if
#'   present) and the anchor column (if present). Either may be missing.
#' - Use `dplyr::coalesce()` to combine the row and column numeric vectors so
#'   the first non-missing value is used for each compared year.
#' - Build a tibble, drop `NA` APD entries and the anchor row itself, and
#'   return results ordered by year.
#' - Dependencies: uses `tibble::tibble()` and `dplyr::coalesce()`; it does not
#'   mutate global state.
#'
#' Edge cases and failure modes:
#' - Errors if `APD` has no row names or if `anchor_year` is not found among
#'   the row names (after integer coercion).
#' - If anchor row/column exists but all values are `NA`, the returned tibble
#'   will have zero rows.
#'
#' @implementation See the "Implementation notes" subsection in @details for a
#' step-by-step description of the algorithm.
#' @examples
#' # Normal case: small square APD matrix with years 1920:1922
#' APD <- matrix(
#'   c(0, 0.1, 0.2,
#'     0.1, 0, 0.3,
#'     0.2, 0.3, 0),
#'   nrow = 3, byrow = TRUE
#' )
#' rownames(APD) <- colnames(APD) <- as.character(1920:1922)
#' anchor_series_from_apd(APD, 1921)
#'
#' # Edge case: anchor present but all comparisons are NA -> returns zero-row tibble
#' APD2 <- APD
#' APD2["1921", ] <- NA_real_
#' APD2[, "1921"] <- NA_real_
#' anchor_series_from_apd(APD2, "1921")
#'
#' @keywords internal
#' @family apd drift
#' @author
#' agoutsmedt
anchor_series_from_apd <- function(APD, anchor_year) {
  # Read row names (string years)
  yrs_chr <- rownames(APD)

  # Validate prerequisites with informative errors
  if (is.null(yrs_chr)) {
    stop("APD must have row names representing years", call. = FALSE)
  }

  # Allow anchor as integer or character matching row names (coerced)
  anchor_present <- (as.character(anchor_year) %in% yrs_chr) ||
    (anchor_year %in% as.integer(yrs_chr))

  if (!anchor_present) {
    stop(
      "anchor_year '",
      anchor_year,
      "' is not present in APD row names: ",
      paste(head(yrs_chr, 10), collapse = ", "),
      call. = FALSE
    )
  }

  # Coerce anchor to character for direct matrix lookup
  a <- as.character(anchor_year)

  # Extract anchor row if present, otherwise produce NA vector matching columns.
  # This handles APD matrices that store comparisons row-wise.
  row_vec <- if (a %in% rownames(APD)) {
    APD[a, , drop = TRUE]
  } else {
    rep(NA_real_, ncol(APD))
  }

  # Extract anchor column if present, otherwise produce NA vector matching rows.
  # This handles APD matrices that store comparisons column-wise.
  col_vec <- if (a %in% colnames(APD)) {
    APD[, a, drop = TRUE]
  } else {
    rep(NA_real_, nrow(APD))
  }

  # Combine row-wise and column-wise comparisons: prefer the first non-missing
  # value for each year (useful if matrix is asymmetric or non-square).
  v <- dplyr::coalesce(as.numeric(row_vec), as.numeric(col_vec))

  # Build tidy result: `year` as integer, `apd` numeric; drop NAs and the anchor itself,
  # and return ordered by year.
  tibble::tibble(
    year = as.integer(yrs_chr),
    apd = v
  ) |>
    dplyr::filter(!is.na(apd), year != as.integer(anchor_year)) |>
    dplyr::arrange(year)
}

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
#'   contains the year identifier. Default: `"publication_year"`. Must exist
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
#'   by `year_col` (returned as `publication_year`), `sentence` (character),
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
#'   publication_year = 2000L,
#'   sentence = "old sense",
#'   embedding = list(c(0, 0, 1))
#' )
#' df2001 <- tibble::tibble(
#'   id = 2L,
#'   publication_year = 2001L,
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
#'                                   year_col = "publication_year",
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
  year_col = "publication_year",
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
      publication_year = integer(0),
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
    dplyr::rename(publication_year = dplyr::any_of(year_col)) |>
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
    dplyr::rename(publication_year = dplyr::any_of(year_col)) |>
    dplyr::mutate(type = "new")
  rm(tbl_tp1)
  gc()

  result <- dplyr::bind_rows(drivers_old, drivers_new)
  attr(result, "dir_vec") <- dir_vec
  result
}

#: Plotting semantic drift-------------------------

#' @title Plot rolling mean of a year-to-year semantic drift measure
#' @description Compute and plot a moving average of a year-to-year drift measure
#'   (for example prototype-based distance `prt` or average pairwise distance `apd`)
#'   and optionally add a LOESS smooth of the raw values.
#'
#' @param drift tibble with at least two columns: `year` (integer or character scalar per row)
#'   and a numeric column specified by `value_col`. Rows are treated as time-ordered after
#'   arranging by `year`. NA values in `value_col` are allowed and handled by the rolling mean.
#' @param value_col character scalar naming the numeric column in `drift` to plot and roll.
#'   Allowed examples: `"prt"`, `"apd"`. Default in the function signature is `c("prt", "apd")`,
#'   but the function requires a single character string and will error if multiple values are
#'   supplied; pass a single name like `"prt"`.
#' @param smooth logical scalar, whether to add a LOESS smooth of the raw `value_col`
#'   values. Default: `FALSE`. When `TRUE` the smoothing uses `span` and `method = "loess"`.
#' @param span numeric scalar in (0, 1] passed to `geom_smooth(method = "loess")` when
#'   `smooth = TRUE`. Default: `0.25`. NA or out-of-range values will be passed to ggplot2
#'   and may produce warnings/errors from `geom_smooth`.
#' @param window integer scalar >= 2 giving the number of years used for the rolling mean
#'   (right-aligned). Default: `NULL` (no rolling mean / no rolling line). If `window <= 1`
#'   a warning is issued and no rolling mean is computed. NA values inside a rolling window
#'   are ignored via `na.rm = TRUE` when computing the mean; if all values in the window are
#'   missing the result is `NA`.
#'
#' @return A `ggplot` object. The plot contains:
#'   - semi-transparent points for the raw year-to-year `value_col` values;
#'   - an optional rolling-mean line (`numeric` column named `<value_col>_roll`) when
#'     `window` >= 2; and
#'   - an optional LOESS trend line when `smooth = TRUE`.
#'   On error the function throws with `cli::cli_abort()` (e.g. missing column or invalid args).
#'
#' @details
#' This helper visualises short-term year-to-year changes in a semantic drift measure by
#' plotting raw year values and an optional right-aligned moving average. It is designed
#' to be used with yearly prototype- or embedding-based drift measures.
#'
#' Implementation notes:
#' - The function first validates inputs and arranges `drift` by `year`. If `year` is a
#'   character vector the ordering is lexical — convert to integer or Date for chronological order.
#' - The rolling mean uses `zoo::rollapply(..., align = "right", fill = NA_real_)` so each
#'   rolling value corresponds to the current year and the `window - 1` previous years.
#'   `mean(..., na.rm = TRUE)` is used inside the window to tolerate missing values.
#' - If `window` is `NULL` or `<= 1` no rolling line is drawn. If `window` is larger than
#'   the number of available rows, the resulting rolling column will contain mostly `NA`.
#' - The function does not mutate global state. It depends on the `ggplot2`, `dplyr`,
#'   `zoo`, `glue`, and `cli` packages; these should be available at runtime.
#' - Trade-offs: `zoo::rollapply` is used because it provides explicit `align = "right"`
#'   behaviour and flexible `fill` control. Alternatives such as `stats::filter` or
#'   `slider::slide_*` were considered; `zoo` is chosen for compactness and fewer dependencies.
#'
#' @implementation
#' Assembles a `ggplot2` with three optional layers: raw points, a computed rolling-mean
#' line added when `window >= 2`, and a LOESS trend when `smooth = TRUE`. The rolling mean
#' is stored in a new column `<value_col>_roll` on a local copy of `drift`.
#'
#' @examples
#' # Normal case: integer years, rolling window of 3 and LOESS smoothing
#' d <- tibble::tibble(
#'   year = 2001:2008,
#'   prt = c(0.1, 0.15, 0.12, 0.2, 0.18, 0.25, 0.22, 0.3)
#' )
#' plot_semantic_drift(d, value_col = "prt", window = 3L, smooth = TRUE)
#'
#' # Edge case: character years (lexical order) and NA values in the series
#' d2 <- tibble::tibble(
#'   year = as.character(c(2001:2004, 2010, 2005)),
#'   apd = c(NA, 0.2, 0.18, 0.19, 0.25, 0.21)
#' )
#' # Convert year to integer for chronological ordering, or be aware lexical ordering:
#' d2$year <- as.integer(d2$year)
#' plot_semantic_drift(d2, value_col = "apd", window = 2L)
#'
#' # Edge case: no rolling (window = NULL) simply shows raw points (and optional LOESS)
#' plot_semantic_drift(d, value_col = "prt", window = NULL, smooth = FALSE)
#'
#' @export
#' @keywords plot timeseries semantic-drift
#' @seealso [ggplot2::geom_smooth()], [zoo::rollapply()], [plot_prt_rolling()], [plot_cumulative_drift()]
#' @family plotting
#' @concept semantic drift
plot_semantic_drift <- function(
  drift,
  value_col = c("prt", "apd"),
  smooth = FALSE,
  span = 0.25,
  window = NULL
) {
  # Validate `value_col` is a single character string naming a column in `drift`.
  if (!is.character(value_col) || length(value_col) != 1L) {
    cli::cli_abort(
      "`value_col` must be a single character string naming a column in `drift`. Either 'prt' or 'apd' are allowed."
    )
  }
  if (!value_col %in% colnames(drift)) {
    cli::cli_abort("Column {.val {value_col}} not found in `drift`.")
  }

  compute_roll <- FALSE
  if (!is.null(window)) {
    if (!is.numeric(window) || length(window) != 1L) {
      cli::cli_abort("`window` must be a single integer-like value or NULL.")
    }
    window <- as.integer(window)
    if (window <= 1L) {
      # Inform the user that a window <= 1 is effectively no rolling computation.
      cli::cli_alert_warning(
        "No rolling applied; `window` <= 1. Results will be equivalent to year-to-year plot."
      )
      compute_roll <- FALSE
    } else {
      compute_roll <- TRUE
    }
  }

  # Arrange rows by `year` before computing rolling mean. If `year` is character,
  # ordering will be lexical; the user should supply integer or Date for chronological order.
  d <- drift |>
    dplyr::arrange(year)

  roll_col <- paste0(value_col, "_roll")
  if (compute_roll) {
    vals <- d[[value_col]]
    # Compute a right-aligned rolling mean with NA-aware averaging. `fill = NA_real_`
    # ensures the first (window-1) rows receive NA (no incomplete-window padding).
    rollvec <- zoo::rollapply(
      vals,
      width = window,
      FUN = function(x) mean(x, na.rm = TRUE),
      align = "right",
      fill = NA_real_
    )
    d[[roll_col]] <- rollvec
  }

  # Nicely formatted display name for axis/title: uppercase common abbreviations.
  display_name <- if (tolower(value_col) %in% c("prt", "apd")) {
    toupper(value_col)
  } else {
    value_col
  }

  # Determine whether year column is integer-like for numeric x-axis with decade breaks.
  yrs_num <- suppressWarnings(as.integer(d$year))
  is_numeric_years <- !any(is.na(yrs_num)) && length(yrs_num) > 0L

  if (is_numeric_years) {
    # Build decade breaks from numeric years
    yr_min <- min(yrs_num, na.rm = TRUE)
    yr_max <- max(yrs_num, na.rm = TRUE)
    decade_start <- floor(yr_min / 10) * 10
    decade_end <- ceiling(yr_max / 10) * 10
    decade_breaks <- seq(decade_start, decade_end, by = 10)

    d$year_num <- yrs_num

    # Base plot: numeric x-axis
    p <- ggplot2::ggplot(d, ggplot2::aes(x = year_num)) +
      ggplot2::geom_point(
        ggplot2::aes(y = .data[[value_col]]),
        alpha = 0.4,
        size = 0.8
      ) +
      ggplot2::labs(
        x = NULL,
        y = glue::glue(
          "{if (compute_roll) 'Rolling mean ' else ''}{display_name}{if (compute_roll) glue::glue(' (window = {window})') else ''}"
        ),
        title = glue::glue(
          "{if (compute_roll) 'Rolling mean of ' else ''}{display_name}"
        )
      ) +
      ggplot2::theme_minimal() +
      ggplot2::scale_x_continuous(
        breaks = decade_breaks,
        labels = as.character(decade_breaks)
      )
  } else {
    # Fallback: treat years as discrete factor and sample every 10th label for ticks
    d$year_f <- factor(
      as.character(d$year),
      levels = unique(as.character(d$year))
    )
    n_lev <- length(levels(d$year_f))
    step <- max(1L, floor(n_lev / 10)) # ensure roughly 10 or fewer ticks; keeps readability
    idxs <- seq(1L, n_lev, by = step)
    decade_breaks <- levels(d$year_f)[idxs]

    p <- ggplot2::ggplot(d, ggplot2::aes(x = year_f)) +
      ggplot2::geom_point(
        ggplot2::aes(y = .data[[value_col]]),
        alpha = 0.4,
        size = 0.8
      ) +
      ggplot2::labs(
        x = NULL,
        y = glue::glue(
          "{if (compute_roll) 'Rolling mean ' else ''}{display_name}{if (compute_roll) glue::glue(' (window = {window})') else ''}"
        ),
        title = glue::glue(
          "{if (compute_roll) 'Rolling mean of ' else ''}{display_name}"
        )
      ) +
      ggplot2::theme_minimal(base_size = 18) +
      ggplot2::scale_x_discrete(breaks = decade_breaks, expand = c(0, 0))
  }

  # Add rolling mean line only when requested (window >= 2).
  if (compute_roll) {
    p <- p +
      ggplot2::geom_line(
        ggplot2::aes(y = .data[[roll_col]]),
        color = "darkgreen",
        linewidth = 0.8
      )
  }

  # Optionally add LOESS smoothing of raw values for trend visualization.
  if (isTRUE(smooth)) {
    p <- p +
      ggplot2::geom_smooth(
        ggplot2::aes(y = .data[[value_col]]),
        method = "loess",
        span = span,
        se = FALSE,
        color = "darkred"
      )
  }

  p
}

#' Cumulative semantic drift (running sum of year-to-year PRT)
#'
#' @title Plot cumulative PRT over time
#' @description Compute and plot the running (cumulative) sum of yearly prototype-based
#'   distances (`prt`) to visualise accumulated semantic drift.
#'
#' @param drift tibble with columns `year` (integer or character scalar per row) and
#'   `prt` (numeric scalar). Rows represent years. `year` may be integer or character;
#'   if character, ordering is lexical unless converted to integer before calling.
#'   `NA` values in `prt` are allowed and are treated as zero for the cumulative sum
#'   (see Implementation notes).
#'
#' @return A `ggplot` object (class `gg`) showing `cum_prt` (numeric vector) on the y-axis
#'   and `year` on the x-axis. The function returns the plot object for further modification.
#'   If required columns are missing the function errors with a descriptive message.
#'
#' @details
#' This function orders the input `drift` by `year`, replaces missing yearly PRT values
#' with zero (interpreting missing as "no observed change"), computes the cumulative
#' sum via `cumsum()`, and plots the result as a line with year-wise points.
#'
#' Implementation notes:
#' - Steps: (1) validate input columns, (2) sort by `year`, (3) replace `NA` in `prt` with 0,
#'   (4) compute `cum_prt <- cumsum(prt_replaced)`, (5) draw line + points with `ggplot2`.
#' - Assumptions: `drift` contains one row per year (duplicates are not collapsed). If
#'   duplicate years exist they are included in the cumulative sum in their sorted order.
#' - Ordering: `dplyr::arrange(year)` is used; if `year` is character this produces
#'   lexical order. Convert `year` to integer prior to calling for chronological ordering.
#' - NA handling: missing `prt` values are replaced with `0` before summation. This choice
#'   treats missing drift as no change; an alternative is to omit missing values or carry
#'   last observations forward — choose based on domain needs.
#' - Failure modes: function errors if `year` or `prt` are missing. It does not mutate
#'   global state or write files.
#' - Dependencies: `dplyr`, `tidyr`, `ggplot2`, and `cli` (for user-facing errors/warnings).
#'
#' @implementation
#' The implementation performs lightweight validation, sorts the data, replaces missing
#' `prt` values with zero to preserve cumulative semantics, computes a running sum with
#' `cumsum()`, and returns a `ggplot2` object built from that augmented tibble.
#'
#' @examples
#' library(tibble)
#' d <- tibble::tibble(
#'   year = 2000:2005,
#'   prt  = c(0.01, 0.02, NA, 0.01, 0.03, 0.00)
#' )
#' # normal case
#' plot_cumulative_drift(d)
#' # edge case: NA treated as zero (no change)
#' plot_cumulative_drift(d)
#'
#' @seealso plot_prt_rolling, plot_prt_distribution, proto_distance_matrix
#' @keywords plot
#' @export
plot_cumulative_drift <- function(drift) {
  # Validate required columns early to provide a clear error message to users.
  if (!all(c("year", "prt") %in% colnames(drift))) {
    cli::cli_abort("`drift` must contain columns `year` and `prt`.")
  }

  d <- drift |>
    dplyr::arrange(year) |> # Order by year (lexical if `year` is character)
    dplyr::mutate(
      # Replace NA with 0 so that missing yearly drift contributes no change to the running sum.
      # This is an explicit design choice; alternatives (e.g., skipping NA) are valid depending on use.
      cum_prt = cumsum(tidyr::replace_na(prt, 0))
    )

  ggplot2::ggplot(d, ggplot2::aes(x = year, y = cum_prt)) +
    ggplot2::geom_line(color = "purple", linewidth = 0.8) +
    ggplot2::geom_point(size = 0.8) +
    ggplot2::labs(
      x = NULL,
      y = "Cumulative PRT",
      title = "Cumulative semantic drift (sum of yearly PRT)"
    ) +
    ggplot2::theme_minimal()
}

#' Distribution of year-to-year PRT values
#'
#' @title Distribution of PRT values
#' @description Compute and plot the distribution of prototype-based distances (PRT)
#'   using a histogram overlaid with a density estimate.
#'
#' @param drift tibble with a numeric column `prt` (vector). Each row is one observation
#'   (typically a year-to-year PRT). `prt` may contain `NA`; missing values are ignored
#'   when drawing the histogram and density. No other columns are required.
#' @param bins integer scalar >= 1. Number of bins used by the histogram. Default: `30`.
#'   Non-integer inputs are coerced to integer; inputs < 1 cause an error.
#'
#' @return A `ggplot` object (class `gg`) showing the histogram (density-scaled) with an
#'   overlaid kernel density. The function returns the plot for further modification or
#'   printing. If `drift` lacks a `prt` column or `bins` is invalid the function errors
#'   with a descriptive message.
#'
#' @details
#' The function draws a density-scaled histogram of `prt` values and overlays a kernel
#' density estimate to aid visual assessment of the distribution (skew, modes, tails).
#'
#' Implementation notes:
#' - Steps: (1) validate that `drift` contains `prt` and that `bins` is a positive
#'   integer-like scalar, (2) coerce `bins` to integer, (3) build a `ggplot2` histogram
#'   with `aes(y = ..density..)` and overlay `geom_density()`.
#' - NA handling: `geom_histogram()` and `geom_density()` drop `NA` by default; the function
#'   explicitly sets `na.rm = TRUE` for clarity. If all `prt` values are `NA` the plot
#'   will be empty (no bars/curve).
#' - Assumptions: `drift` is a small-to-moderate tibble; the function does not aggregate,
#'   rescale, or otherwise transform `prt` values beyond plotting.
#' - Dependencies: `ggplot2` and `cli`. The function does not modify global state or write files.
#'
#' @implementation
#' The implementation validates inputs with `cli::cli_abort()` for clear user messages,
#' coerces `bins` to integer, and builds the ggplot using `geom_histogram()` (density-scaled)
#' plus `geom_density()` (kernel estimate). No sampling or bootstrap is performed.
#'
#' @examples
#' library(tibble)
#' d <- tibble::tibble(prt = c(0.01, 0.02, 0.03, NA, 0.01, 0.00, 0.02))
#' # normal case
#' plot_prt_distribution(d)
#' # change number of bins
#' plot_prt_distribution(d, bins = 10L)
#' # edge case: all NA (produces an empty plot)
#' plot_prt_distribution(tibble::tibble(prt = rep(NA_real_, 5)))
#'
#' @seealso plot_prt_rolling, plot_cumulative_drift, proto_distance_matrix
#' @keywords plot
#' @export
plot_prt_distribution <- function(drift, bins = 30) {
  # Validate presence of `prt` column for clear user feedback.
  if (!"prt" %in% colnames(drift)) {
    cli::cli_abort("`drift` must contain a numeric column named `prt`.")
  }

  # Validate bins: require a single numeric-like value and coerce to integer.
  if (!is.numeric(bins) || length(bins) != 1L) {
    cli::cli_abort("`bins` must be a single numeric-like value >= 1.")
  }
  bins <- as.integer(bins)
  if (is.na(bins) || bins < 1L) {
    cli::cli_abort("`bins` must be an integer >= 1.")
  }

  # Build the plot. Use density scaling for the histogram so it matches the density curve.
  ggplot2::ggplot(drift, ggplot2::aes(x = prt)) +
    ggplot2::geom_histogram(
      ggplot2::aes(y = after_stat(density)),
      bins = bins,
      fill = "gray70",
      color = "white",
      na.rm = TRUE # explicitly ignore NA values in plotting
    ) +
    ggplot2::geom_density(color = "black", size = 0.6, na.rm = TRUE) +
    ggplot2::labs(
      x = "PRT",
      y = "Density",
      title = "Distribution of year-to-year PRT values"
    ) +
    ggplot2::theme_minimal()
}

#' Heatmap of pairwise prototype distances (years × years)
#'
#' @title Heatmap of pairwise proto-distances
#' @description Create a year-by-year heatmap from a square distance matrix where
#'   row and column names encode years. Useful to visualise pairwise prototype-based
#'   distances (PRT) across time.
#'
#' @param distance_matrix numeric square matrix (n x n) with both `rownames` and
#'   `colnames` set to the corresponding year labels (character vector of length n).
#'   Values are numeric distances (e.g., 1 - cosine). `NA` values are allowed and
#'   are shown with `na.value` (defaults to light grey in the plot).
#' @param legend_title character scalar, title for the colour legend. Default: "PRT\n(1 - cosine)".
#'
#' @return A `ggplot` object (class `gg`) showing a raster heatmap of pairwise
#'   distances. The x and y axes use the provided year labels. If input validation
#'   fails the function throws an error (via `cli::cli_abort()`).
#'
#' @details
#' The function converts the square matrix to a long tibble and plots it with
#' `ggplot2::geom_raster()`, mapping distance to a perceptually-uniform colour
#' scale (from the `scico` package). Axis ticks are reduced to decade breaks when
#' possible to keep the plot readable.
#'
#' Implementation notes:
#' - Validates that `distance_matrix` is a numeric square matrix with dimnames.
#' - Converts the matrix to a long data frame (`as.data.frame()` + `pivot_longer()`),
#'   then converts the row/column labels to factors preserving the original order
#'   so that the matrix layout is preserved in the raster.
#' - Computes decade breaks by attempting to coerce row names to integer years;
#'   if coercion fails (non-numeric names) it falls back to character positions and
#'   picks every 10th label.
#' - If `rownames` and `colnames` are not identical a warning is emitted but the
#'   function will still plot using the provided labels (the plot may be asymmetric).
#' - NA handling: NA values in the matrix are plotted using `na.value = "grey90"`.
#' - Side effects: none (no global state modified, no files written).
#' - Dependencies: `ggplot2`, `tidyr`, `tibble`, `dplyr`, `scico`, and `cli`.
#'
#' @implementation
#' Steps performed:
#' 1. Validate type/shape and presence of dimnames.
#' 2. Optionally warn if row/col names differ.
#' 3. Convert matrix -> long tibble, set factor levels to preserve ordering.
#' 4. Compute decade breaks from numeric years when possible; otherwise fall back
#'    to regular 10-step sampling of labels.
#' 5. Build and return a `ggplot2` raster plot with `scico` palette.
#'
#' @examples
#' # normal case: symmetric matrix with year labels
#' yrs <- as.character(2000:2004)
#' m <- matrix(runif(25, 0, 0.2), nrow = 5, ncol = 5)
#' rownames(m) <- colnames(m) <- yrs
#' plot_distance_heatmap(m)
#'
#' # edge case: NA values in the matrix are visualised with a neutral color
#' m_na <- m
#' m_na[2, 4] <- NA_real_
#' plot_distance_heatmap(m_na)
#'
#' @seealso proto_distance_matrix, plot_prt_rolling, plot_cumulative_drift
#' @keywords plot
#' @export
#' @author
#' Positron Assistant
plot_distance_heatmap <- function(
  distance_matrix,
  legend_title = "PRT\n(1 - cosine)"
) {
  # Basic validations to provide clear user feedback early
  if (!is.matrix(distance_matrix) || !is.numeric(distance_matrix)) {
    cli::cli_abort("`distance_matrix` must be a numeric matrix.")
  }
  if (nrow(distance_matrix) != ncol(distance_matrix)) {
    cli::cli_abort(
      "`distance_matrix` must be square (same number of rows and columns)."
    )
  }
  if (
    is.null(rownames(distance_matrix)) || is.null(colnames(distance_matrix))
  ) {
    cli::cli_abort(
      "`distance_matrix` must have both rownames and colnames set to year labels."
    )
  }

  # Warn if row and column labels differ; still proceed but user may get asymmetric plot.
  if (!identical(rownames(distance_matrix), colnames(distance_matrix))) {
    cli::cli_warn(
      "Row names and column names differ; plot will use the provided labels as-is."
    )
  }

  # Convert matrix to a long tibble suitable for ggplot.
  # rownames_to_column preserves the original row order (important for matrix layout).
  df <- as.data.frame(distance_matrix) |>
    tibble::rownames_to_column(var = "year") |>
    tidyr::pivot_longer(
      cols = -year,
      names_to = "year2",
      values_to = "dist"
    ) |>
    # Convert the year columns to factors with levels in the original order so the
    # raster preserves the matrix layout (row/column order).
    dplyr::mutate(
      year = factor(year, levels = unique(year)),
      year2 = factor(year2, levels = unique(year2))
    )

  # Attempt to compute decade breaks using numeric years; if conversion fails,
  # fall back to sampling every 10th label to avoid over-crowding axis ticks.
  yrs_num <- suppressWarnings(as.integer(unique(rownames(distance_matrix))))
  if (any(is.na(yrs_num))) {
    decade_breaks <- unique(rownames(distance_matrix))[seq(
      1,
      length(unique(rownames(distance_matrix))),
      by = 10
    )]
  } else {
    yr_min <- min(yrs_num, na.rm = TRUE)
    yr_max <- max(yrs_num, na.rm = TRUE)
    decade_seq <- seq(floor(yr_min / 10) * 10, floor(yr_max / 10) * 10, by = 10)
    decade_breaks <- as.character(decade_seq)
  }

  p <- ggplot2::ggplot(df, ggplot2::aes(x = year, y = year2, fill = dist)) +
    # geom_raster is efficient for regularly-gridded heatmaps and preserves aspect ratio
    ggplot2::geom_raster() +
    # perceptually-uniform colour scale from scico; reverse direction for readability
    scico::scale_fill_scico(
      palette = "lipari",
      na.value = "grey90",
      direction = -1,
      name = legend_title
    ) +
    coord_fixed(expand = FALSE) +
    ggplot2::labs(
      x = NULL,
      y = NULL
    ) +
    ggplot2::theme_minimal(base_size = 18) +
    ggplot2::theme(
      axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, hjust = 1)
    ) +
    # Reduce tick labels to decade breaks (or sampled labels) for readability
    ggplot2::scale_x_discrete(breaks = decade_breaks, labels = decade_breaks) +
    ggplot2::scale_y_discrete(breaks = decade_breaks, labels = decade_breaks)

  p
}

#' Plot APD series against one or more anchor years
#'
#' @title Plot APD vs anchor year(s)
#' @description
#' Create a ggplot2 visualization of Average Pairwise Distance (APD) relative to
#' one anchor year or multiple anchor years. In single-anchor mode
#' (`facet = FALSE`) the function returns a single panel for `anchor_year`.
#' In multi-anchor mode (`facet = TRUE`) it returns a faceted plot for each
#' value in `anchors`.
#'
#' @param APD numeric matrix, square (years x years). Row names and column names
#'   must be present and represent years (character or integer). `APD[i, j]`
#'   denotes the distance between the i-th (row) year and the j-th (column) year.
#'   NAs are allowed in the matrix and will appear as gaps in the plotted series
#'   (the function does not impute missing values).
#' @param anchor_year integer scalar or character(1). The anchor year to use
#'   when `facet = FALSE`. Must match one of the row names of `APD`.
#' @param anchors integer vector or NULL. Anchor years to use when `facet = TRUE`.
#'   All values must be present in the row names of `APD`.
#' @param facet logical scalar. If `TRUE` the function plots multiple anchors
#'   (from `anchors`) using `facet_wrap`; if `FALSE` it plots a single anchor
#'   specified by `anchor_year`. Default: `FALSE`.
#' @param scales character(1). Passed to `ggplot2::facet_wrap()` when
#'   `facet = TRUE`. One of `"fixed"`, `"free"`, `"free_x"`, `"free_y"`.
#'   Default: `"fixed"`.
#' @param span numeric scalar in (0, 1]. Smoothing span passed to `geom_smooth`
#'   (loess). Smaller values follow the data more closely. Default: `0.25`.
#'
#' @return
#' A `ggplot` object. The function stops with an error if `APD` lacks row names,
#' if required anchors are missing, or if required arguments are not supplied
#' (e.g., `anchor_year` when `facet = FALSE`). It never returns NULL.
#'
#' @details
#' The function extracts APD series for the requested anchor(s) and visualizes
#' them over time. The plotted series show APD between each year and the
#' anchor year; a vertical dashed line marks the anchor. When faceting, each
#' anchor gets its own panel and its own vertical marker.
#'
#' Implementation notes:
#' - Validate that `APD` has row names. Row names are used to match anchors.
#' - For faceted mode, convert `anchors` to character to compare with
#'   `rownames(APD)` and error on missing anchors.
#' - For each anchor the function calls `anchor_series_from_apd(APD,
#'   anchor_year = a)`, which is expected to return a tibble with columns
#'   `year` (integer or numeric) and `apd` (numeric). These per-anchor tibbles
#'   are combined with `purrr::map_dfr()` and annotated with an `anchor`
#'   column for faceting.
#' - The plot uses `geom_line`, `geom_point`, and a LOESS smoother
#'   (`geom_smooth(method = "loess")`) with the specified `span`. The vertical
#'   dashed line (`geom_vline`) highlights the anchor year.
#' - Assumptions: `APD` is square and its row/column names share the same set
#'   of year labels; `anchor_series_from_apd()` exists and returns the expected
#'   columns. The function does not mutate global state.
#' - Edge cases & failure modes: function errors if `rownames(APD)` is NULL,
#'   if requested anchors are absent, or if `anchor_year` is missing when
#'   `facet = FALSE`. Very short time series may not be well suited for LOESS;
#'   switch smoothing method if needed.
#'
#' @implementation
#' The function builds the plotting data by extracting anchor-specific series
#' (via `anchor_series_from_apd`) and optionally stacking them for faceting.
#' It then constructs a ggplot with common aesthetics and returns it. Using
#' `purrr::map_dfr()` keeps memory usage modest when combining multiple small
#' tibbles; LOESS smoothing is used for flexibility on typical time-series
#' lengths encountered here.
#'
#' @examples
#' # Minimal runnable examples
#' set.seed(1)
#' years <- 2000:2004
#' APD <- matrix(runif(25, 0, 1), nrow = 5, ncol = 5)
#' rownames(APD) <- colnames(APD) <- as.character(years)
#'
#' # Single-anchor plot
#' library(ggplot2)
#' plot_anchor(APD, anchor_year = 2002)
#'
#' # Faceted anchors
#' plot_anchor(APD, anchors = c(2000, 2003), facet = TRUE, scales = "free_y")
#'
#' @seealso anchor_series_from_apd, ggplot2::geom_smooth
#' @keywords internal
#' @family plotting
#' @author Positron Assistant
#' @aliases plot_anchor
plot_anchor <- function(
  APD,
  anchor_year = NULL,
  anchors = NULL,
  facet = FALSE,
  scales = "fixed",
  span = 0.25
) {
  # Validate APD rownames
  yrs_chr <- rownames(APD)
  if (is.null(yrs_chr)) {
    stop("APD must have row names representing years")
  }

  if (facet) {
    if (is.null(anchors)) {
      stop("When facet = TRUE you must provide a vector of `anchors`")
    }
    # Convert anchors to character to match rownames(APD) which are character
    anchors_chr <- as.character(anchors)
    missing_anchors <- setdiff(anchors_chr, yrs_chr)
    if (length(missing_anchors) > 0) {
      stop(
        "The following anchors are not present in APD rownames: ",
        paste(missing_anchors, collapse = ", ")
      )
    }

    # Build a combined tibble with an `anchor` column by extracting the
    # series for each anchor using anchor_series_from_apd().
    # anchor_series_from_apd() is expected to return a tibble with
    # columns `year` and `apd`.
    df <- purrr::map_dfr(anchors_chr, function(a) {
      anchor_series_from_apd(APD, anchor_year = a) |>
        dplyr::mutate(anchor = as.integer(a))
    })

    # Prepare vertical line positions (one per unique anchor)
    vlines <- data.frame(anchor = unique(as.integer(df$anchor)))

    gg <- ggplot2::ggplot(df, ggplot2::aes(x = year, y = apd)) +
      ggplot2::geom_line() +
      ggplot2::geom_point(size = 1.5) +
      # LOESS smoother: flexible local smoothing; span controls smoothness
      ggplot2::geom_smooth(
        method = "loess",
        se = FALSE,
        color = "blue",
        alpha = 0.9,
        linetype = 1,
        span = span
      ) +
      ggplot2::facet_wrap(~anchor, scales = scales) +
      # Draw a dashed vertical line at the anchor year in each facet
      ggplot2::geom_vline(
        data = vlines,
        ggplot2::aes(xintercept = anchor),
        linetype = 2
      ) +
      ggplot2::labs(y = "APD vs anchor", x = NULL) +
      ggplot2::theme_minimal(base_size = 18)

    gg
  } else {
    if (is.null(anchor_year)) {
      stop("Provide `anchor_year` when facet = FALSE")
    }
    # Extract the single series for the requested anchor
    df_single <- anchor_series_from_apd(APD, anchor_year = anchor_year)

    gg <- ggplot2::ggplot(df_single, ggplot2::aes(x = year, y = apd)) +
      ggplot2::geom_line() +
      ggplot2::geom_point(size = 1.5) +
      ggplot2::geom_smooth(
        method = "loess",
        se = FALSE,
        color = "blue",
        alpha = 0.9,
        linetype = 1,
        span = span
      ) +
      # Single vertical dashed line at the anchor year
      ggplot2::geom_vline(xintercept = as.integer(anchor_year), linetype = 2) +
      ggplot2::labs(y = "APD vs anchor", x = NULL) +
      ggplot2::theme_minimal(base_size = 18)

    gg
  }
}

#: Method for text analysis-------------------------

#' Compute Term Frequency–Inverse Document Frequency (TF–IDF) for tokenized documents
#'
#' @title Compute TF–IDF in a data.table
#' @description
#' Calculate term frequency (TF), document frequency (DF), inverse document
#' frequency (IDF) and TF–IDF scores for tokens within documents stored in a
#' `data.table`. The result contains one row per unique token × document pair
#' with common TF–IDF components.
#'
#' @param dt data.table or data.frame. Table containing at least two columns:
#'   a token column and a document identifier column. May contain multiple rows
#'   per token occurrence. The function coerces to `data.table` internally and
#'   works on a copy (does not modify the input).
#' @param token_col character scalar. Name of the token column (e.g., `"word"`,
#'   `"token"`). Each cell is expected to be a single token (character). `NA`
#'   tokens are kept in counts unless pre-filtered by the caller.
#' @param document_col character scalar. Name of the document identifier column
#'   (e.g., `"doc"`, `"document"`, `"time_window"`). Identifiers may be numeric
#'   or character; they are treated as grouping keys. `NA` document ids are kept.
#'
#' @return A `data.table` with one row per unique token × document pair and at
#'   least the following columns (in addition to the original identifier columns):
#'   - `absolute_tf` (integer): total count of the token across all documents.
#'   - `nb_word` (integer): total number of token occurrences in the document.
#'   - `tf` (numeric): term frequency within the document (token count in doc / nb_word).
#'   - `df` (integer): document frequency — number of distinct documents containing the token.
#'   - `idf` (numeric): inverse document frequency computed as `log(total_docs / df)`.
#'   - `tf_idf` (numeric): TF–IDF score computed as `tf * idf`.
#'   If the input contains no rows the function returns an empty `data.table`
#'   with the above columns (as appropriate).
#'
#' @details
#' This function implements a compact, data.table-based TF–IDF pipeline:
#' 1. Coerce input to `data.table` and operate on a copy to avoid side effects.
#' 2. Temporarily rename the supplied `token_col` and `document_col` to
#'    `token` and `document` for concise expressions.
#' 3. Compute global token counts (`absolute_tf`), per-document totals
#'    (`nb_word`), and per-document token frequency (`tf`) using grouped `.N`.
#' 4. Reduce to unique token×document rows so DF is computed per token correctly.
#' 5. Compute DF (`df`), IDF (`log(total_docs / df)`), and TF–IDF (`tf * idf`).
#'
#' Implementation notes:
#' - Algorithmic choices and trade-offs:
#'   - Uses `data.table` grouped operations (`.N`) for speed and low memory overhead.
#'   - The function keeps `NA` values in token/document columns (they count as a key)
#'     rather than silently dropping them; callers should pre-filter missing tokens
#'     or documents if that is desired.
#'   - `idf` uses the natural logarithm; alternative scalings (add-one smoothing,
#'     log1p, idf with +1 in denominator) are possible but not applied here.
#' - Preconditions and validation:
#'   - `dt` must contain the named token and document columns; otherwise the
#'     function errors early with `stop()`.
#'   - The function assumes each row of `dt` represents one token occurrence.
#' - Edge cases / failure modes:
#'   - If a token appears in zero documents (impossible given the pipeline), `df`
#'     would be zero and `idf` would be -Inf; this cannot occur because `df` is
#'     computed from observed rows.
#'   - Very large corpora may produce large `absolute_tf` and `nb_word` values;
#'     they remain integers but may overflow in extreme pathological cases.
#' - Dependencies / side-effects:
#'   - Depends on `data.table`. Operates on a local copy and does not modify the
#'     caller's object or global state.
#'
#' @examples
#' library(data.table)
#' dt <- data.table(doc = c(1, 1, 2, 2, 2, 3), word = c("apple", "banana", "apple", "apple", "kiwi", "banana"))
#' compute_tf_idf(dt, token_col = "word", document_col = "doc")
#'
#' # Edge case: an empty data.table yields an empty result
#' compute_tf_idf(data.table::data.table(word = character(0), doc = integer(0)))
#'
#' @seealso \code{\link[data.table]{data.table}}, \code{\link[base]{log}}
#' @keywords text tf-idf
#' @export
#' @author Your Name
compute_tf_idf <- function(dt, token_col = "token", document_col = "document") {
  # Coerce to data.table and operate on a copy to avoid mutating caller data.
  dt <- data.table::as.data.table(dt)
  dt <- data.table::copy(dt)

  # Ensure inputs are character vectors
  document_col <- as.character(document_col)
  token_col <- as.character(token_col)

  # Validate required columns exist; provide a clear error if not.
  if (!all(document_col %in% colnames(dt))) {
    stop(
      "Input must contain document column(s): ",
      paste(document_col, collapse = ", "),
      call. = FALSE
    )
  }
  if (!token_col %in% colnames(dt)) {
    stop("Input must contain token column: ", token_col, call. = FALSE)
  }

  # Prevent collision: token_col must not be one of the document grouping columns
  if (token_col %in% document_col) {
    stop("`token_col` must be distinct from `document_col`", call. = FALSE)
  }

  # Create a temporary composite document key when multiple document columns are provided.
  # Use a name unlikely to collide with existing columns.
  doc_key <- ".document_tmp_key"
  i <- 1L
  while (doc_key %in% colnames(dt)) {
    doc_key <- paste0(".document_tmp_key", i)
    i <- i + 1L
  }

  if (length(document_col) == 1L) {
    # If single document column, create the temp key as a copy for uniform downstream code
    dt[, (doc_key) := as.character(.SD[[1]]), .SDcols = document_col]
  } else {
    # Multiple columns: paste together with a separator unlikely to appear in values
    dt[,
      (doc_key) := do.call(paste, c(.SD, sep = "\r")),
      .SDcols = document_col
    ]
  }

  # Temporarily standardise token column name to `token` to simplify expressions.
  if (token_col != "token") {
    data.table::setnames(dt, token_col, "token")
    token_was_renamed <- TRUE
  } else {
    token_was_renamed <- FALSE
  }

  # Compute counts using grouped `.N`:
  # - `absolute_tf`: total occurrences of each token across the corpus
  # - `nb_word`: number of token occurrences in each document (composite)
  # - `tf`: token occurrences in (document, token) divided by document length
  #
  # Use character column name for doc_key in by= (data.table accepts string names).
  dt[, absolute_tf := .N, by = "token"]
  dt[, nb_word := .N, by = doc_key]
  dt[, tf := .N / nb_word, by = c(doc_key, "token")]

  # Reduce to unique token × document rows for DF and TF–IDF computation.
  tokens_count <- unique(dt)

  # Document frequency: number of distinct documents containing each token.
  df_dt <- tokens_count[, .N, by = "token"]
  data.table::setnames(df_dt, "N", "df")

  # Merge DF into tokens_count (left join), compute IDF and TF–IDF.
  total_docs <- uniqueN(tokens_count[[doc_key]]) # total number of distinct documents (composite)
  tokens_count <- merge(
    tokens_count,
    df_dt,
    by = "token",
    all.x = TRUE,
    sort = FALSE
  )

  # IDF: natural log of (total_docs / df). This follows idf = log(N/df).
  tokens_count[, idf := log(total_docs / df)]

  # TF–IDF = tf * idf
  tokens_count[, tf_idf := tf * idf]

  # Restore token original name
  if (token_was_renamed) {
    data.table::setnames(tokens_count, "token", token_col)
  }

  # If original document_col was a single column, rename the composite back to that name.
  # If multiple document columns were used, remove the composite key (original columns are preserved).
  if (length(document_col) == 1L) {
    data.table::setnames(tokens_count, doc_key, document_col)
  } else {
    # remove composite helper column before returning to avoid confusing callers
    tokens_count[, (doc_key) := NULL]
  }

  # Return the data.table (explicit [] to print when called interactively)
  tokens_count[]
}

#: Function for Shiny App-------------------------
#' Launch an Interactive Shiny App to Explore Network Graphs
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' This function launches an interactive Shiny application to explore one or several
#' network graphs (as `tbl_graph` or list of `tbl_graph`). If a list is passed, each
#' graph should be named according to its time window (e.g., "2010-2012"), enabling dynamic selection.
#'
#' The interface supports cluster exploration, tooltip interactivity, layout computation, and node metadata inspection.
#'
#' @param graph_tbl A `tbl_graph` object or a **named list of `tbl_graph`**, each representing a time window.
#' @param cluster_id Column name in the node data identifying clusters.
#' @param cluster_information Character vector of node metadata columns to show in the table.
#' @param cluster_tooltip Optional. Tooltip shown when hovering over cluster labels.
#' @param node_id Column name identifying node IDs.
#' @param node_tooltip Optional. Tooltip for node-level interaction.
#' @param node_size Optional. Column name used to scale node size.
#' @param color Optional. Column used to color nodes. If `NULL`, colors are generated.
#' @param layout Character. Layout algorithm passed to `networkflow::layout_networks()` (e.g., `"kk"`, `"fr"`).
#'
#' @return A Shiny app interface to interact with the network graph(s).
#' @export
launch_network_app <- function(
  graph_tbl,
  cluster_id,
  cluster_information,
  cluster_tooltip = NULL,
  node_id,
  cluster_sentences,
  top_references,
  top_references_without_id,
  cluster_origins,
  cluster_destinies,
  tf_idf_data,
  node_tooltip = NULL,
  node_size = NULL,
  color = NULL,
  layout = "kk"
) {
  stopifnot(
    requireNamespace("shiny"),
    requireNamespace("ggiraph"),
    requireNamespace("ggplot2"),
    requireNamespace("DT"),
    requireNamespace("dplyr"),
    requireNamespace("ggraph"),
    requireNamespace("rlang"),
    requireNamespace("purrr"),
    requireNamespace("shinycssloaders"),
    requireNamespace("tidygraph"),
    requireNamespace("networkflow"),
    requireNamespace("cli"),
    requireNamespace("htmltools"),
    requireNamespace("jsonlite") # add
  )

  # Validate input
  is_list_graph <- is.list(graph_tbl) &&
    all(purrr::map_lgl(graph_tbl, ~ inherits(.x, "tbl_graph")))
  if (is_list_graph && is.null(names(graph_tbl))) {
    cli::cli_abort(
      "The list of graphs must be named, where names correspond to time windows (e.g., '2010-2012')."
    )
  }

  if (!is.null(layout)) {
    cli::cli_alert_info(
      "Computing layout with {.fn networkflow::layout_networks} using layout = '{layout}'"
    )
    graph_tbl <- networkflow::layout_networks(
      graphs = graph_tbl,
      node_id = node_id,
      layout = layout
    )
  }

  if (is.null(color)) {
    cli::cli_alert_info(
      "Generating node colors via {.fn networkflow::color_networks}"
    )
    graph_tbl <- networkflow::color_networks(
      graphs = graph_tbl,
      column_to_color = cluster_id,
      unique_color_across_list = FALSE
    )
    color <- "color"
  }

  # Symbols
  color_sym <- rlang::sym(color)
  cluster_sym <- rlang::sym(cluster_id)
  id_sym <- rlang::sym(node_id)
  tooltip_sym <- if (!is.null(node_tooltip)) rlang::sym(node_tooltip) else NULL
  id_chr <- rlang::as_name(id_sym)
  cluster_chr <- rlang::as_name(cluster_sym)

  # UI
  ui <- shiny::fluidPage(
    shiny::titlePanel("Network Explorer"),
    shiny::sidebarLayout(
      sidebarPanel = shiny::sidebarPanel(
        width = 3,
        if (is_list_graph) {
          shiny::selectInput(
            "selected_graph",
            "Select Time Window:",
            choices = names(graph_tbl),
            selected = names(graph_tbl)[1]
          )
        },
        #       shiny::sliderInput("min_edge_width", "Min Edge Width:", min = 0.1, max = 10, value = 1, step = 0.1),
        #      shiny::sliderInput("max_edge_width", "Max Edge Width:", min = 0.1, max = 10, value = 3, step = 0.1),
        shiny::sliderInput(
          "min_node_size",
          "Min Node Size:",
          min = 0.1,
          max = 10,
          value = 1,
          step = 0.1
        ),
        shiny::sliderInput(
          "max_node_size",
          "Max Node Size:",
          min = 0.1,
          max = 10,
          value = 10,
          step = 0.1
        ),
        shiny::sliderInput(
          "label_size",
          "Label size",
          min = 0.5,
          max = 5,
          value = 2.2,
          step = 0.1
        ),

        # shiny::hr(),
        # shiny::h5("Cluster composition"),
        DT::DTOutput("cluster_share")
      ),
      mainPanel = shiny::mainPanel(
        shiny::div(
          style = "border: 1px solid #ccc; padding: 10px; border-radius: 5px;",
          shinycssloaders::withSpinner(
            ggiraph::girafeOutput(
              "network_plot",
              width = "100%",
              height = "600px"
            )
          )
        ),
        shiny::hr(),
        shiny::uiOutput("info_panel")
      )
    )
  )

  # Server
  server <- function(input, output, session) {
    selected_cluster <- shiny::reactiveVal(NULL)
    selected_node_id <- shiny::reactiveVal(NULL)

    all_nodes_df <- shiny::reactive({
      if (is_list_graph) {
        purrr::imap_dfr(graph_tbl, function(g, nm) {
          df <- tidygraph::activate(g, "nodes") |> as.data.frame()
          df$.graph <- nm
          if (!"time_window" %in% names(df)) {
            df$time_window <- nm
          }
          df
        })
      } else {
        df <- tidygraph::activate(graph_tbl, "nodes") |> as.data.frame()
        df$.graph <- "graph"
        if (!"time_window" %in% names(df)) {
          df$time_window <- NA_character_
        }
        df
      }
    })

    active_graph <- shiny::reactive({
      if (is_list_graph) graph_tbl[[input$selected_graph]] else graph_tbl
    })

    cluster_nodes_raw <- shiny::reactive({
      req(selected_cluster())
      g_tbl <- active_graph()
      tidygraph::activate(g_tbl, "nodes") |>
        as.data.frame() |>
        dplyr::filter(!!cluster_sym == selected_cluster())
    })

    output$network_plot <- ggiraph::renderGirafe({
      g_tbl <- active_graph()
      g_tbl <- tidygraph::activate(g_tbl, "nodes")

      if (is.null(node_size)) {
        g_tbl <- dplyr::mutate(g_tbl, size = 1)
      } else {
        if (!(node_size %in% colnames(as.data.frame(g_tbl)))) {
          cli::cli_abort(
            "The column specified in {.arg node_size} does not exist in the node data."
          )
        }
        g_tbl <- dplyr::mutate(g_tbl, size = !!rlang::sym(node_size))
      }

      nodes_df <- as.data.frame(tidygraph::activate(g_tbl, "nodes"))

      required_cols <- c(cluster_id, node_id, color, "size", "x", "y")
      missing_main <- setdiff(required_cols, colnames(nodes_df))
      missing_info <- setdiff(cluster_information, colnames(nodes_df))

      if (length(missing_main) > 0 || length(missing_info) > 0) {
        cli::cli_abort(
          "Missing required columns in nodes: {paste(c(missing_main, missing_info), collapse = ', ')}"
        )
      }

      # Build aesthetics for nodes
      node_aes <- list(
        x = quote(x),
        y = quote(y),
        fill = color_sym,
        size = quote(size),
        data_id = id_sym # <— was tooltip_sym
      )
      if (!is.null(tooltip_sym)) {
        node_aes$tooltip <- tooltip_sym
        #    node_aes$data_id <- tooltip_sym
      } else {
        node_aes$tooltip <- id_sym # fallback tooltip
      }

      # Cluster label data
      label_data <- nodes_df %>%
        dplyr::group_by(!!cluster_sym) %>%
        dplyr::summarise(
          label_x = mean(x, na.rm = TRUE),
          label_y = mean(y, na.rm = TRUE),
          color = first(!!color_sym),
          cluster_label = first(!!cluster_sym),
          .groups = "drop"
        )

      label_aes <- list(
        x = quote(label_x),
        y = quote(label_y),
        label = quote(cluster_label),
        data_id = quote(cluster_label),
        fill = quote(color)
      )
      if (!is.null(cluster_tooltip)) {
        label_aes$tooltip <- cluster_tooltip
      }

      #   edge_width_range <- c(input$min_edge_width, input$max_edge_width)
      node_size_range <- c(input$min_node_size, input$max_node_size)
      label_size <- input$label_size

      g <- ggraph::ggraph(g_tbl, layout = "manual", x = x, y = y) +
        # ggraph::geom_edge_arc0(
        #   ggplot2::aes(color = !!color_sym, width = weight),
        #   alpha = 0.3, strength = 0.2, show.legend = FALSE
        # ) +
        ggiraph::geom_point_interactive(
          mapping = do.call(ggplot2::aes, node_aes),
          shape = 21,
          alpha = 0.8,
          show.legend = FALSE
        ) +
        ggiraph::geom_label_repel_interactive(
          data = label_data,
          mapping = do.call(ggplot2::aes, label_aes),
          alpha = 0.9,
          fontface = "bold",
          show.legend = FALSE,
          size = label_size,
        ) +
        # ggraph::scale_edge_width_continuous(range = edge_width_range) +
        ggplot2::scale_size_continuous(range = node_size_range) +
        # ggraph::scale_edge_colour_identity() +
        ggplot2::scale_fill_identity() +
        ggplot2::theme_void()

      ggiraph::girafe(
        ggobj = g,
        width_svg = 10,
        height_svg = 6,
        options = list(
          ggiraph::opts_selection(type = "single"),
          ggiraph::opts_zoom(min = 1, max = 12), # wheel to zoom, drag to pan
          ggiraph::opts_toolbar(position = "topright") # gives reset zoom button)
        )
      )
    })

    shiny::observeEvent(input$network_plot_selected, {
      sel <- input$network_plot_selected
      nodes_all <- all_nodes_df()
      nodes_here <- tidygraph::activate(active_graph(), "nodes") |>
        as.data.frame()

      if (!is.null(sel) && sel %in% nodes_all[[id_chr]]) {
        # clicked a node -> show ONLY node info
        selected_node_id(sel)
        selected_cluster(NULL)
      } else if (!is.null(sel) && sel %in% nodes_here[[cluster_chr]]) {
        # clicked a cluster label -> show ONLY cluster info
        selected_cluster(sel)
        selected_node_id(NULL)
      } else {
        selected_node_id(NULL)
        selected_cluster(NULL)
      }
    })

    output$info_panel <- shiny::renderUI({
      if (!is.null(selected_node_id())) {
        tagList(
          shiny::h4("Selected node"),
          DT::DTOutput("node_info")
        )
      } else if (!is.null(selected_cluster())) {
        cl <- if (is_list_graph) {
          paste0(
            selected_cluster(),
            " — ",
            input$selected_graph,
            "-",
            as.integer(input$selected_graph) + 7
          )
        } else {
          as.character(selected_cluster())
        }
        tagList(
          shiny::h4(paste0("Documents in ", cl)),
          shiny::uiOutput("role_filter_ui"),
          DT::DTOutput("cluster_docs"),
          shiny::h4(paste0("Closest sentences for ", cl)),
          DT::DTOutput("cluster_sentences"),
          shiny::h4(paste0("Top References of ", cl)),
          DT::DTOutput("cluster_refs"),
          shiny::h4(paste0("Top References (without ID) of ", cl)),
          DT::DTOutput("cluster_refs_without_id"),
          shiny::h4(paste0("Cluster tf-idf for ", cl)),
          DT::DTOutput("cluster_tf_idf"),
          shiny::h4(paste0("Cluster origins for ", cl, " (t-1 → t)")),
          DT::DTOutput("cluster_origins_table"),
          shiny::h4(paste0("Cluster destinies for ", cl, " (t → t+1)")),
          DT::DTOutput("cluster_destinies_table")
        )
      } else {
        NULL
      }
    })

    output$cluster_share <- DT::renderDT({
      g_tbl <- active_graph()
      nodes <- tidygraph::activate(g_tbl, "nodes") %>% as.data.frame()

      tab <- nodes %>%
        dplyr::count(!!cluster_sym, name = "n") %>%
        dplyr::mutate(
          prop = n / sum(n),
          pct = sprintf("%.1f%%", 100 * prop)
        ) %>%
        dplyr::arrange(dplyr::desc(prop)) %>%
        dplyr::rename(Cluster = !!cluster_sym) %>%
        dplyr::select(Cluster, n, pct)

      DT::datatable(
        tab,
        options = list(dom = 't', paging = FALSE),
        rownames = FALSE
      )
    })

    output$node_info <- DT::renderDT({
      req(selected_node_id())
      nodes_all <- all_nodes_df()

      out <- nodes_all |>
        dplyr::filter(.data[[id_chr]] == selected_node_id()) |>
        dplyr::arrange(.graph) |>
        dplyr::select(
          dplyr::any_of(c(
            "time_window",
            cluster_id,
            cluster_information,
            node_size
          )),
          -sentence
        )

      tbl <- DT::datatable(
        out,
        options = list(pageLength = 10),
        escape = FALSE,
        rownames = FALSE
      )

      if (is_list_graph && "time_window" %in% names(out)) {
        lv <- unique(out$time_window)
        year <- lv %>% str_extract("^\\d+")
        col <- ifelse(year == input$selected_graph, "#fff3cd", "") # pale yellow
        tbl <- DT::formatStyle(
          tbl,
          "time_window",
          target = "row",
          backgroundColor = DT::styleEqual(lv, col)
        )
      }

      tbl
    })

    output$cluster_docs <- DT::renderDT({
      df <- cluster_nodes_raw()

      # role filter
      if (
        !is.null(input$role_filter) &&
          input$role_filter != "All" &&
          "role" %in% names(df)
      ) {
        df <- dplyr::filter(df, .data$role == input$role_filter)
      }

      # role tooltips (HTML)
      role_expl <- c(
        R1 = "Ultra-peripheral node: z low, P < 0.05. Almost all links within its cluster.",
        R2 = "Peripheral node: z low, 0.05 ≤ P < 0.62. Mostly within-cluster links.",
        R3 = "Connector node: z low, 0.62 ≤ P < 0.80. Many links to other clusters.",
        R4 = "Kinless node: z low, P ≥ 0.80. Links spread across clusters.",
        R5 = "Provincial hub: z high, P < 0.30. Hub inside its cluster.",
        R6 = "Connector hub: z high, 0.30 ≤ P < 0.75. Hub bridging clusters.",
        R7 = "Kinless hub: z high, P ≥ 0.75. Hub linked broadly across clusters."
      )
      role_alias <- c(
        "ultra-peripheral" = "R1",
        "peripheral" = "R2",
        "connector" = "R3",
        "kinless" = "R4",
        "provincial hub" = "R5",
        "connector hub" = "R6",
        "kinless hub" = "R7"
      )
      norm_label <- function(x) {
        x <- trimws(as.character(x))
        x <- gsub("[\u2010-\u2015]", "-", x)
        x <- gsub("\\s+", " ", x)
        tolower(x)
      }
      if ("role" %in% names(df)) {
        df$role <- vapply(
          df$role,
          function(val) {
            key <- role_alias[[norm_label(val)]]
            desc <- if (!is.null(key)) {
              role_expl[[key]]
            } else {
              "Role description unavailable"
            }
            sprintf(
              '<span title="%s">%s</span>',
              htmltools::htmlEscape(desc),
              htmltools::htmlEscape(as.character(val))
            )
          },
          FUN.VALUE = character(1)
        )
      }

      shown_cols <- intersect(cluster_information, names(df))
      if (!length(shown_cols)) {
        shown_cols <- setdiff(names(df), c("x", "y", ".graph"))
      }
      shown <- df |> dplyr::select(dplyr::all_of(shown_cols))

      # indices of numeric columns to tooltip (0-based for DataTables)
      cols <- colnames(shown)
      # indices (0-based)
      cols <- colnames(shown)
      z_idx <- match("z_within", cols) - 1L
      p_idx <- match("participation_coefficient", cols) - 1L

      # detailed tooltips
      z_expl <- paste(
        "Within-cluster degree z (standardized).",
        "Formula: z = (k_iC - mean(k_C)) / sd(k_C),",
        "  k_iC = links/weight from node i to nodes in its cluster C.",
        "Interpretation: higher = more hub-like inside its cluster; ~0 = average.",
        "Rule of thumb: z > 2.5 → hub.",
        sep = "\n"
      )
      p_expl <- paste(
        "Participation coefficient P ∈ [0,1].",
        "Formula: P = 1 - Σ_C (k_iC / k_i)^2,",
        "  k_iC = links/weight from i to cluster C; k_i = total links/weight of i.",
        "Interpretation: 0 = all links in one cluster; 1 = evenly spread across clusters.",
        "Typical cutoffs: ~0.05 local, ~0.30 local hub, ~0.62 connector, ≥0.80 kinless-like.",
        sep = "\n"
      )

      # JS callback to add title=... without changing data types

      js_row_cb <- DT::JS(paste0(
        "function(row,data){",
        if (!is.na(z_idx)) {
          paste0(
            "$('td:eq(",
            z_idx,
            ")', row).attr('title', ",
            jsonlite::toJSON(z_expl, auto_unbox = TRUE),
            ");"
          )
        } else {
          ""
        },
        if (!is.na(p_idx)) {
          paste0(
            "$('td:eq(",
            p_idx,
            ")', row).attr('title', ",
            jsonlite::toJSON(p_expl, auto_unbox = TRUE),
            ");"
          )
        } else {
          ""
        },
        "}"
      ))

      # format numbers for display only; keep raw for sort/filter
      num_renderer <- DT::JS(
        "function(data,type,row,meta){ if(type === 'display'){ if(data == null) return ''; return Number(data).toFixed(3);} return data; }"
      )
      col_defs <- list()
      if (!is.na(z_idx)) {
        col_defs <- c(
          col_defs,
          list(list(targets = z_idx, render = num_renderer))
        )
      }
      if (!is.na(p_idx)) {
        col_defs <- c(
          col_defs,
          list(list(targets = p_idx, render = num_renderer))
        )
      }

      DT::datatable(
        shown,
        filter = "top",
        escape = -which(cols %in% c("role", "Titre")), # do not escape role HTML; escape others
        rownames = FALSE,
        options = list(
          dom = "lfrtip",
          searchHighlight = TRUE,
          rowCallback = js_row_cb,
          columnDefs = col_defs
        )
      )
    })

    output$role_filter_ui <- shiny::renderUI({
      df <- cluster_nodes_raw()
      roles <- sort(unique(as.character(df$role)))
      if (!length(roles)) {
        return(NULL)
      }
      shiny::selectInput(
        "role_filter",
        "Filter by role:",
        choices = c("All", roles),
        selected = "All"
      )
    })

    output$cluster_sentences <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()

      # join on (time_window, cluster_id) exactly like top_references
      sentences <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        dplyr::distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(cluster_sentences)

      tab <- sentences %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        # pick reasonable columns if present
        dplyr::select(dplyr::any_of(c(
          cluster_information,
          "sentence",
          "similarity"
        )))
      DT::datatable(
        tab,
        escape = FALSE,
        options = list(pageLength = 15),
        rownames = FALSE
      )
    })

    output$cluster_refs <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      main_refs_cluster <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(top_references)
      main_refs_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(Nom, Annee, Revue_Abbrege, nb_cit) %>%
        DT::datatable(options = list(pageLength = 20))
    })

    output$cluster_refs_without_id <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      main_refs_cluster <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(top_references_without_id)
      main_refs_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(Nom, Annee, Revue_Abbrege, nb_cit) %>%
        DT::datatable(options = list(pageLength = 10))
    })

    output$cluster_tf_idf <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      tf_idf_for_cluster <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(tf_idf_data) %>%
        filter(!is.na(term))
      tf_idf_for_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(term, tf_idf) %>%
        mutate(tf_idf = round(tf_idf, 4)) %>%
        DT::datatable(options = list(pageLength = 20))
    })

    output$cluster_origins_table <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      origins <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(cluster_origins)
      origins %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(previous_cluster, origin_percent) %>%
        mutate(origin_percent = sprintf("%.1f%%", 100 * origin_percent)) %>%
        DT::datatable(options = list(pageLength = 10))
    })

    output$cluster_destinies_table <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      destinies <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(cluster_destinies)
      destinies %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(forward_cluster, destiny_percent) %>%
        mutate(destiny_percent = sprintf("%.1f%%", 100 * destiny_percent)) %>%
        DT::datatable(options = list(pageLength = 10))
    })
  }

  shiny::shinyApp(ui = ui, server = server)
}


#: Functions for network analysis-------------------------

#' Automatically Label Clusters Using Ollama::generate()
#'
#' @description
#' For each cluster in a `tbl_graph` or a list of `tbl_graph`s, this function aggregates
#' selected textual node metadata, passes it to a local LLM via `ollamar::generate()`,
#' and assigns a concise label back to the cluster.
#'
#' @param graph_tbl A `tbl_graph` or a named list of `tbl_graph` objects.
#' @param cluster_id Column name used to group nodes into clusters.
#' @param cluster_information Character vector of node metadata columns to include.
#' @param model Name of the Ollama model to use (e.g., "llama3", "mistral").
#' @param max_words Maximum number of words allowed in the label (default = 5).
#'
#' @return A `tbl_graph` or list of `tbl_graphs` with `cluster_label` added to nodes.
#' @export
label_cluster_llm <- function(
  graph_tbl,
  cluster_id,
  cluster_information,
  model = "llama3.1",
  max_words = 5
) {
  library(dplyr)
  library(tidygraph)
  library(data.table)
  library(ollamar)
  library(jsonlite)
  library(rlang)

  label_one_graph <- function(g) {
    g_df <- activate(g, "nodes") %>% as_tibble()

    if (!cluster_id %in% colnames(g_df)) {
      stop("cluster_id not found in node data.")
    }
    if (!all(cluster_information %in% colnames(g_df))) {
      stop("Some cluster_information columns are missing.")
    }

    cluster_ids <- unique(g_df[[cluster_id]])
    cluster_labels <- vector("list", length(cluster_ids))

    for (i in seq_along(cluster_ids)) {
      cid <- cluster_ids[i]
      cluster_data <- g_df %>% filter(!!sym(cluster_id) == cid)

      data_text <- cluster_data %>%
        select(all_of(cluster_information)) %>%
        mutate(across(everything(), as.character)) %>%
        mutate(row = row_number()) %>%
        pivot_longer(-row, names_to = "field", values_to = "content") %>%
        group_by(field) %>%
        summarise(values = list(na.omit(content)), .groups = "drop") %>%
        data.table::as.data.table()

      json_input <- toJSON(data_text, pretty = TRUE)

      prompt <- paste0(
        "Here is a cluster or scientific articles in economics made using bibliographic coupling.
                       Each article is described by its metadada.
                       Using this information to name cluster using no more than 5 words.
                       Your output should start with the name of the cluster followed by a full stop.
                       Your output should only be the name of the cluster, nothing else. I insist: output only the name of the cluster.
                       Here is the data: ",
        json_input
      )

      label <- ollamar::generate(
        model = model,
        prompt = prompt,
        output = "text"
      )

      cluster_labels[[i]] <- tibble(
        !!sym(cluster_id) := cid,
        cluster_label = trimws(label)
      )
    }

    cluster_labels_df <- bind_rows(cluster_labels)

    g <- g %>%
      activate(nodes) %>%
      left_join(cluster_labels_df, by = cluster_id)

    return(g)
  }

  if (inherits(graph_tbl, "list")) {
    return(lapply(graph_tbl, label_one_graph))
  } else if (inherits(graph_tbl, "tbl_graph")) {
    return(label_one_graph(graph_tbl))
  } else {
    stop("Input must be a tbl_graph or a named list of tbl_graphs.")
  }
}

#' Fast P and z metrics for Guimerà–Amaral role analysis
#'
#' Compute, for every node, the total strength \eqn{s_i}, the participation
#' coefficient \eqn{P_i}, and the within-cluster strength z-score \eqn{z_i},
#' using a single pass over the edge list. This function **does not** assign
#' discrete roles; it returns the metrics used to classify roles later.
#'
#' @details
#' Let \eqn{C(v)} be the cluster/community of node \eqn{v} (taken from
#' `comm_attr`). Let \eqn{w_{uv}} be the edge weight (from `weight_attr`).
#'
#' - **Strength to cluster \eqn{c}**: \eqn{s_{v,c} = \sum_{u \in c} w_{uv}}.
#' - **Total strength**: \eqn{s_v = \sum_c s_{v,c}}.
#' - **Participation coefficient**:
#'   \deqn{P_v = 1 - \sum_c \left(\frac{s_{v,c}}{s_v}\right)^2,}
#'   with \eqn{P_v \in [0,1]}. For isolates (\eqn{s_v = 0}), \eqn{P_v = NA}.
#' - **Within-cluster z-score**:
#'   \deqn{z_v = \frac{s_{v,C(v)} - \mu_{C(v)}}{\sigma_{C(v)}},}
#'   where \eqn{\mu_{C}} and \eqn{\sigma_{C}} are the mean and SD of
#'   \eqn{s_{u,C}} over nodes \eqn{u} in cluster \eqn{C}. If \eqn{\sigma_{C}=0}
#'   (single-node or uniform cluster), \eqn{z_v = 0}.
#'
#' The computation treats the graph as undirected for strengths (each edge
#' contributes to both endpoints). If direction matters, supply a symmetrized
#' `weight_attr` beforehand or adapt the function.
#'
#' @param graph An `igraph` (or `tidygraph::tbl_graph`) object with:
#'   - a vertex attribute `comm_attr` giving a cluster/community ID for every node,
#'   - an optional edge attribute `weight_attr` (defaults to uniform weight 1 when missing).
#' @param comm_attr Character scalar. Name of the vertex attribute holding cluster IDs.
#'   Default: `"cluster_leiden"`.
#' @param weight_attr Character scalar. Name of the edge attribute holding weights.
#'   Default: `"weight"`.
#'
#' @return A named list of numeric vectors of length `vcount(graph)`:
#' \describe{
#'   \item{total_strength}{Total incident weight \eqn{s_v}.}
#'   \item{participation_coefficient}{\eqn{P_v} in \[0,1\]; `NA` for isolates.}
#'   \item{z_within}{Within-cluster z-score \eqn{z_v}.}
#' }
#'
#' @section Performance:
#' Single aggregation over the edge list. Time \eqn{O(E)}, memory \eqn{O(E)}.
#' Suitable for large sparse graphs. No per-node `incident()` loops.
#'
#' @note To obtain discrete roles (e.g., R1–R7), learn thresholds on
#' `z_within` and `participation_coefficient` (e.g., fixed or data-driven)
#' and apply a `dplyr::case_when()` mapping.
#'
#' @examples
#' # toy example
#' library(igraph)
#' g <- make_ring(6)
#' V(g)$cluster_leiden <- c(1,1,1,2,2,2)
#' E(g)$weight <- 1
#' m <- compute_role_fast(g)  # list(total_strength, participation_coefficient, z_within)
#' head(m$participation_coefficient)
#'
#' @references
#' Guimerà, R., & Amaral, L. A. N. (2005). Functional cartography of complex
#' metabolic networks. *Nature*, 433, 895–900.
#'
#' @seealso \code{\link{vcount}}, \code{\link{ecount}}
#' @export
compute_role_fast <- function(
  graph,
  comm_attr = "cluster_leiden",
  weight_attr = "weight"
) {
  cli::cli_alert_info(
    "Computing roles for graph with {gorder(graph)} nodes and {gsize(graph)} edges."
  )
  n <- gorder(graph)
  comm <- igraph::vertex_attr(graph, comm_attr)
  if (is.null(comm)) {
    stop("vertex attribute ", comm_attr, " missing")
  }
  comm <- as.integer(factor(comm, levels = unique(comm))) # compact

  el <- igraph::as_edgelist(graph, names = FALSE) # m x 2
  w <- igraph::edge_attr(graph, weight_attr)
  if (is.null(w)) {
    w <- rep(1, nrow(el))
  }

  # Each edge contributes weight w to each endpoint toward the OTHER endpoint's community
  dt <- data.table(
    node = c(el[, 1], el[, 2]),
    other = c(el[, 2], el[, 1]),
    w = c(w, w)
  )
  dt[, comm_other := comm[other]]
  dt[, other := NULL]

  # s_ic: strength from node i to community c
  s_ic <- dt[, .(s = sum(w)), by = .(node, comm = comm_other)]

  # total strength s_i
  s_i <- s_ic[, .(total_strength = sum(s)), by = node]
  total_strength <- numeric(n)
  if (nrow(s_i)) {
    total_strength[s_i$node] <- s_i$total_strength
  }

  # Participation P_i = 1 - sum_c (s_ic / s_i)^2
  tmp <- s_ic[s_i, on = "node"] # join s_i
  tmp[, frac2 := (s / total_strength)^2]
  Ptab <- tmp[, .(P = 1 - sum(frac2)), by = node]
  P <- rep(NA_real_, n)
  if (nrow(Ptab)) {
    P[Ptab$node] <- Ptab$P
  }
  P[total_strength == 0] <- NA_real_

  # s_in: strength to OWN community
  setkey(s_ic, node, comm)
  idx <- data.table(node = seq_len(n), comm = comm)
  own <- s_ic[idx, .(node, s_in = s), nomatch = 0L]
  s_in <- numeric(n)
  if (nrow(own)) {
    s_in[own$node] <- own$s_in
  }

  # z within each community
  nd <- data.table(node = seq_len(n), comm = comm, s_in = s_in)
  nd[, mu := mean(s_in), by = comm]
  nd[, sdv := sd(s_in), by = comm]
  nd[, z := ifelse(is.finite(sdv) & sdv > 0, (s_in - mu) / sdv, 0)]
  z <- nd$z

  list(
    total_strength = total_strength,
    participation_coefficient = P,
    z_within = z
  )
}

#' Data-driven cut points for Guimerà–Amaral role assignment
#'
#' Learn thresholds to classify nodes into Guimerà–Amaral roles using observed
#' distributions of within-cluster z-scores and participation coefficients.
#' The function estimates:
#' \itemize{
#'   \item a global hub threshold on \code{z} via a high quantile;
#'   \item three non-hub \code{P} cut points (k=4 clusters → 3 cuts) by 1-D k-means;
#'   \item two hub \code{P} cut points  (k=3 clusters → 2 cuts) by 1-D k-means.
#' }
#' If clustering is not feasible (too few points or unique values), canonical
#' defaults are used: \code{c(0.05, 0.62, 0.80)} for non-hubs and
#' \code{c(0.30, 0.75)} for hubs.
#'
#' @details
#' Algorithm:
#' \enumerate{
#'   \item Compute \code{hub_z = quantile(z, hub_q)}.
#'   \item Split \code{P} into non-hub (\code{z < hub_z}) and hub (\code{z >= hub_z}).
#'   \item For each split, run \code{kmeans(P, centers = k)} when possible. Sort the
#'         k centroids \eqn{c_1 < \dots < c_k} and define cut points as midpoints:
#'         \eqn{(c_1+c_2)/2, \dots, (c_{k-1}+c_k)/2}.
#' }
#'
#' Interpretation:
#' \itemize{
#'   \item \code{hub_z}: z cutoff separating hubs vs non-hubs.
#'   \item \code{nonhub_P}: three P cuts mapping to ultra-peripheral, peripheral, connector, kinless.
#'   \item \code{hub_P}: two P cuts mapping to provincial hub, connector hub, kinless hub.
#' }
#'
#' Reproducibility: \code{kmeans} is deterministic given data, but you can set
#' \code{set.seed()} for safety before calling. For cross-window comparability,
#' estimate thresholds on pooled data or on a stratified sample with equal
#' per-window sizes.
#'
#' @param z Numeric vector of within-cluster z-scores.
#' @param P Numeric vector of participation coefficients in \eqn{[0,1]}.
#' @param hub_q Numeric in \eqn{(0,1)}. Quantile of \code{z} used as the hub cutoff.
#'   Default \code{0.975}.
#' @param k_nonhub Integer. Number of k-means clusters for non-hub \code{P}.
#'   Default \code{4}.
#' @param k_hub Integer. Number of k-means clusters for hub \code{P}.
#'   Default \code{3}.
#'
#' @return A list with components:
#' \describe{
#'   \item{\code{hub_z}}{Scalar z cutoff separating hubs and non-hubs.}
#'   \item{\code{nonhub_P}}{Numeric vector of length 3 with P cut points for non-hubs
#'                          (in increasing order).}
#'   \item{\code{hub_P}}{Numeric vector of length 2 with P cut points for hubs
#'                       (in increasing order).}
#' }
#'
#' @examples
#' set.seed(1)
#' z <- c(rnorm(900, 0, 1), rnorm(100, 3, 0.6))     # many non-hubs, some hubs
#' P <- runif(1000)
#' thr <- choose_role_thresholds(z, P)
#' thr$hub_z
#' thr$nonhub_P
#' thr$hub_P
#'
#' # Using the thresholds to assign roles (sketch):
#' # dplyr::case_when(
#' #   z <  thr$hub_z & P <= thr$nonhub_P[1] ~ "ultra-peripheral",
#' #   z <  thr$hub_z & P <= thr$nonhub_P[2] ~ "peripheral",
#' #   z <  thr$hub_z & P <= thr$nonhub_P[3] ~ "connector",
#' #   z <  thr$hub_z                        ~ "kinless",
#' #   z >= thr$hub_z & P <= thr$hub_P[1]    ~ "provincial hub",
#' #   z >= thr$hub_z & P <= thr$hub_P[2]    ~ "connector hub",
#' #   TRUE                                  ~ "kinless hub"
#' # )
#'
#' @seealso \code{\link{compute_role_fast}}, \code{\link[stats]{kmeans}},
#'   \code{\link[stats]{quantile}}
#' @export
choose_role_thresholds <- function(
  z,
  P,
  hub_q = 0.975,
  k_nonhub = 4,
  k_hub = 3
) {
  stopifnot(length(z) == length(P))
  z <- z[is.finite(z)]
  P <- P[is.finite(P)]
  if (!length(z)) {
    stop("empty z")
  }

  hub_thr <- unname(stats::quantile(z, hub_q, na.rm = TRUE))

  nonhub_P <- P[z < hub_thr]
  hub_P <- P[z >= hub_thr]

  get_breaks <- function(x, k, fallback) {
    if (length(x) >= k && length(unique(x)) >= k) {
      km <- stats::kmeans(x, centers = k, iter.max = 100)
      centers <- sort(as.numeric(km$centers))
      sort((centers[-k] + centers[-1]) / 2)
    } else {
      fallback
    }
  }

  nonhub_brks <- get_breaks(nonhub_P, k_nonhub, c(0.05, 0.62, 0.80))
  hub_brks <- get_breaks(hub_P, k_hub, c(0.30, 0.75))

  list(hub_z = hub_thr, nonhub_P = nonhub_brks, hub_P = hub_brks)
}
