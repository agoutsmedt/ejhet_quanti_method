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
