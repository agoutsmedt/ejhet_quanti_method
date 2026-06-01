#' Heatmap of pairwise prototype distances (years x years)
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
