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
