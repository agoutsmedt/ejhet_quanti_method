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
