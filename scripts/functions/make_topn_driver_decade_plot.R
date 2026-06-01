#' Build top-n "new" drivers per decade plot (TF-IDF)
#'
#' @title Top-n "new" drivers per decade (TF-IDF)
#' @description Compute decade-level TF-IDF on driver tokens and plot the top-n
#'   tokens labelled as `"new"` for each decade. Returns a `ggplot` object or
#'   `NULL` when input is missing/empty or filtering removes all tokens.
#'
#' @param driver_tokens tibble/data.frame. Required. Token-level input (e.g.
#'   output of `extract_ngrams()`) with at minimum the columns:
#'   - `year_pair_start` (character or integer scalar identifying the year),
#'   - `type` (character/factor including `"new"`),
#'   - `projection_score` (numeric weight),
#'   - `token` (character). Rows with `NA` in these key columns are handled by
#'   downstream steps (coercion, filtering) and may be dropped.
#' @param top_n integer scalar. Number of top tokens to keep per decade
#'   (default `6L`). Must be positive; if fewer tokens exist for a decade only
#'   available tokens are returned.
#' @param min_corpus_tf integer scalar. Minimum corpus frequency threshold;
#'   tokens with `corpus_tf <= min_corpus_tf` are removed before selecting top
#'   tokens (default `20L`). Set to `0L` to disable frequency filtering.
#' @param title_suffix character scalar or `NULL`. Optional suffix appended to
#'   the plot title; `NULL` uses the default title.
#' @param out_file character scalar or `NULL`. Optional path to save the plot via
#'   `ggplot2::ggsave()`. If provided the plot file is written (overwriting an
#'   existing file with the same path). If `NULL` (default) the plot is not
#'   written to disk.
#'
#' @return A `ggplot` object showing top tokens per decade (flipped coordinates),
#'   or `NULL` if `driver_tokens` is `NULL`/empty or if filtering removes all
#'   tokens. The function returns the plot invisibly as the final value and has
#'   the side-effect of writing `out_file` when that argument is supplied.
#'
#' @details
#' At a high level the function:
#' - attaches a `decade` column by coercing `year_pair_start` to integer and
#'   grouping years into decades,
#' - computes TF-IDF per document defined by `c("decade", "type")` using
#'   `compute_tf_idf()` (which is expected to return `tf_idf` and `corpus_tf`),
#' - filters tokens by `corpus_tf > min_corpus_tf`,
#' - selects tokens with `type == "new"` and keeps the top `top_n` tokens per
#'   `decade` by `tf_idf`,
#' - builds a `ggplot2` chart using `ggrepel::geom_text_repel()` to label tokens.
#'
#' Implementation notes:
#' - Algorithmic sequence: validate input -> compute `decade` -> compute TF-IDF
#'   at `(decade, type)` level -> filter by corpus frequency ->
#'   `slice_max(tf_idf, n = top_n, with_ties = FALSE)` per decade ->
#'   build and optionally save plot.
#' - Assumptions and preconditions: `driver_tokens` contains the columns named
#'   above and `compute_tf_idf()` is available in the namespace and returns at
#'   least `tf_idf` and `corpus_tf`. `year_pair_start` must be coercible to
#'   integer; non-coercible values become `NA` and may be dropped.
#' - Edge-case handling: returns `NULL` with a warning if input is `NULL`/empty,
#'   or no tokens remain after corpus-frequency or `type == "new"` filtering.
#'   `slice_max(..., with_ties = FALSE)` forces a deterministic number of rows
#'   per group and may drop tied tokens arbitrarily.
#' - Trade-offs: uses `ggrepel` with moderate `force`/`max.iter` to reduce label
#'   overlap at the expense of plotting time. Decade aggregation reduces noise
#'   but may mask within-decade changes.
#' - Dependencies and side-effects: relies on `dplyr`, `ggplot2`, `ggrepel`,
#'   `cli`, and a working `compute_tf_idf()` implementation. If `out_file` is
#'   provided the function writes a file (overwrites without prompt). No global
#'   state is modified intentionally.
#'
#' @examples
#' # Normal case: small toy dataset (requires compute_tf_idf() in the env)
#' library(tibble)
#' toy <- tibble::tibble(
#'   year_pair_start = c("1995", "1998", "2001", "2003", "2010", "2012"),
#'   type = c("new", "new", "new", "new", "new", "new"),
#'   projection_score = c(1.0, 0.8, 0.9, 0.6, 0.7, 0.5),
#'   token = c("alpha", "beta", "alpha", "gamma", "delta", "epsilon")
#' )
#' if (rlang::is_function(compute_tf_idf)) {
#'   p <- make_topn_driver_decade_plot(toy, top_n = 2L, min_corpus_tf = 0L)
#'   p
#' }
#'
#' # Edge case: empty input returns NULL
#' make_topn_driver_decade_plot(tibble::tibble(), top_n = 2L)
#'
#' @keywords internal
#' @author Your Name
#' @seealso compute_tf_idf, make_topn_driver_plot, extract_ngrams
make_topn_driver_decade_plot <- function(
  driver_tokens,
  top_n = 6L,
  min_corpus_tf = 20L,
  title_suffix = NULL,
  out_file = NULL
) {
  if (rlang::is_null(driver_tokens) || nrow(driver_tokens) == 0L) {
    cli::cli_alert_warning(
      "make_topn_decade_plot: empty driver_tokens -> returning NULL"
    )
    return(NULL)
  }

  # Attach decade and compute decade-level TF-IDF
  decade_tokens <- driver_tokens |>
    dplyr::mutate(
      year_int = as.integer(year_pair_start),
      decade = (year_int %/% 10) * 10
    )

  tf_idf_decade <- compute_tf_idf(
    decade_tokens,
    document_col = c("decade", "type"),
    weight_col = "projection_score"
  ) |>
    dplyr::filter(corpus_tf > min_corpus_tf)

  if (nrow(tf_idf_decade) == 0L) {
    cli::cli_alert_warning(
      "make_topn_decade_plot: no tokens after corpus_tf filtering -> returning NULL"
    )
    return(NULL)
  }

  topn_new_per_decade <- tf_idf_decade |>
    dplyr::filter(type == "new") |>
    dplyr::group_by(decade) |>
    dplyr::slice_max(tf_idf, n = top_n, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::mutate(token = as.character(token))

  if (nrow(topn_new_per_decade) == 0L) {
    cli::cli_alert_warning(
      "make_topn_decade_plot: no 'new' tokens -> returning NULL"
    )
    return(NULL)
  }

  decade_seq <- seq(
    min(topn_new_per_decade$decade, na.rm = TRUE),
    max(topn_new_per_decade$decade, na.rm = TRUE),
    by = 10
  )

  title_main <- if (is.null(title_suffix)) {
    paste0("Top ", top_n, " 'new' drivers per decade (by TF-IDF)")
  } else {
    paste("Top", top_n, "'new' drivers per decade —", title_suffix)
  }

  # Order limits in descending order so the oldest decade (smallest number)
  # appears at the top after coord_flip().
  p <- ggplot2::ggplot(
    topn_new_per_decade,
    ggplot2::aes(x = factor(decade), y = tf_idf, group = token)
  ) +
    ggrepel::geom_text_repel(
      ggplot2::aes(label = token),
      hjust = 0,
      vjust = 0.5,
      show.legend = FALSE,
      na.rm = TRUE,
      force = 6,
      box.padding = 0.2,
      point.padding = 0.2,
      segment.size = 0,
      max.iter = 2000,
      seed = 42,
      size = 4
    ) +
    ggplot2::scale_x_discrete(
      limits = as.character(sort(
        unique(topn_new_per_decade$decade),
        decreasing = TRUE
      )),
      breaks = decade_seq
    ) +
    ggplot2::scale_y_continuous(
      expand = ggplot2::expansion(mult = c(0.01, 0))
    ) +
    ggplot2::coord_cartesian(clip = "off") +
    ggplot2::labs(title = title_main, x = NULL, y = "TF-IDF") +
    ggplot2::coord_flip() +
    ggplot2::theme_minimal(base_size = 16) +
    ggplot2::theme(
      legend.position = "none",
      plot.margin = ggplot2::margin(t = 5, r = 60, b = 5, l = 5, unit = "pt")
    )

  if (!is.null(out_file)) {
    ggplot2::ggsave(filename = out_file, plot = p, width = 12, height = 8)
  }

  p
}
