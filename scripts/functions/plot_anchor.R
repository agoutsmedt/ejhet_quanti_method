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
