#' Compute and apply a per-group quantile threshold to filter rows
#'
#' @title Filter rows by per-group quantile threshold
#' @description
#' Compute a quantile threshold from a numeric `metric` within each group and
#' return rows whose `metric` exceeds (or is at least) that per-group threshold.
#'
#' @param dt data.table or data.frame. Table of observations. If a `data.table`
#'   is supplied the function may modify it by reference (adds a temporary
#'   `threshold` column). To avoid in-place mutation, pass `data.table::copy(dt)`.
#' @param group_cols character vector. Names of column(s) used to form groups.
#'   Groups are computed with `data.table`'s `by=`. `NA` values in grouping
#'   columns are treated as a distinct group value.
#' @param metric character scalar. Name of the numeric column to compute the
#'   quantile from (default: `"tf"`). Must exist in `dt` and be coercible to
#'   numeric; missing or non-numeric values in the metric are handled by
#'   `quantile(..., na.rm = TRUE)` (groups with all-`NA` produce `NA` threshold).
#' @param probs numeric scalar in (0, 1). Quantile probability used to compute
#'   the threshold (default: `0.75`). Only a single probability is supported.
#' @param inclusive logical scalar. If `TRUE` rows with `metric >= threshold`
#'   are kept; otherwise only rows with `metric > threshold` are kept.
#' @param keep_threshold logical scalar. If `TRUE` the returned table includes
#'   the computed `threshold` column; otherwise the `threshold` column is
#'   removed before returning (default: `FALSE`).
#'
#' @return A `data.table` (same columns as input, possibly plus `threshold`)
#'   containing the subset of rows that satisfy the per-group comparison.
#'   If no rows match the comparison, an empty `data.table` with the same
#'   columns is returned. If a group's quantile is `NA` (e.g. all `metric`
#'   values are `NA`), no rows from that group will be selected because any
#'   comparison with `NA` yields `NA` (treated as `FALSE` for subsetting).
#'
#' @details
#' The function computes a single scalar quantile per group (using
#' `stats::quantile(..., na.rm = TRUE)`) and then filters rows in that group
#' by comparing the row's `metric` to the group threshold. It is designed for
#' simple per-group thresholding (e.g. keep top 25% by some score within each
#' group).
#'
#' Implementation notes:
#' - Steps performed:
#'   1. Coerce `dt` to a `data.table` (no defensive copy). If the caller passed a
#'      `data.table`, the call will mutate it by adding a `threshold` column.
#'   2. Compute the requested quantile per group with `by = group_cols` and
#'      assign it to a new `threshold` column. The metric column is accessed via
#'      `.SD[[1]]` together with `.SDcols = metric` to avoid NSE and simplify
#'      lookups by name.
#'   3. Subset rows using `>=` or `>` depending on `inclusive`.
#'   4. Optionally drop the `threshold` helper column and return the filtered
#'      `data.table`.
#' - Assumptions and preconditions:
#'   * `metric` and `group_cols` names exist in `dt`.
#'   * `probs` is a single numeric in (0,1).
#' - Edge cases and failure modes:
#'   * If a group contains only `NA` values for `metric` the computed
#'     `threshold` is `NA` and no rows from that group will be returned.
#'   * If `metric` is missing or not coercible to numeric an error may be
#'     raised by `quantile()` or subsequent comparisons.
#'   * This function does not support vector `probs`; supply a scalar.
#' - Trade-offs:
#'   * Uses `data.table` grouping for performance. To prevent in-place
#'     modification of a `data.table` input, the caller must copy before call.
#'
#' @examples
#' library(data.table)
#' dt <- data.table::data.table(
#'   group = c("a", "a", "a", "b", "b"),
#'   tf = c(1, 2, 3, 1, 10)
#' )
#' # keep rows with tf > 75th percentile per group (default)
#' filter_group_quantile(dt, group_cols = "group", metric = "tf", probs = 0.75)
#'
#' # include threshold column and use inclusive comparison
#' filter_group_quantile(dt, group_cols = "group", metric = "tf",
#'   probs = 0.5, inclusive = TRUE, keep_threshold = TRUE)
#'
#' # edge case: group with only NA metric values -> no rows returned for that group
#' dt2 <- data.table::data.table(group = c("x","x"), tf = c(NA_real_, NA_real_))
#' filter_group_quantile(dt2, group_cols = "group", metric = "tf")
#'
#' @keywords internal
#' @seealso stats::quantile, data.table::data.table
#' @author Your Name
filter_group_quantile <- function(
  dt,
  group_cols,
  metric = "tf",
  probs = 0.75,
  inclusive = FALSE, # if TRUE use >=, otherwise >
  keep_threshold = FALSE # if TRUE return the threshold column in result
) {
  # Coerce to data.table for efficient grouping. Note: this will not make a
  # defensive copy — if `dt` is already a data.table the function will mutate it
  # by reference when adding the `threshold` column. Callers that need to preserve
  # the original should pass `data.table::copy(dt)`.
  if (!data.table::is.data.table(dt)) {
    dt <- data.table::as.data.table(dt)
  }

  # Compute threshold per group. Use .SD[[1]] with .SDcols = metric so we can
  # refer to the metric column by name without non-standard evaluation.
  # `na.rm = TRUE` ensures missing metric values are ignored when possible.
  dt[,
    threshold := as.numeric(quantile(.SD[[1]], probs = probs, na.rm = TRUE)),
    by = group_cols,
    .SDcols = metric
  ]

  # Apply comparison using the requested operator. Comparisons that produce NA
  # (e.g. when threshold is NA) will not select the row.
  if (inclusive) {
    res <- dt[get(metric) >= threshold]
  } else {
    res <- dt[get(metric) > threshold]
  }

  # Optionally drop the helper `threshold` column before returning.
  if (!keep_threshold) {
    res[, threshold := NULL]
  }
  # Return a data.table (use [] to preserve printing semantics)
  res[]
}
