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
