#: Calculating semantic drift metrics-----------------------
#' Normalize rows of a numeric matrix-like object to unit Euclidean length
#'
#' @title Row-wise L2 normalization of a matrix
#' @description
#' Scale each row of a numeric matrix (or matrix-like object) to have unit
#' Euclidean (L2) norm. Rows with zero length are removed because they cannot be
#' rescaled.
#'
#' @param mat Numeric matrix-like object. Accepts a numeric `matrix`, a
#'   `data.frame` of numeric columns (will be coerced to a matrix), or other
#'   matrix-like objects that inherit from the `"mat"` class. Rows represent
#'   vectors to be normalized. Input must be finite and numeric; rows containing
#'   `NA` or non-numeric columns will cause an error.
#'
#' @return A numeric matrix with the same number of columns as `mat` where each
#'   returned row has Euclidean norm 1. Row names from the input are preserved
#'   for the kept rows. Rows whose norm is exactly (or numerically) zero are
#'   dropped; if no rows remain the function returns a numeric matrix with
#'   zero rows and the original number of columns.
#'
#' @details
#' This helper performs a standard row-wise L2 normalization used before
#' computing cosine similarities. It has no side effects and does not modify
#' global state.
#'
#' Implementation notes:
#' - Coerce `data.frame` inputs to a numeric matrix to allow uniform vectorized
#'   operations.
#' - Validate that the input is numeric. Non-numeric inputs produce an error via
#'   `cli::cli_abort()`.
#' - Compute row norms with `sqrt(rowSums(mat * mat))` and identify rows with
#'   norm > 0. A strict `> 0` test is used (rather than `!= 0`) to avoid
#'   floating-point equality issues.
#' - Drop zero-length rows and divide each remaining row by its corresponding
#'   norm. Division uses column-wise recycling (R's native recycling rules) so
#'   `mat[keep, , drop = FALSE] / nrms[keep]` efficiently scales each row by
#'   its scalar norm.
#' - The function does not attempt to impute or tolerate `NA`s; rows containing
#'   `NA` will cause validation to fail.
#'
#' Edge cases and failure modes:
#' - If `mat` is not numeric an informative error is raised.
#' - If all rows have zero norm, the returned object is a zero-row numeric
#'   matrix with the same number of columns.
#' - Rows with `NA` values produce an error (no silent coercion).
#'
#' Alternatives and trade-offs:
#' - This implementation favors clarity and vectorized base R arithmetic over
#'   per-row loops for speed. For extremely large matrices, specialized C-backed
#'   implementations or BLAS-accelerated libraries may be faster.
#'
#' @implementation
#' Vectorized algorithm:
#' 1. Coerce `data.frame` -> `matrix`.
#' 2. Validate numeric type.
#' 3. Compute per-row L2 norms.
#' 4. Keep rows with norm > 0 and divide each row by its norm using recycling.
#'
#' @seealso `rowSums()`, base `scale()` for column scaling
#' @examples
#' # normal case: matrix input
#' m <- matrix(c(3, 4, 0, 0, 0, 2), nrow = 3, byrow = TRUE)
#' row_normalize(m)
#'
#' # data.frame input coerced to matrix
#' df <- data.frame(x = c(3, 0), y = c(4, 0))
#' row_normalize(df)
#'
#' # edge case: rows of zeros are removed -> returns a 0-row matrix
#' m_zero <- matrix(c(0, 0, 0, 0), nrow = 2)
#' row_normalize(m_zero)
#'
#' @keywords internal
#' @author Your Name
row_normalize <- function(mat) {
  # Accept data.frames by coercing to a matrix to enable vectorized ops
  if (is.data.frame(mat)) {
    mat <- as.matrix(mat)
  }

  # Ensure we have a matrix-like numeric object.
  # Allow objects that explicitly inherit from a "mat" class as a convenience.
  if (!is.matrix(mat) && !inherits(mat, "mat")) {
    cli::cli_abort("`mat` must be a mat-like numeric object")
  }
  if (!is.numeric(mat)) {
    cli::cli_abort("`mat` must be numeric")
  }

  # Compute L2 norms for each row: sqrt(sum(row^2)).
  nrms <- sqrt(rowSums(mat * mat))

  # Keep rows whose norm is strictly positive (guards against floating point
  # near-zero values and prevents division-by-zero).
  keep <- nrms > 0

  # Subset kept rows and divide each row by its scalar norm.
  # Division by a vector of length nrows uses R's column-wise recycling so each
  # row i is divided by nrms[i], which is efficient and vectorized.
  mat <- mat[keep, , drop = FALSE] / nrms[keep]

  mat
}

