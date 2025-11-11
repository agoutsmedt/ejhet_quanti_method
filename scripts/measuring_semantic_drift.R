# The goal: using the representative vectors of sentence embeddings for each year to measure semantic drift over time
source(file.path("scripts", "paths_and_packages.R"))

# Load per-year representative vectors (list-column: embedding_by_year_centered)
representative_vectors <- read_feather(here::here(
  data_path,
  "representative_vectors_window_5.feather"
)) |>
  filter(between(year, 1950, 2010)) |>
  select(year, embedding_by_year) |>
  unnest(embedding_by_year) |>
  mutate(dimension = row_number(), .by = year)

# Transform 3 columns table to matrix with xtabs
mat <- xtabs(
  formula = embedding_by_year ~ year + dimension,
  data = representative_vectors
)
mat <- as.matrix(mat)

# ---- usage ----
drift <- consecutive_proto_drift(mat) # year-to-year PRT drift


# Visualisations for year-to-year proto-distance (PRT) drift-------------
#'
#'
#' Functions expect a tibble `drift` with columns: year (int or chr), year_prev, prt (numeric)
#' and/or a square distance matrix with dimnames as years.
#' Uses ggplot2 for plotting and zoo for simple rolling means.
#' ...existing code...

#' Rolling mean (moving average) of PRT
#' @param drift tibble with `year` and `prt`
#' @param window integer window size (years) for rolling mean; must be >= 1
#' @return ggplot object
plot_prt_rolling <- function(drift, smooth = FALSE, span = 0.25, window = 5L) {
  if (window < 1L) {
    cli::cli_alert_warning(
      "No rollling applied; equivalent to year-to-year plot."
    )
  }
  d <- drift |>
    arrange(year) |>
    mutate(
      prt_roll = zoo::rollapply(
        prt,
        width = window,
        FUN = function(x) mean(x, na.rm = TRUE),
        align = "right",
        fill = NA_real_
      )
    )
  p <- ggplot(d, aes(x = year)) +
    geom_line(aes(y = prt_roll), color = "darkgreen", size = 0.8) +
    geom_point(aes(y = prt), alpha = 0.4, size = 0.8) +
    labs(
      x = NULL,
      y = glue::glue("Rolling mean PRT (window = {window})"),
      title = "Rolling mean of year-to-year PRT"
    ) +
    theme_minimal()

  if (smooth) {
    p <- p +
      geom_smooth(
        aes(y = prt),
        method = "loess",
        span = span,
        se = FALSE,
        color = "darkred"
      )
  }

  p
}

#' Cumulative drift over time (running sum of PRT)
#' @param drift tibble with `year` and `prt`
#' @return ggplot object
plot_cumulative_drift <- function(drift) {
  d <- drift |>
    arrange(year) |>
    mutate(cum_prt = cumsum(replace_na(prt, 0)))
  ggplot(d, aes(x = year, y = cum_prt)) +
    geom_line(color = "purple", size = 0.8) +
    geom_point(size = 0.8) +
    labs(
      x = NULL,
      y = "Cumulative PRT",
      title = "Cumulative semantic drift (sum of yearly PRT)"
    ) +
    theme_minimal()
}

#' Distribution of PRT values
#' @param drift tibble with `prt`
#' @return ggplot object
plot_prt_distribution <- function(drift, bins = 30) {
  ggplot(drift, aes(x = prt)) +
    geom_histogram(
      aes(y = ..density..),
      bins = bins,
      fill = "gray70",
      color = "white"
    ) +
    geom_density(color = "black", size = 0.6) +
    labs(
      x = "PRT",
      y = "Density",
      title = "Distribution of year-to-year PRT values"
    ) +
    theme_minimal()
}

plot_prt_rolling(drift, smooth = FALSE, window = 10L)
plot_cumulative_drift(drift)
plot_prt_distribution(drift, bins = 30)

# Exploring representative vectors similarity ------------
#' Heatmap of the full distance matrix (years x years)
#' @param distance_matrix square numeric matrix with dimnames = years
#' @return ggplot object
plot_distance_heatmap <- function(distance_matrix) {
  if (is.null(dimnames(distance_matrix))) {
    cli::cli_abort("distance_matrix must have dimnames (years).")
  }

  # prepare data frame for plotting
  df <- as.data.frame(distance_matrix) |>
    tibble::rownames_to_column(var = "year") |>
    tidyr::pivot_longer(-year, names_to = "year2", values_to = "dist") |>
    mutate(
      year = factor(year, levels = unique(year)),
      year2 = factor(year2, levels = unique(year2))
    )

  # compute decade breaks from numeric year rownames (fall back to character if needed)
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

  p <- ggplot(df, aes(x = year, y = year2, fill = dist)) +
    geom_raster() +
    scale_fill_scico(
      palette = "lipari",
      na.value = "grey90",
      direction = -1,
      name = "PRT\n(1 - cosine)"
    ) +
    coord_fixed(expand = FALSE) +
    labs(
      x = NULL,
      y = NULL,
      title = "Heatmap of pairwise proto-distances"
    ) +
    theme_minimal(base_size = 18) +
    theme(
      axis.text.x = element_text(angle = 90, vjust = 0.5, hjust = 1)
    ) +
    scale_x_discrete(breaks = decade_breaks, labels = decade_breaks) +
    scale_y_discrete(breaks = decade_breaks, labels = decade_breaks)

  p
}

dm <- proto_distance_matrix(mat)
plot_distance_heatmap(dm)
