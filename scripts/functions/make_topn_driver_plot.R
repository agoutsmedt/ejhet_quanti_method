#' Top-n "new" drivers per year plot (TF-IDF)
#'
#' @title Top-n "new" drivers per year (TF-IDF)
#' @description Compute year-level TF-IDF on driver tokens and plot the top-n tokens
#'   labelled as `"new"` for each year. Returns a ggplot object (or `NULL` if no
#'   data after filtering).
#'
#' @param driver_tokens tibble/data.frame. Required. Output of `extract_ngrams()` or
#'   equivalent with at least the columns: `year_pair_start` (character or integer
#'   identifying the year), `type` (factor/char with values including `"new"`),
#'   `projection_score` (numeric weight), and `token` (character token). Rows with
#'   `NA` in these key columns are removed by downstream summarisation where
#'   appropriate.
#' @param top_n integer scalar. Number of top tokens to keep per year (default
#'   `2L`). Must be positive. If fewer tokens exist for a year, only available
#'   tokens are returned.
#' @param min_corpus_tf integer scalar. Minimum corpus frequency threshold; tokens
#'   with `corpus_tf <= min_corpus_tf` are dropped before selecting top tokens
#'   (default `20L`). Use `0L` to disable filtering.
#' @param title_suffix character scalar. Optional suffix appended to the plot
#'   title. `NULL` uses the default title.
#' @param out_file character scalar or `NULL`. Optional path to save the plot via
#'   `ggplot2::ggsave()`. If `NULL` (default) the plot is not saved.
#'
#' @return A `ggplot` object showing top tokens per year (flipped coordinates),
#'   or `NULL` if input is `NULL`, empty, or no tokens remain after filtering.
#'   The function installs no side-effects except optionally writing the file
#'   at `out_file`.
#'
#' @details
#' This function:
#' - computes TF-IDF per document defined by `c("year_pair_start", "type")`
#'   using `compute_tf_idf()` (expected to return `tf_idf` and `corpus_tf` columns),
#' - filters tokens by `corpus_tf > min_corpus_tf`,
#' - selects tokens with `type == "new"`, and then takes the top `top_n`
#'   tokens per `year_pair_start` by `tf_idf`,
#' - builds a ggplot with `ggrepel::geom_text_repel()` to label tokens on the
#'   y-axis (years).
#'
#' Implementation notes:
#' - Algorithmic steps: validate input -> compute TF-IDF -> corpus frequency
#'   filtering -> per-year `slice_max(tf_idf, n = top_n)` -> build plot.
#' - Assumptions: `driver_tokens` contains the columns listed above and
#'   `compute_tf_idf()` returns `tf_idf` and `corpus_tf`. Year labels are
#'   coercible to integer. If `compute_tf_idf()` is not available the function
#'   will error.
#' - Edge cases: returns `NULL` with a warning if `driver_tokens` is `NULL`/empty,
#'   or if filtering removes all tokens. `slice_max(..., with_ties = FALSE)`
#'   breaks ties arbitrarily to keep exactly `top_n` rows per year.
#' - Trade-offs: uses `ggrepel` with larger `force` and `max.iter` to reduce
#'   overlap at the cost of slightly longer plotting time.
#' - Dependencies: `dplyr`, `ggplot2`, `ggrepel`, `rlang`, `cli` and a working
#'   `compute_tf_idf()` implementation. No global state is modified.
#'
#' @examples
#' # Normal case: small toy dataset
#' library(tibble)
#' toy <- tibble::tibble(
#'   year_pair_start = c("2000", "2000", "2001", "2001"),
#'   type = c("new", "new", "new", "new"),
#'   projection_score = c(1.0, 0.5, 0.9, 0.6),
#'   token = c("alpha", "beta", "alpha", "gamma")
#' )
#' # compute_tf_idf() must be available in the environment for the example to run
#' if (rlang::is_function(compute_tf_idf)) {
#'   p <- make_topn_driver_plot(toy, top_n = 2L, min_corpus_tf = 0L)
#'   p
#' }
#'
#' # Edge case: empty input returns NULL
#' make_topn_driver_plot(tibble::tibble(), top_n = 2L)
#'
#' @keywords internal
#' @author Your Name
#' @seealso compute_tf_idf, extract_ngrams
make_topn_driver_plot <- function(
  driver_tokens,
  top_n = 2L,
  min_corpus_tf = 20L,
  title_suffix = NULL,
  out_file = NULL
) {
  # Quick validation: empty input -> nothing to plot
  if (rlang::is_null(driver_tokens) || nrow(driver_tokens) == 0L) {
    cli::cli_alert_warning(
      "make_top2_new_plot: empty driver_tokens -> returning NULL"
    )
    return(NULL)
  }

  # Compute TF-IDF at the (year, type) document level and filter low-frequency tokens.
  # `compute_tf_idf()` is expected to return at least: token, tf_idf, corpus_tf, type, year_pair_start.
  tf_idf_drivers <- compute_tf_idf(
    driver_tokens,
    document_col = c("year_pair_start", "type"),
    weight_col = "projection_score"
  ) |>
    dplyr::filter(corpus_tf > min_corpus_tf)

  # If nothing remains after corpus-level filtering, return NULL with a warning.
  if (nrow(tf_idf_drivers) == 0L) {
    cli::cli_alert_warning(
      "make_top2_new_plot: no tokens after corpus_tf filtering -> returning NULL"
    )
    return(NULL)
  }

  # Select "new" tokens and keep the top `top_n` by tf_idf for each year.
  # `with_ties = FALSE` ensures deterministic number of rows per group but may
  # drop some tied tokens.
  top2_new_per_year <- tf_idf_drivers |>
    dplyr::filter(type == "new") |>
    dplyr::group_by(year_pair_start) |>
    dplyr::slice_max(tf_idf, n = top_n, with_ties = FALSE) |>
    dplyr::ungroup() |>
    # Convert year to integer for axis scaling and token to character for plotting.
    dplyr::mutate(
      year = as.integer(year_pair_start),
      token = as.character(token)
    )

  # Nothing to plot if there are no 'new' tokens
  if (nrow(top2_new_per_year) == 0L) {
    cli::cli_alert_warning(
      "make_top2_new_plot: no 'new' tokens -> returning NULL"
    )
    return(NULL)
  }

  # Build a sequence of decade breaks for the x-axis labels (used as breaks after
  # coercing years to factors). Using min/max of available years is robust to
  # incomplete ranges.
  yr_seq <- seq(
    min(top2_new_per_year$year, na.rm = TRUE),
    max(top2_new_per_year$year, na.rm = TRUE),
    by = 10
  )

  # Title: allow optional suffix
  title_main <- if (is.null(title_suffix)) {
    "Top 2 'new' drivers per year (by TF-IDF)"
  } else {
    paste("Top 2 'new' drivers per year —", title_suffix)
  }

  # Compose the ggplot: use factor(year) so the x axis shows discrete years,
  # geom_text_repel places token labels, coord_flip produces horizontal labels.
  p <- ggplot2::ggplot(
    top2_new_per_year,
    ggplot2::aes(x = factor(year), y = tf_idf, group = token)
  ) +
    ggrepel::geom_text_repel(
      ggplot2::aes(label = token),
      hjust = 0,
      vjust = 0.5,
      show.legend = FALSE,
      na.rm = TRUE,
      direction = "x", # prioritise horizontal repulsion to reduce overlap along year axis
      force = 12, # stronger force helps separate many labels
      box.padding = 0.2,
      point.padding = 0.2,
      segment.size = 0,
      max.iter = 5000, # increase iterations for complex layouts
      seed = 42,
      size = 3
    ) +
    ggplot2::scale_x_discrete(
      limits = as.character(sort(
        unique(top2_new_per_year$year),
        decreasing = TRUE
      )),
      breaks = yr_seq
    ) +
    ggplot2::scale_y_continuous(
      expand = ggplot2::expansion(mult = c(0.01, 0))
    ) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(title = title_main, x = NULL, y = "TF-IDF") +
    ggplot2::coord_flip() +
    ggplot2::theme_minimal(base_size = 18) +
    ggplot2::theme(
      legend.position = "none",
      plot.margin = ggplot2::margin(t = 5, r = 60, b = 5, l = 5, unit = "pt")
    )

  # Optionally persist the plot to disk. We do not return the path to keep the
  # function focused on producing the plot object.
  if (!is.null(out_file)) {
    ggplot2::ggsave(filename = out_file, plot = p, width = 10, height = 12)
  }

  # Return the ggplot object for further composition or printing.
  p
}