#' Compute a pairwise proto-distance matrix (1 - cosine similarity) for yearly prototypes
#'
#' @title Pairwise proto-distance matrix from yearly prototype vectors
#' @description
#' Compute a square matrix of proto-distances between yearly representative
#' vectors using cosine similarity. The function expects `mat` to have rownames
#' that represent integer-like years (e.g. `"1900"`). It normalizes rows to
#' unit length, computes pairwise cosine similarities, converts them to
#' distances via `1 - cosine`, and sets the diagonal to `NA` to exclude
#' trivial self-distance.
#'
#' @param mat Numeric matrix-like object with rows representing years and
#'   columns representing embedding dimensions. Rows must have names corresponding
#'   to integer-like years (character rownames such as `"1900"`). `NA` values
#'   are not allowed; if rows contain only zeros they are removed during
#'   normalization (see details).
#'
#' @return A numeric square matrix (n_kept x n_kept) of proto-distances with
#'   dimnames equal to the kept row names (years). Values are `1 - cosine`,
#'   which lies in the interval [-1, 2] in general; for typical unit-normalized
#'   embeddings distances fall in [0, 2]. The diagonal entries are `NA`.
#'   If no rows remain after normalization the function returns a 0 x 0 numeric
#'   matrix with `dimnames = list(character(0), character(0))`.
#'
#' @details
#' This function is designed to measure pairwise differences between yearly
#' prototype vectors (e.g. sentence-embedding centroids). It:
#' - Requires row names that encode integer-like years; it aborts if rownames
#'   are missing or not integer-like.
#' - Sorts rows by year to ensure deterministic ordering.
#' - Row-normalizes vectors with `row_normalize()` (which drops exact zero
#'   rows). Year labels for removed rows are not present in the output.
#' - Computes cosine similarities via matrix multiplication and converts them to
#'   distances using `1 - cosine`.
#'
#' Implementation notes:
#' - Algorithmic steps:
#'   1. Validate that `mat` has rownames and that they parse as integer-like years.
#'   2. Order rows by year and coerce to deterministic ordering.
#'   3. Row-normalize with `row_normalize()`; this may drop rows that are exact
#'      zero vectors (they cannot be scaled).
#'   4. Compute the dense cosine similarity matrix via `mat_norm %*% t(mat_norm)`.
#'   5. Convert to distances `1 - cosine` and set the diagonal to `NA`.
#' - Assumptions and preconditions: `mat` is numeric, finite, and rownames are
#'   integer-like year labels. Rows containing `NA` will cause the underlying
#'   `row_normalize()` validation to fail.
#' - Edge cases & failure modes:
#'   * If rownames are missing or not integer-like, the function aborts with an
#'     informative error.
#'   * If `row_normalize()` removes all rows, the result is a 0x0 numeric
#'     matrix (no error).
#'   * If some rows are zero vectors, they are simply dropped and corresponding
#'     years are absent from the returned matrix.
#' - Trade-offs: The implementation uses dense matrix multiplication which is
#'   simple and efficient for moderate sizes but uses O(n^2) memory and time;
#'   for very large year counts a block-wise or approximate approach may be
#'   preferable.
#' - Dependencies: calls `row_normalize()` (local helper) and `cli::cli_abort()`.
#'
#' @implementation
#' Vectorized, BLAS-friendly approach:
#' - Normalise rows (L2) with `row_normalize()` to produce unit vectors.
#' - Compute all pairwise cosines with a single matrix product.
#' - Convert to distances and mask the diagonal with `NA`.
#'
#' @examples
#' # Normal case: two yearly prototype vectors
#' m <- matrix(c(1, 0, 0, 1), nrow = 2, byrow = TRUE)
#' rownames(m) <- c("1900", "1901")
#' proto_distance_matrix(m)
#'
#' # Edge case: zero rows are removed by normalization -> fewer rows in output
#' m2 <- matrix(c(0, 0, 1, 0), nrow = 2, byrow = TRUE)
#' rownames(m2) <- c("1900", "1901")
#' proto_distance_matrix(m2)
#'
#' @seealso row_normalize(), consecutive_proto_drift()
#' @keywords internal
#' @author Your Name
#' @family proto-distance functions
proto_distance_matrix <- function(mat) {
  # Require row names that represent years
  if (is.null(rownames(mat))) {
    cli::cli_abort("Input matrix must have rownames representing years.")
  }

  # Try to interpret row names as integer-like years; abort if parsing fails.
  yrs <- suppressWarnings(as.integer(rownames(mat)))
  if (any(is.na(yrs))) {
    cli::cli_abort("Row names must be integer-like years (e.g. '1900').")
  }

  # Ensure rows are sorted by year for deterministic output
  ord <- order(yrs)
  mat <- mat[ord, , drop = FALSE]
  yrs <- yrs[ord]

  # Normalize rows to unit length; this may drop exact-zero rows.
  # row_normalize() preserves rownames for kept rows.
  mat_norm <- row_normalize(mat)

  # Capture the (character) row names of the kept rows after normalization.
  # Using character rownames is safe for dimnames assignment.
  yrs_kept <- rownames(mat_norm)

  # Compute cosine similarity via a single matrix multiplication.
  # For normalized rows, (mat_norm %*% t(mat_norm))_ij == cosine(vec_i, vec_j).
  cosine_matrix <- as.matrix(mat_norm %*% t(mat_norm))

  # Convert similarity to distance (1 - cosine). This yields values typically
  # in [0, 2] (0 identical, 2 opposite).
  distance_matrix <- 1 - cosine_matrix

  # Mask self-distance as NA since self-comparisons are not informative for drift.
  diag(distance_matrix) <- NA_real_

  # Attach dimnames corresponding to the kept years (may be character).
  dimnames(distance_matrix) <- list(yrs_kept, yrs_kept)

  distance_matrix
}

#' Consecutive year-to-year proto-distance (PRT) drift
#'
#' @title Consecutive proto-distance (year-to-year) drift
#' @description
#' Compute year-to-year proto-distance (PRT) values from a matrix of yearly
#' prototype vectors. The function delegates validation and normalization to
#' `proto_distance_matrix()` and then extracts the off-diagonal elements that
#' correspond to consecutive-year distances (row i vs row i-1).
#'
#' @param mat Numeric matrix-like object with rows = years and columns =
#'   embedding dimensions. Rows must have names that represent years (e.g.
#'   `"1900"`). Accepts a numeric `matrix` or other matrix-like objects; `NA`
#'   values are not allowed (validation happens in `proto_distance_matrix()`).
#'
#' @return A tibble with three columns:
#'   - `year`: integer (if row names parse as integer-like years) or character
#'     (if row names are not integer-like) giving the later year in each
#'     consecutive pair. For the zero-row edge case this is `integer(0)`.
#'   - `year_prev`: same type as `year`, representing the previous year.
#'   - `prt`: numeric vector of proto-distances (values are `1 - cosine`).
#'   If no consecutive pairs exist (fewer than 2 rows after normalization)
#'   the function returns a zero-row tibble with column types shown above.
#'
#' @details
#' The function computes year-to-year drift by:
#' - Calling `proto_distance_matrix(mat)` to validate row names, sort rows by
#'   year, normalize vectors, and compute a full pairwise distance matrix
#'   (1 - cosine similarity). That helper may drop exact-zero rows.
#' - Extracting the (i, i-1) off-diagonal entries from the distance matrix
#'   which represent the distance from each year to the previous year.
#'
#' Implementation notes:
#' - Steps:
#'   1. Ensure `mat` has rownames; `proto_distance_matrix()` will error if not.
#'   2. Compute the full square distance matrix (may have fewer rows than the
#'      input if zero vectors were removed).
#'   3. If fewer than 2 rows remain, return an empty tibble with predictable
#'      column types.
#'   4. Parse row names as integers when possible; otherwise warn and keep
#'      character labels.
#'   5. Extract consecutive-year distances using a vectorized index `cbind()`
#'      on the matrix (fast and avoids explicit loops).
#' - Assumptions and preconditions:
#'   * `mat` is numeric and has row names meaningful as year labels.
#'   * `proto_distance_matrix()` enforces that rows do not contain `NA`s.
#' - Edge cases & failure modes:
#'   * Missing row names -> error (handled by this function / helper).
#'   * Non-integer row names -> function returns character `year`/`year_prev`
#'     and emits a warning.
#'   * Exact-zero prototype rows are removed by normalization; corresponding
#'     years will be absent from the output.
#'   * If fewer than two rows remain after normalization, an empty tibble is
#'     returned instead of an error.
#' - Trade-offs: extraction of consecutive entries uses dense matrix memory
#'   returned by `proto_distance_matrix()`; for extremely large year counts a
#'   streaming or block approach could be used.
#' - Dependencies: calls `proto_distance_matrix()` and `cli::cli_warn()` /
#'   `cli::cli_abort()`; returns a tibble (requires `tibble`).
#'
#' @implementation
#' Vectorized approach:
#' - Build full pairwise distance matrix via `proto_distance_matrix()`.
#' - Use a single `cbind()` index to extract consecutive off-diagonal entries
#'   (i, i-1) into a numeric vector.
#'
#' @examples
#' # Normal case: two yearly prototype vectors
#' m <- matrix(c(1, 0, 0, 1), nrow = 2, byrow = TRUE)
#' rownames(m) <- c("1900", "1901")
#' consecutive_proto_drift(m)
#'
#' # Edge case: only one year remains -> zero-row tibble
#' m_single <- matrix(c(1, 2), nrow = 1)
#' rownames(m_single) <- "1900"
#' consecutive_proto_drift(m_single)
#'
#' # Non-integer row names -> warning and character year columns
#' m_chr <- matrix(c(1, 0, 0, 1), nrow = 2, byrow = TRUE)
#' rownames(m_chr) <- c("a", "b")
#' consecutive_proto_drift(m_chr)
#'
#' @seealso proto_distance_matrix(), row_normalize()
#' @keywords internal
#' @family proto-distance functions
#' @author Your Name
consecutive_proto_drift <- function(mat) {
  # Ensure rownames exist; proto_distance_matrix() also checks this but we give
  # an early, specific error message for this precondition.
  if (is.null(rownames(mat))) {
    cli::cli_abort("Input must have rownames representing years.")
  }

  # Compute the full pairwise distance matrix (validates, sorts, normalizes).
  distance_matrix <- proto_distance_matrix(mat)

  # Keep the (character) row names of the (possibly reduced) distance matrix.
  yrs_chr <- rownames(distance_matrix)
  n <- nrow(distance_matrix)

  # If fewer than two rows remain there are no consecutive pairs -> return a
  # predictable zero-row tibble (use integer(0) for year cols for consistency).
  if (n < 2) {
    return(tibble::tibble(
      year = integer(0),
      year_prev = integer(0),
      prt = numeric(0)
    ))
  }

  # Try to interpret the retained rownames as integer-like years. We suppress
  # warnings from as.integer() and handle parse failure with a user warning.
  yrs_int <- suppressWarnings(as.integer(yrs_chr))
  if (any(is.na(yrs_int))) {
    # Non-integer labels: warn user and keep character year labels in output.
    cli::cli_warn(
      "Row names are not integer-like years; returning year labels as character."
    )
    year_col <- yrs_chr[-1] # later year in each consecutive pair
    year_prev_col <- yrs_chr[-n] # previous year for each pair
  } else {
    # Integer-like labels: return integer columns for years.
    year_col <- yrs_int[-1]
    year_prev_col <- yrs_int[-n]
  }

  # Vectorized extraction of consecutive off-diagonal entries:
  # For n rows, consecutive pairs correspond to (2,1), (3,2), ..., (n, n-1).
  # Build index matrix with cbind(row_indices, col_indices) and subset the matrix.
  idx <- seq_len(n - 1)
  prt_vals <- as.numeric(distance_matrix[cbind(idx + 1, idx)])

  # Return a tibble with the later year, previous year, and the proto-distance.
  tibble::tibble(
    year = year_col,
    year_prev = year_prev_col,
    prt = prt_vals
  )
}

