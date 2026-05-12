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
