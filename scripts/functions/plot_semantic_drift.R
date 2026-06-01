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