#: Method for text analysis-------------------------

#' Compute Term Frequency-Inverse Document Frequency (TF-IDF)
#'
#' This function computes the Term Frequency (TF), Inverse Document Frequency (IDF),
#' and TF-IDF score for tokens within documents in a data.table.
#'
#' @param dt A `data.table` containing at least two columns: one for tokens (e.g., words)
#' and one for documents (e.g., time windows, article IDs, etc.).
#' @param token_col A string indicating the name of the column containing tokens. Default is `"token"`.
#' @param document_col A string indicating the name of the column containing document identifiers. Default is `"document"`.
#'
#' @return A `data.table` with one row per unique token-document pair, including the following columns:
#' \describe{
#'   \item{absolute_tf}{Total frequency of each token across all documents.}
#'   \item{nb_word}{Total number of tokens in each document.}
#'   \item{tf}{Term frequency of each token within each document.}
#'   \item{df}{Document frequency — the number of documents in which each token appears.}
#'   \item{idf}{Inverse document frequency: \code{log(total_docs / df)}.}
#'   \item{tf_idf}{TF-IDF score: \code{tf * idf}.}
#' }
#'
#' @examples
#' library(data.table)
#' dt <- data.table(doc = c(1, 1, 2, 2, 2, 3), word = c("apple", "banana", "apple", "apple", "kiwi", "banana"))
#' result <- compute_tf_idf(dt, token_col = "word", document_col = "doc")
#' print(result)
#'
#' @import data.table
#' @export
compute_tf_idf <- function(dt, token_col = "token", document_col = "document") {
  # Make a copy to avoid modifying in-place
  dt <- copy(dt)

  # Convert column names to symbols
  token_sym <- as.name(token_col)
  time_sym <- as.name(document_col)

  # Standardize names temporarily for easier handling
  setnames(dt, c(document_col, token_col), c("document", "token"))

  # Calculate absolute term frequency
  dt[, absolute_tf := .N, by = token]
  dt[, nb_word := .N, by = document]
  dt[, tf := .N / nb_word, by = .(document, token)]

  # Make unique for TF-IDF calculation
  tokens_count <- unique(dt)

  # TF table
  tf_dt <- dt[, .N, by = .(document, token)]
  setnames(tf_dt, "N", "tf")

  # DF table
  df_dt <- tokens_count[, .N, by = token]
  setnames(df_dt, "N", "df")

  # Merge and compute IDF and TF-IDF
  total_docs <- uniqueN(tokens_count$document)
  tokens_count <- merge(tokens_count, df_dt, by = "token", all.x = TRUE)
  tokens_count[, idf := log(total_docs / df)]
  tokens_count[, tf_idf := tf * idf]

  # Rename back to original column names
  setnames(tokens_count, c("document", "token"), c(document_col, token_col))

  return(tokens_count[])
}

