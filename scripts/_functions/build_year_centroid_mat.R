#: Manipulating embeddings-----------------------

#' Build per-year centroid matrix from sentence-level embeddings
#'
#' @title Build per-year centroid matrix
#' @description
#' Compute a per-year centroid (mean) embedding from a sentence-level table that
#' contains a list-column of numeric embedding vectors. The result is a numeric
#' matrix with one row per year (rownames are years as character) and one column
#' per embedding dimension.
#'
#' @param df tibble or data.frame. Must contain a column named by `year_col`
#'   (integer or numeric scalar per row) and a list-column named by
#'   `embedding_col` where each element is a numeric vector (the embedding).
#'   NA entries in the embedding list-column are ignored. Rows whose year is not
#'   in `years` are dropped.
#' @param year_col character scalar. Name of the column in `df` containing year
#'   values (e.g. `year`). Default: `"year"`.
#' @param embedding_col character scalar. Name of the list-column that holds
#'   numeric embedding vectors. Default: `"embedding"`.
#' @param years integer vector. Allowed years to keep; rows with `year_col`
#'   outside this range are dropped.
#'
#' @return
#' A numeric matrix with rows = years and columns = embedding dimensions.
#' - Row names are the years (character) sorted in increasing order.
#' - If no rows match `years` the function returns a numeric matrix with
#'   zero rows and zero columns (0 x 0).
#' - If a year has no valid embeddings it is omitted from the output.
#' - The function may error if embedding vectors combined for a year have
#'   inconsistent lengths (precondition: embedding vectors for all rows that
#'   contribute to the same year must have the same length).
#'
#' @details
#' This function aggregates sentence-level embeddings into per-year centroids
#' by computing the column-wise mean of all embeddings for each year. It is
#' intended for small-to-moderate dimensional embeddings (e.g. numeric vectors
#' of length 128–2048) stored in a list-column.
#'
#' Implementation notes:
#' - Step 1: Coerce `df` to a tibble and filter rows to `years`.
#' - Step 2: Remove rows with missing embeddings, group by the `year_col`,
#'   and summarise a `centroid` list-column. For each group we:
#'     * extract the list of numeric vectors,
#'     * rbind them into a matrix with `do.call(rbind, ...)` (rows = sentences),
#'     * compute `colMeans()` to get the centroid; if a year has zero rows we
#'       return `numeric(0)` for that centroid.
#' - Step 3: If no years are present after grouping return a 0x0 numeric matrix.
#' - Step 4: Unnest the numeric-centroid vectors into long format, assign a
#'   `dimension` index per centroid element, and use `xtabs()` to pivot to a
#'   year-by-dimension matrix.
#' - Step 5: Convert to a numeric matrix and ensure rownames are character
#'   years sorted ascending.
#'
#' Assumptions and failure modes:
#' - Embeddings for rows that contribute to the same year must be numeric
#'   vectors of identical length. If lengths differ, `do.call(rbind, ...)`
#'   will error.
#' - If some list elements are `NA` or `NULL` they are filtered out before
#'   aggregation; a year with no valid embeddings is omitted.
#' - The function depends on `tibble`, `dplyr`, `tidyr`, and base `stats::xtabs`.
#'   It does not mutate global state.
#'
#' Alternatives and trade-offs:
#' - The function chooses a simple arithmetic mean (centroid) per year for
#'   clarity and efficiency. Alternatives (e.g. robust medoids or weighted
#'   centroids) would add complexity and compute cost.
#'
#' @examples
#' # normal case: two years with 2-d embeddings
#' df <- tibble::tibble(
#'   year = c(1900L, 1900L, 1901L),
#'   embedding = list(c(1, 0), c(0, 1), c(2, 2))
#' )
#' build_year_centroid_mat(df, year_col = "year", embedding_col = "embedding")
#'
#' # edge case: no rows in requested years -> returns 0 x 0 matrix
#' df_empty < - tibble::tibble(year = integer(0), embedding = list())
#' build_year_centroid_mat(df_empty, years = 2000:2001)
#'
#' @keywords internal
#' @family embeddings
#' @aliases build_year_centroid_mat
#' @concept embeddings
build_year_centroid_mat <- function(
  df,
  year_col = "year",
  embedding_col = "embedding",
  years = NULL
) {
  # Coerce to tibble and keep only requested years
  df <- tibble::as_tibble(df) |> dplyr::filter(.data[[year_col]] %in% years)

  # Group by year and compute centroid (mean of embeddings) and row count.
  per_year <- df |>
    dplyr::filter(!is.na(.data[[embedding_col]])) |> # drop rows with NA embeddings
    dplyr::group_by(year = .data[[year_col]]) |>
    dplyr::summarise(
      centroid = list({
        # Extract list of embeddings for this year
        emb_list <- .data[[embedding_col]]

        # If there are no embeddings, return an empty numeric to signal absence.
        if (length(emb_list) == 0L) {
          numeric(0)
        } else {
          # Bind list of numeric vectors into a matrix (rows = sentences).
          # This will error if vectors have inconsistent lengths -- that's a
          # precondition for correct input.
          mats <- do.call(rbind, emb_list)

          # If rbind produced zero rows, return numeric(0); otherwise compute column means.
          if (nrow(mats) == 0L) numeric(0) else colMeans(mats)
        }
      }),
      n = dplyr::n(), # number of rows (sentences) per year
      .groups = "drop"
    ) |>
    dplyr::arrange(year)

  # If no years survived the filtering/grouping return a 0x0 numeric matrix.
  if (nrow(per_year) == 0L) {
    return(matrix(NA_real_, nrow = 0, ncol = 0))
  }

  # Unnest numeric-centroid vectors into long form and create a year x dimension matrix.
  reps <- per_year |>
    tidyr::unnest(cols = c(centroid)) |>
    # assign a sequential dimension index within each year; ensures consistent xtabs formula
    dplyr::mutate(dimension = row_number(), .by = year)

  # Use xtabs to pivot long form into a matrix: rows = year, columns = dimension.
  mat <- xtabs(centroid ~ year + dimension, data = reps)
  mat <- as.matrix(mat)

  # Ensure rownames are character years sorted ascending (common expectation downstream).
  rownames(mat) <- as.character(sort(as.integer(rownames(mat))))
  mat
}
