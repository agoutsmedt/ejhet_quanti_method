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