#: Function for Shiny App-------------------------
#' Launch an Interactive Shiny App to Explore Network Graphs
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' This function launches an interactive Shiny application to explore one or several
#' network graphs (as `tbl_graph` or list of `tbl_graph`). If a list is passed, each
#' graph should be named according to its time window (e.g., "2010-2012"), enabling dynamic selection.
#'
#' The interface supports cluster exploration, tooltip interactivity, layout computation, and node metadata inspection.
#'
#' @param graph_tbl A `tbl_graph` object or a **named list of `tbl_graph`**, each representing a time window.
#' @param cluster_id Column name in the node data identifying clusters.
#' @param cluster_information Character vector of node metadata columns to show in the table.
#' @param cluster_tooltip Optional. Tooltip shown when hovering over cluster labels.
#' @param node_id Column name identifying node IDs.
#' @param node_tooltip Optional. Tooltip for node-level interaction.
#' @param node_size Optional. Column name used to scale node size.
#' @param color Optional. Column used to color nodes. If `NULL`, colors are generated.
#' @param layout Character. Layout algorithm passed to `networkflow::layout_networks()` (e.g., `"kk"`, `"fr"`).
#'
#' @return A Shiny app interface to interact with the network graph(s).
#' @export
launch_network_app <- function(
  graph_tbl,
  cluster_id,
  cluster_information,
  cluster_tooltip = NULL,
  node_id,
  cluster_sentences,
  top_references,
  top_references_without_id,
  cluster_origins,
  cluster_destinies,
  tf_idf_data,
  node_tooltip = NULL,
  node_size = NULL,
  color = NULL,
  layout = "kk"
) {
  stopifnot(
    requireNamespace("shiny"),
    requireNamespace("ggiraph"),
    requireNamespace("ggplot2"),
    requireNamespace("DT"),
    requireNamespace("dplyr"),
    requireNamespace("ggraph"),
    requireNamespace("rlang"),
    requireNamespace("purrr"),
    requireNamespace("shinycssloaders"),
    requireNamespace("tidygraph"),
    requireNamespace("networkflow"),
    requireNamespace("cli"),
    requireNamespace("htmltools"),
    requireNamespace("jsonlite") # add
  )

  # Validate input
  is_list_graph <- is.list(graph_tbl) &&
    all(purrr::map_lgl(graph_tbl, ~ inherits(.x, "tbl_graph")))
  if (is_list_graph && is.null(names(graph_tbl))) {
    cli::cli_abort(
      "The list of graphs must be named, where names correspond to time windows (e.g., '2010-2012')."
    )
  }

  if (!is.null(layout)) {
    cli::cli_alert_info(
      "Computing layout with {.fn networkflow::layout_networks} using layout = '{layout}'"
    )
    graph_tbl <- networkflow::layout_networks(
      graphs = graph_tbl,
      node_id = node_id,
      layout = layout
    )
  }

  if (is.null(color)) {
    cli::cli_alert_info(
      "Generating node colors via {.fn networkflow::color_networks}"
    )
    graph_tbl <- networkflow::color_networks(
      graphs = graph_tbl,
      column_to_color = cluster_id,
      unique_color_across_list = FALSE
    )
    color <- "color"
  }

  # Symbols
  color_sym <- rlang::sym(color)
  cluster_sym <- rlang::sym(cluster_id)
  id_sym <- rlang::sym(node_id)
  tooltip_sym <- if (!is.null(node_tooltip)) rlang::sym(node_tooltip) else NULL
  id_chr <- rlang::as_name(id_sym)
  cluster_chr <- rlang::as_name(cluster_sym)

  # UI
  ui <- shiny::fluidPage(
    shiny::titlePanel("Network Explorer"),
    shiny::sidebarLayout(
      sidebarPanel = shiny::sidebarPanel(
        width = 3,
        if (is_list_graph) {
          shiny::selectInput(
            "selected_graph",
            "Select Time Window:",
            choices = names(graph_tbl),
            selected = names(graph_tbl)[1]
          )
        },
        #       shiny::sliderInput("min_edge_width", "Min Edge Width:", min = 0.1, max = 10, value = 1, step = 0.1),
        #      shiny::sliderInput("max_edge_width", "Max Edge Width:", min = 0.1, max = 10, value = 3, step = 0.1),
        shiny::sliderInput(
          "min_node_size",
          "Min Node Size:",
          min = 0.1,
          max = 10,
          value = 1,
          step = 0.1
        ),
        shiny::sliderInput(
          "max_node_size",
          "Max Node Size:",
          min = 0.1,
          max = 10,
          value = 10,
          step = 0.1
        ),
        shiny::sliderInput(
          "label_size",
          "Label size",
          min = 0.5,
          max = 5,
          value = 2.2,
          step = 0.1
        ),

        # shiny::hr(),
        # shiny::h5("Cluster composition"),
        DT::DTOutput("cluster_share")
      ),
      mainPanel = shiny::mainPanel(
        shiny::div(
          style = "border: 1px solid #ccc; padding: 10px; border-radius: 5px;",
          shinycssloaders::withSpinner(
            ggiraph::girafeOutput(
              "network_plot",
              width = "100%",
              height = "600px"
            )
          )
        ),
        shiny::hr(),
        shiny::uiOutput("info_panel")
      )
    )
  )

  # Server
  server <- function(input, output, session) {
    selected_cluster <- shiny::reactiveVal(NULL)
    selected_node_id <- shiny::reactiveVal(NULL)

    all_nodes_df <- shiny::reactive({
      if (is_list_graph) {
        purrr::imap_dfr(graph_tbl, function(g, nm) {
          df <- tidygraph::activate(g, "nodes") |> as.data.frame()
          df$.graph <- nm
          if (!"time_window" %in% names(df)) {
            df$time_window <- nm
          }
          df
        })
      } else {
        df <- tidygraph::activate(graph_tbl, "nodes") |> as.data.frame()
        df$.graph <- "graph"
        if (!"time_window" %in% names(df)) {
          df$time_window <- NA_character_
        }
        df
      }
    })

    active_graph <- shiny::reactive({
      if (is_list_graph) graph_tbl[[input$selected_graph]] else graph_tbl
    })

    cluster_nodes_raw <- shiny::reactive({
      req(selected_cluster())
      g_tbl <- active_graph()
      tidygraph::activate(g_tbl, "nodes") |>
        as.data.frame() |>
        dplyr::filter(!!cluster_sym == selected_cluster())
    })

    output$network_plot <- ggiraph::renderGirafe({
      g_tbl <- active_graph()
      g_tbl <- tidygraph::activate(g_tbl, "nodes")

      if (is.null(node_size)) {
        g_tbl <- dplyr::mutate(g_tbl, size = 1)
      } else {
        if (!(node_size %in% colnames(as.data.frame(g_tbl)))) {
          cli::cli_abort(
            "The column specified in {.arg node_size} does not exist in the node data."
          )
        }
        g_tbl <- dplyr::mutate(g_tbl, size = !!rlang::sym(node_size))
      }

      nodes_df <- as.data.frame(tidygraph::activate(g_tbl, "nodes"))

      required_cols <- c(cluster_id, node_id, color, "size", "x", "y")
      missing_main <- setdiff(required_cols, colnames(nodes_df))
      missing_info <- setdiff(cluster_information, colnames(nodes_df))

      if (length(missing_main) > 0 || length(missing_info) > 0) {
        cli::cli_abort(
          "Missing required columns in nodes: {paste(c(missing_main, missing_info), collapse = ', ')}"
        )
      }

      # Build aesthetics for nodes
      node_aes <- list(
        x = quote(x),
        y = quote(y),
        fill = color_sym,
        size = quote(size),
        data_id = id_sym # <— was tooltip_sym
      )
      if (!is.null(tooltip_sym)) {
        node_aes$tooltip <- tooltip_sym
        #    node_aes$data_id <- tooltip_sym
      } else {
        node_aes$tooltip <- id_sym # fallback tooltip
      }

      # Cluster label data
      label_data <- nodes_df %>%
        dplyr::group_by(!!cluster_sym) %>%
        dplyr::summarise(
          label_x = mean(x, na.rm = TRUE),
          label_y = mean(y, na.rm = TRUE),
          color = first(!!color_sym),
          cluster_label = first(!!cluster_sym),
          .groups = "drop"
        )

      label_aes <- list(
        x = quote(label_x),
        y = quote(label_y),
        label = quote(cluster_label),
        data_id = quote(cluster_label),
        fill = quote(color)
      )
      if (!is.null(cluster_tooltip)) {
        label_aes$tooltip <- cluster_tooltip
      }

      #   edge_width_range <- c(input$min_edge_width, input$max_edge_width)
      node_size_range <- c(input$min_node_size, input$max_node_size)
      label_size <- input$label_size

      g <- ggraph::ggraph(g_tbl, layout = "manual", x = x, y = y) +
        # ggraph::geom_edge_arc0(
        #   ggplot2::aes(color = !!color_sym, width = weight),
        #   alpha = 0.3, strength = 0.2, show.legend = FALSE
        # ) +
        ggiraph::geom_point_interactive(
          mapping = do.call(ggplot2::aes, node_aes),
          shape = 21,
          alpha = 0.8,
          show.legend = FALSE
        ) +
        ggiraph::geom_label_repel_interactive(
          data = label_data,
          mapping = do.call(ggplot2::aes, label_aes),
          alpha = 0.9,
          fontface = "bold",
          show.legend = FALSE,
          size = label_size,
        ) +
        # ggraph::scale_edge_width_continuous(range = edge_width_range) +
        ggplot2::scale_size_continuous(range = node_size_range) +
        # ggraph::scale_edge_colour_identity() +
        ggplot2::scale_fill_identity() +
        ggplot2::theme_void()

      ggiraph::girafe(
        ggobj = g,
        width_svg = 10,
        height_svg = 6,
        options = list(
          ggiraph::opts_selection(type = "single"),
          ggiraph::opts_zoom(min = 1, max = 12), # wheel to zoom, drag to pan
          ggiraph::opts_toolbar(position = "topright") # gives reset zoom button)
        )
      )
    })

    shiny::observeEvent(input$network_plot_selected, {
      sel <- input$network_plot_selected
      nodes_all <- all_nodes_df()
      nodes_here <- tidygraph::activate(active_graph(), "nodes") |>
        as.data.frame()

      if (!is.null(sel) && sel %in% nodes_all[[id_chr]]) {
        # clicked a node -> show ONLY node info
        selected_node_id(sel)
        selected_cluster(NULL)
      } else if (!is.null(sel) && sel %in% nodes_here[[cluster_chr]]) {
        # clicked a cluster label -> show ONLY cluster info
        selected_cluster(sel)
        selected_node_id(NULL)
      } else {
        selected_node_id(NULL)
        selected_cluster(NULL)
      }
    })

    output$info_panel <- shiny::renderUI({
      if (!is.null(selected_node_id())) {
        tagList(
          shiny::h4("Selected node"),
          DT::DTOutput("node_info")
        )
      } else if (!is.null(selected_cluster())) {
        cl <- if (is_list_graph) {
          paste0(
            selected_cluster(),
            " — ",
            input$selected_graph,
            "-",
            as.integer(input$selected_graph) + 7
          )
        } else {
          as.character(selected_cluster())
        }
        tagList(
          shiny::h4(paste0("Documents in ", cl)),
          shiny::uiOutput("role_filter_ui"),
          DT::DTOutput("cluster_docs"),
          shiny::h4(paste0("Closest sentences for ", cl)),
          DT::DTOutput("cluster_sentences"),
          shiny::h4(paste0("Top References of ", cl)),
          DT::DTOutput("cluster_refs"),
          shiny::h4(paste0("Top References (without ID) of ", cl)),
          DT::DTOutput("cluster_refs_without_id"),
          shiny::h4(paste0("Cluster tf-idf for ", cl)),
          DT::DTOutput("cluster_tf_idf"),
          shiny::h4(paste0("Cluster origins for ", cl, " (t-1 → t)")),
          DT::DTOutput("cluster_origins_table"),
          shiny::h4(paste0("Cluster destinies for ", cl, " (t → t+1)")),
          DT::DTOutput("cluster_destinies_table")
        )
      } else {
        NULL
      }
    })

    output$cluster_share <- DT::renderDT({
      g_tbl <- active_graph()
      nodes <- tidygraph::activate(g_tbl, "nodes") %>% as.data.frame()

      tab <- nodes %>%
        dplyr::count(!!cluster_sym, name = "n") %>%
        dplyr::mutate(
          prop = n / sum(n),
          pct = sprintf("%.1f%%", 100 * prop)
        ) %>%
        dplyr::arrange(dplyr::desc(prop)) %>%
        dplyr::rename(Cluster = !!cluster_sym) %>%
        dplyr::select(Cluster, n, pct)

      DT::datatable(
        tab,
        options = list(dom = 't', paging = FALSE),
        rownames = FALSE
      )
    })

    output$node_info <- DT::renderDT({
      req(selected_node_id())
      nodes_all <- all_nodes_df()

      out <- nodes_all |>
        dplyr::filter(.data[[id_chr]] == selected_node_id()) |>
        dplyr::arrange(.graph) |>
        dplyr::select(
          dplyr::any_of(c(
            "time_window",
            cluster_id,
            cluster_information,
            node_size
          )),
          -sentence
        )

      tbl <- DT::datatable(
        out,
        options = list(pageLength = 10),
        escape = FALSE,
        rownames = FALSE
      )

      if (is_list_graph && "time_window" %in% names(out)) {
        lv <- unique(out$time_window)
        year <- lv %>% str_extract("^\\d+")
        col <- ifelse(year == input$selected_graph, "#fff3cd", "") # pale yellow
        tbl <- DT::formatStyle(
          tbl,
          "time_window",
          target = "row",
          backgroundColor = DT::styleEqual(lv, col)
        )
      }

      tbl
    })

    output$cluster_docs <- DT::renderDT({
      df <- cluster_nodes_raw()

      # role filter
      if (
        !is.null(input$role_filter) &&
          input$role_filter != "All" &&
          "role" %in% names(df)
      ) {
        df <- dplyr::filter(df, .data$role == input$role_filter)
      }

      # role tooltips (HTML)
      role_expl <- c(
        R1 = "Ultra-peripheral node: z low, P < 0.05. Almost all links within its cluster.",
        R2 = "Peripheral node: z low, 0.05 ≤ P < 0.62. Mostly within-cluster links.",
        R3 = "Connector node: z low, 0.62 ≤ P < 0.80. Many links to other clusters.",
        R4 = "Kinless node: z low, P ≥ 0.80. Links spread across clusters.",
        R5 = "Provincial hub: z high, P < 0.30. Hub inside its cluster.",
        R6 = "Connector hub: z high, 0.30 ≤ P < 0.75. Hub bridging clusters.",
        R7 = "Kinless hub: z high, P ≥ 0.75. Hub linked broadly across clusters."
      )
      role_alias <- c(
        "ultra-peripheral" = "R1",
        "peripheral" = "R2",
        "connector" = "R3",
        "kinless" = "R4",
        "provincial hub" = "R5",
        "connector hub" = "R6",
        "kinless hub" = "R7"
      )
      norm_label <- function(x) {
        x <- trimws(as.character(x))
        x <- gsub("[\u2010-\u2015]", "-", x)
        x <- gsub("\\s+", " ", x)
        tolower(x)
      }
      if ("role" %in% names(df)) {
        df$role <- vapply(
          df$role,
          function(val) {
            key <- role_alias[[norm_label(val)]]
            desc <- if (!is.null(key)) {
              role_expl[[key]]
            } else {
              "Role description unavailable"
            }
            sprintf(
              '<span title="%s">%s</span>',
              htmltools::htmlEscape(desc),
              htmltools::htmlEscape(as.character(val))
            )
          },
          FUN.VALUE = character(1)
        )
      }

      shown_cols <- intersect(cluster_information, names(df))
      if (!length(shown_cols)) {
        shown_cols <- setdiff(names(df), c("x", "y", ".graph"))
      }
      shown <- df |> dplyr::select(dplyr::all_of(shown_cols))

      # indices of numeric columns to tooltip (0-based for DataTables)
      cols <- colnames(shown)
      # indices (0-based)
      cols <- colnames(shown)
      z_idx <- match("z_within", cols) - 1L
      p_idx <- match("participation_coefficient", cols) - 1L

      # detailed tooltips
      z_expl <- paste(
        "Within-cluster degree z (standardized).",
        "Formula: z = (k_iC - mean(k_C)) / sd(k_C),",
        "  k_iC = links/weight from node i to nodes in its cluster C.",
        "Interpretation: higher = more hub-like inside its cluster; ~0 = average.",
        "Rule of thumb: z > 2.5 → hub.",
        sep = "\n"
      )
      p_expl <- paste(
        "Participation coefficient P ∈ [0,1].",
        "Formula: P = 1 - Σ_C (k_iC / k_i)^2,",
        "  k_iC = links/weight from i to cluster C; k_i = total links/weight of i.",
        "Interpretation: 0 = all links in one cluster; 1 = evenly spread across clusters.",
        "Typical cutoffs: ~0.05 local, ~0.30 local hub, ~0.62 connector, ≥0.80 kinless-like.",
        sep = "\n"
      )

      # JS callback to add title=... without changing data types

      js_row_cb <- DT::JS(paste0(
        "function(row,data){",
        if (!is.na(z_idx)) {
          paste0(
            "$('td:eq(",
            z_idx,
            ")', row).attr('title', ",
            jsonlite::toJSON(z_expl, auto_unbox = TRUE),
            ");"
          )
        } else {
          ""
        },
        if (!is.na(p_idx)) {
          paste0(
            "$('td:eq(",
            p_idx,
            ")', row).attr('title', ",
            jsonlite::toJSON(p_expl, auto_unbox = TRUE),
            ");"
          )
        } else {
          ""
        },
        "}"
      ))

      # format numbers for display only; keep raw for sort/filter
      num_renderer <- DT::JS(
        "function(data,type,row,meta){ if(type === 'display'){ if(data == null) return ''; return Number(data).toFixed(3);} return data; }"
      )
      col_defs <- list()
      if (!is.na(z_idx)) {
        col_defs <- c(
          col_defs,
          list(list(targets = z_idx, render = num_renderer))
        )
      }
      if (!is.na(p_idx)) {
        col_defs <- c(
          col_defs,
          list(list(targets = p_idx, render = num_renderer))
        )
      }

      DT::datatable(
        shown,
        filter = "top",
        escape = -which(cols %in% c("role", "Titre")), # do not escape role HTML; escape others
        rownames = FALSE,
        options = list(
          dom = "lfrtip",
          searchHighlight = TRUE,
          rowCallback = js_row_cb,
          columnDefs = col_defs
        )
      )
    })

    output$role_filter_ui <- shiny::renderUI({
      df <- cluster_nodes_raw()
      roles <- sort(unique(as.character(df$role)))
      if (!length(roles)) {
        return(NULL)
      }
      shiny::selectInput(
        "role_filter",
        "Filter by role:",
        choices = c("All", roles),
        selected = "All"
      )
    })

    output$cluster_sentences <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()

      # join on (time_window, cluster_id) exactly like top_references
      sentences <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        dplyr::distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(cluster_sentences)

      tab <- sentences %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        # pick reasonable columns if present
        dplyr::select(dplyr::any_of(c(
          cluster_information,
          "sentence",
          "similarity"
        )))
      DT::datatable(
        tab,
        escape = FALSE,
        options = list(pageLength = 15),
        rownames = FALSE
      )
    })

    output$cluster_refs <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      main_refs_cluster <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(top_references)
      main_refs_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(Nom, Annee, Revue_Abbrege, nb_cit) %>%
        DT::datatable(options = list(pageLength = 20))
    })

    output$cluster_refs_without_id <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      main_refs_cluster <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(top_references_without_id)
      main_refs_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(Nom, Annee, Revue_Abbrege, nb_cit) %>%
        DT::datatable(options = list(pageLength = 10))
    })

    output$cluster_tf_idf <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      tf_idf_for_cluster <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(tf_idf_data) %>%
        filter(!is.na(term))
      tf_idf_for_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(term, tf_idf) %>%
        mutate(tf_idf = round(tf_idf, 4)) %>%
        DT::datatable(options = list(pageLength = 20))
    })

    output$cluster_origins_table <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      origins <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(cluster_origins)
      origins %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(previous_cluster, origin_percent) %>%
        mutate(origin_percent = sprintf("%.1f%%", 100 * origin_percent)) %>%
        DT::datatable(options = list(pageLength = 10))
    })

    output$cluster_destinies_table <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      destinies <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(cluster_destinies)
      destinies %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(forward_cluster, destiny_percent) %>%
        mutate(destiny_percent = sprintf("%.1f%%", 100 * destiny_percent)) %>%
        DT::datatable(options = list(pageLength = 10))
    })
  }

  shiny::shinyApp(ui = ui, server = server)
}


#: Functions for network analysis-------------------------

#' Automatically Label Clusters Using Ollama::generate()
#'
#' @description
#' For each cluster in a `tbl_graph` or a list of `tbl_graph`s, this function aggregates
#' selected textual node metadata, passes it to a local LLM via `ollamar::generate()`,
#' and assigns a concise label back to the cluster.
#'
#' @param graph_tbl A `tbl_graph` or a named list of `tbl_graph` objects.
#' @param cluster_id Column name used to group nodes into clusters.
#' @param cluster_information Character vector of node metadata columns to include.
#' @param model Name of the Ollama model to use (e.g., "llama3", "mistral").
#' @param max_words Maximum number of words allowed in the label (default = 5).
#'
#' @return A `tbl_graph` or list of `tbl_graphs` with `cluster_label` added to nodes.
#' @export
label_cluster_llm <- function(
  graph_tbl,
  cluster_id,
  cluster_information,
  model = "llama3.1",
  max_words = 5
) {
  library(dplyr)
  library(tidygraph)
  library(data.table)
  library(ollamar)
  library(jsonlite)
  library(rlang)

  label_one_graph <- function(g) {
    g_df <- activate(g, "nodes") %>% as_tibble()

    if (!cluster_id %in% colnames(g_df)) {
      stop("cluster_id not found in node data.")
    }
    if (!all(cluster_information %in% colnames(g_df))) {
      stop("Some cluster_information columns are missing.")
    }

    cluster_ids <- unique(g_df[[cluster_id]])
    cluster_labels <- vector("list", length(cluster_ids))

    for (i in seq_along(cluster_ids)) {
      cid <- cluster_ids[i]
      cluster_data <- g_df %>% filter(!!sym(cluster_id) == cid)

      data_text <- cluster_data %>%
        select(all_of(cluster_information)) %>%
        mutate(across(everything(), as.character)) %>%
        mutate(row = row_number()) %>%
        pivot_longer(-row, names_to = "field", values_to = "content") %>%
        group_by(field) %>%
        summarise(values = list(na.omit(content)), .groups = "drop") %>%
        data.table::as.data.table()

      json_input <- toJSON(data_text, pretty = TRUE)

      prompt <- paste0(
        "Here is a cluster or scientific articles in economics made using bibliographic coupling.
                       Each article is described by its metadada.
                       Using this information to name cluster using no more than 5 words.
                       Your output should start with the name of the cluster followed by a full stop.
                       Your output should only be the name of the cluster, nothing else. I insist: output only the name of the cluster.
                       Here is the data: ",
        json_input
      )

      label <- ollamar::generate(
        model = model,
        prompt = prompt,
        output = "text"
      )

      cluster_labels[[i]] <- tibble(
        !!sym(cluster_id) := cid,
        cluster_label = trimws(label)
      )
    }

    cluster_labels_df <- bind_rows(cluster_labels)

    g <- g %>%
      activate(nodes) %>%
      left_join(cluster_labels_df, by = cluster_id)

    return(g)
  }

  if (inherits(graph_tbl, "list")) {
    return(lapply(graph_tbl, label_one_graph))
  } else if (inherits(graph_tbl, "tbl_graph")) {
    return(label_one_graph(graph_tbl))
  } else {
    stop("Input must be a tbl_graph or a named list of tbl_graphs.")
  }
}

#' Fast P and z metrics for Guimerà–Amaral role analysis
#'
#' Compute, for every node, the total strength \eqn{s_i}, the participation
#' coefficient \eqn{P_i}, and the within-cluster strength z-score \eqn{z_i},
#' using a single pass over the edge list. This function **does not** assign
#' discrete roles; it returns the metrics used to classify roles later.
#'
#' @details
#' Let \eqn{C(v)} be the cluster/community of node \eqn{v} (taken from
#' `comm_attr`). Let \eqn{w_{uv}} be the edge weight (from `weight_attr`).
#'
#' - **Strength to cluster \eqn{c}**: \eqn{s_{v,c} = \sum_{u \in c} w_{uv}}.
#' - **Total strength**: \eqn{s_v = \sum_c s_{v,c}}.
#' - **Participation coefficient**:
#'   \deqn{P_v = 1 - \sum_c \left(\frac{s_{v,c}}{s_v}\right)^2,}
#'   with \eqn{P_v \in [0,1]}. For isolates (\eqn{s_v = 0}), \eqn{P_v = NA}.
#' - **Within-cluster z-score**:
#'   \deqn{z_v = \frac{s_{v,C(v)} - \mu_{C(v)}}{\sigma_{C(v)}},}
#'   where \eqn{\mu_{C}} and \eqn{\sigma_{C}} are the mean and SD of
#'   \eqn{s_{u,C}} over nodes \eqn{u} in cluster \eqn{C}. If \eqn{\sigma_{C}=0}
#'   (single-node or uniform cluster), \eqn{z_v = 0}.
#'
#' The computation treats the graph as undirected for strengths (each edge
#' contributes to both endpoints). If direction matters, supply a symmetrized
#' `weight_attr` beforehand or adapt the function.
#'
#' @param graph An `igraph` (or `tidygraph::tbl_graph`) object with:
#'   - a vertex attribute `comm_attr` giving a cluster/community ID for every node,
#'   - an optional edge attribute `weight_attr` (defaults to uniform weight 1 when missing).
#' @param comm_attr Character scalar. Name of the vertex attribute holding cluster IDs.
#'   Default: `"cluster_leiden"`.
#' @param weight_attr Character scalar. Name of the edge attribute holding weights.
#'   Default: `"weight"`.
#'
#' @return A named list of numeric vectors of length `vcount(graph)`:
#' \describe{
#'   \item{total_strength}{Total incident weight \eqn{s_v}.}
#'   \item{participation_coefficient}{\eqn{P_v} in \[0,1\]; `NA` for isolates.}
#'   \item{z_within}{Within-cluster z-score \eqn{z_v}.}
#' }
#'
#' @section Performance:
#' Single aggregation over the edge list. Time \eqn{O(E)}, memory \eqn{O(E)}.
#' Suitable for large sparse graphs. No per-node `incident()` loops.
#'
#' @note To obtain discrete roles (e.g., R1–R7), learn thresholds on
#' `z_within` and `participation_coefficient` (e.g., fixed or data-driven)
#' and apply a `dplyr::case_when()` mapping.
#'
#' @examples
#' # toy example
#' library(igraph)
#' g <- make_ring(6)
#' V(g)$cluster_leiden <- c(1,1,1,2,2,2)
#' E(g)$weight <- 1
#' m <- compute_role_fast(g)  # list(total_strength, participation_coefficient, z_within)
#' head(m$participation_coefficient)
#'
#' @references
#' Guimerà, R., & Amaral, L. A. N. (2005). Functional cartography of complex
#' metabolic networks. *Nature*, 433, 895–900.
#'
#' @seealso \code{\link{vcount}}, \code{\link{ecount}}
#' @export
compute_role_fast <- function(
  graph,
  comm_attr = "cluster_leiden",
  weight_attr = "weight"
) {
  cli::cli_alert_info(
    "Computing roles for graph with {gorder(graph)} nodes and {gsize(graph)} edges."
  )
  n <- gorder(graph)
  comm <- igraph::vertex_attr(graph, comm_attr)
  if (is.null(comm)) {
    stop("vertex attribute ", comm_attr, " missing")
  }
  comm <- as.integer(factor(comm, levels = unique(comm))) # compact

  el <- igraph::as_edgelist(graph, names = FALSE) # m x 2
  w <- igraph::edge_attr(graph, weight_attr)
  if (is.null(w)) {
    w <- rep(1, nrow(el))
  }

  # Each edge contributes weight w to each endpoint toward the OTHER endpoint's community
  dt <- data.table(
    node = c(el[, 1], el[, 2]),
    other = c(el[, 2], el[, 1]),
    w = c(w, w)
  )
  dt[, comm_other := comm[other]]
  dt[, other := NULL]

  # s_ic: strength from node i to community c
  s_ic <- dt[, .(s = sum(w)), by = .(node, comm = comm_other)]

  # total strength s_i
  s_i <- s_ic[, .(total_strength = sum(s)), by = node]
  total_strength <- numeric(n)
  if (nrow(s_i)) {
    total_strength[s_i$node] <- s_i$total_strength
  }

  # Participation P_i = 1 - sum_c (s_ic / s_i)^2
  tmp <- s_ic[s_i, on = "node"] # join s_i
  tmp[, frac2 := (s / total_strength)^2]
  Ptab <- tmp[, .(P = 1 - sum(frac2)), by = node]
  P <- rep(NA_real_, n)
  if (nrow(Ptab)) {
    P[Ptab$node] <- Ptab$P
  }
  P[total_strength == 0] <- NA_real_

  # s_in: strength to OWN community
  setkey(s_ic, node, comm)
  idx <- data.table(node = seq_len(n), comm = comm)
  own <- s_ic[idx, .(node, s_in = s), nomatch = 0L]
  s_in <- numeric(n)
  if (nrow(own)) {
    s_in[own$node] <- own$s_in
  }

  # z within each community
  nd <- data.table(node = seq_len(n), comm = comm, s_in = s_in)
  nd[, mu := mean(s_in), by = comm]
  nd[, sdv := sd(s_in), by = comm]
  nd[, z := ifelse(is.finite(sdv) & sdv > 0, (s_in - mu) / sdv, 0)]
  z <- nd$z

  list(
    total_strength = total_strength,
    participation_coefficient = P,
    z_within = z
  )
}

#' Data-driven cut points for Guimerà–Amaral role assignment
#'
#' Learn thresholds to classify nodes into Guimerà–Amaral roles using observed
#' distributions of within-cluster z-scores and participation coefficients.
#' The function estimates:
#' \itemize{
#'   \item a global hub threshold on \code{z} via a high quantile;
#'   \item three non-hub \code{P} cut points (k=4 clusters → 3 cuts) by 1-D k-means;
#'   \item two hub \code{P} cut points  (k=3 clusters → 2 cuts) by 1-D k-means.
#' }
#' If clustering is not feasible (too few points or unique values), canonical
#' defaults are used: \code{c(0.05, 0.62, 0.80)} for non-hubs and
#' \code{c(0.30, 0.75)} for hubs.
#'
#' @details
#' Algorithm:
#' \enumerate{
#'   \item Compute \code{hub_z = quantile(z, hub_q)}.
#'   \item Split \code{P} into non-hub (\code{z < hub_z}) and hub (\code{z >= hub_z}).
#'   \item For each split, run \code{kmeans(P, centers = k)} when possible. Sort the
#'         k centroids \eqn{c_1 < \dots < c_k} and define cut points as midpoints:
#'         \eqn{(c_1+c_2)/2, \dots, (c_{k-1}+c_k)/2}.
#' }
#'
#' Interpretation:
#' \itemize{
#'   \item \code{hub_z}: z cutoff separating hubs vs non-hubs.
#'   \item \code{nonhub_P}: three P cuts mapping to ultra-peripheral, peripheral, connector, kinless.
#'   \item \code{hub_P}: two P cuts mapping to provincial hub, connector hub, kinless hub.
#' }
#'
#' Reproducibility: \code{kmeans} is deterministic given data, but you can set
#' \code{set.seed()} for safety before calling. For cross-window comparability,
#' estimate thresholds on pooled data or on a stratified sample with equal
#' per-window sizes.
#'
#' @param z Numeric vector of within-cluster z-scores.
#' @param P Numeric vector of participation coefficients in \eqn{[0,1]}.
#' @param hub_q Numeric in \eqn{(0,1)}. Quantile of \code{z} used as the hub cutoff.
#'   Default \code{0.975}.
#' @param k_nonhub Integer. Number of k-means clusters for non-hub \code{P}.
#'   Default \code{4}.
#' @param k_hub Integer. Number of k-means clusters for hub \code{P}.
#'   Default \code{3}.
#'
#' @return A list with components:
#' \describe{
#'   \item{\code{hub_z}}{Scalar z cutoff separating hubs and non-hubs.}
#'   \item{\code{nonhub_P}}{Numeric vector of length 3 with P cut points for non-hubs
#'                          (in increasing order).}
#'   \item{\code{hub_P}}{Numeric vector of length 2 with P cut points for hubs
#'                       (in increasing order).}
#' }
#'
#' @examples
#' set.seed(1)
#' z <- c(rnorm(900, 0, 1), rnorm(100, 3, 0.6))     # many non-hubs, some hubs
#' P <- runif(1000)
#' thr <- choose_role_thresholds(z, P)
#' thr$hub_z
#' thr$nonhub_P
#' thr$hub_P
#'
#' # Using the thresholds to assign roles (sketch):
#' # dplyr::case_when(
#' #   z <  thr$hub_z & P <= thr$nonhub_P[1] ~ "ultra-peripheral",
#' #   z <  thr$hub_z & P <= thr$nonhub_P[2] ~ "peripheral",
#' #   z <  thr$hub_z & P <= thr$nonhub_P[3] ~ "connector",
#' #   z <  thr$hub_z                        ~ "kinless",
#' #   z >= thr$hub_z & P <= thr$hub_P[1]    ~ "provincial hub",
#' #   z >= thr$hub_z & P <= thr$hub_P[2]    ~ "connector hub",
#' #   TRUE                                  ~ "kinless hub"
#' # )
#'
#' @seealso \code{\link{compute_role_fast}}, \code{\link[stats]{kmeans}},
#'   \code{\link[stats]{quantile}}
#' @export
choose_role_thresholds <- function(
  z,
  P,
  hub_q = 0.975,
  k_nonhub = 4,
  k_hub = 3
) {
  stopifnot(length(z) == length(P))
  z <- z[is.finite(z)]
  P <- P[is.finite(P)]
  if (!length(z)) {
    stop("empty z")
  }

  hub_thr <- unname(stats::quantile(z, hub_q, na.rm = TRUE))

  nonhub_P <- P[z < hub_thr]
  hub_P <- P[z >= hub_thr]

  get_breaks <- function(x, k, fallback) {
    if (length(x) >= k && length(unique(x)) >= k) {
      km <- stats::kmeans(x, centers = k, iter.max = 100)
      centers <- sort(as.numeric(km$centers))
      sort((centers[-k] + centers[-1]) / 2)
    } else {
      fallback
    }
  }

  nonhub_brks <- get_breaks(nonhub_P, k_nonhub, c(0.05, 0.62, 0.80))
  hub_brks <- get_breaks(hub_P, k_hub, c(0.30, 0.75))

  list(hub_z = hub_thr, nonhub_P = nonhub_brks, hub_P = hub_brks)
}
