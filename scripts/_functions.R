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
#' df_empty <- tibble::tibble(year = integer(0), embedding = list())
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
#' @export
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
  norm_mat <- mat[keep, , drop = FALSE] / nrms[keep]

  norm_mat
}

#' Compute Average Pairwise Distance (APD) matrix across years
#'
#' @title Compute APD matrix for sentence embeddings by year
#' @description
#' Build per-year embedding matrices from a sentence-level tibble and compute the
#' average pairwise distance (APD = mean(1 - cosine)) for every unordered pair of years.
#'
#' @param bert_df data.frame or tibble. Must contain a column named by `year_col`
#'   (one value per sentence row) and a list-column named by `embeddings_col`
#'   where each element is a numeric vector (embedding). One row represents one
#'   sentence. Rows with `NA` in the embedding column are filtered out prior to grouping.
#' @param year_col character scalar. Name of the column in `bert_df` that contains
#'   year labels. Default: `"year"`. Values are treated as grouping keys;
#'   they are coerced to `character` for matrix dimnames. NA year values are preserved
#'   as a group if present.
#' @param embeddings_col character scalar. Name of the list-column containing numeric
#'   embedding vectors. Default: `"embedding"`. Each list element must be a numeric
#'   vector of identical length for all embeddings within a year (and ideally across years).
#'   Inconsistent lengths trigger an error.
#' @param chunk_size integer scalar >= 1. Number of rows of `A` processed per block
#'   inside `apd_from_mats()` to limit peak memory usage. Default: `5000L`. Smaller
#'   values reduce memory at the cost of more matrix multiplies.
#'
#' @return numeric matrix (double) of shape (n_years x n_years) with row and column
#'   names set to the character representation of the grouped `year` values. The
#'   matrix is symmetric; off-diagonal entries are the APD between the corresponding
#'   years. Diagonal entries are `NA_real_` (not computed). If no years with embeddings
#'   are found the function returns a 0x0 numeric matrix. If fewer than two non-empty
#'   years exist the returned matrix contains `NA` values (no pairwise computations).
#'
#' @details
#' The function groups `bert_df` by `year_col`, coerces each year's list of embeddings
#' into a numeric matrix with rows = sentences and columns = embedding dimensions, and
#' then computes APD for every unordered pair of non-empty years using `apd_from_mats()`.
#'
#' Implementation notes:
#' - High-level sequence:
#'   1. Validate inputs and required columns early to provide clear errors.
#'   2. Filter out rows with missing embeddings, group by year, and build a list-column
#'      `emb_mat` where each element is a numeric matrix (rows = sentences).
#'   3. Return an empty 0x0 matrix if no years remain.
#'   4. Create an n_years x n_years result matrix `M` initialised with `NA_real_`.
#'   5. Identify non-empty years and compute APD only for unordered pairs of these years
#'      to avoid needless work; compute in a loop while updating a single progress bar.
#'   6. For each pair call `apd_from_mats(Ai, Bj, chunk_size)` which performs blocked
#'      matrix multiplication and returns the scalar APD; assign symmetrically in `M`.
#' - Assumptions and preconditions:
#'   - `bert_df` is a data.frame/tibble with the named columns.
#'   - Each list element in `embeddings_col` is a numeric vector; vectors within a year
#'     must share the same length. The function does not coerce non-numeric embeddings.
#' - Edge-case handling and failure modes:
#'   - Years with zero sentences produce empty matrices and are skipped for pairwise
#'     computation (entries remain `NA`).
#'   - If fewer than two non-empty years exist the function returns the `NA`-filled matrix.
#'   - If embedding lengths are inconsistent within a year the function errors.
#'   - If `apd_from_mats()` encounters zero-row inputs it returns `NA_real_`, which
#'     propagates to the result.
#' - Trade-offs:
#'   - The function avoids building a full (n_total_sentences)^2 similarity matrix
#'     by computing APD per-year-pair and using chunked multiplications inside `apd_from_mats()`.
#' - Dependencies and side-effects:
#'   - Uses `dplyr`, `tidyr`, `tibble`, `cli` and `utils` for grouping, shaping, and user feedback.
#'   - Does not mutate global state or write files.
#'
#' @implementation
#' The implementation materialises per-year matrices, enumerates unordered pairs via
#' `utils::combn()`, and computes each APD by calling `apd_from_mats()` which performs
#' blocked matrix multiplications (Ai %*% t(B)) and accumulates `sum(1 - similarity)`.
#' Progress is reported with a single `cli` progress bar. Result matrix `M` is symmetric.
#'
#' @examples
#' library(tibble)
#' # normal case: two years with two 3-d embeddings each
#' df <- tibble::tibble(
#'   year = c(2000, 2000, 2001, 2001),
#'   embedding = list(
#'     c(1, 0, 0),
#'     c(0, 1, 0),
#'     c(1, 1, 0),
#'     c(0, 0, 1)
#'   )
#' )
#' compute_apd_by_years(df, year_col = "year", embeddings_col = "embedding", chunk_size = 2L)
#'
#' # edge case: a year with no embeddings (row filtered out) -> returns matrix with NAs
#' df2 <- tibble::tibble(
#'   year = c(2000, 2001),
#'   embedding = list(NA, c(1, 0, 0))
#' )
#' compute_apd_by_years(df2, year_col = "year", embeddings_col = "embedding")
#'
#' @seealso apd_from_mats, proto_distance_matrix
#' @keywords similarity
#' @export
compute_apd_by_years <- function(
  bert_df,
  year_col = "year",
  embeddings_col = "embedding",
  chunk_size = 5000L
) {
  # Basic validations
  if (!is.data.frame(bert_df)) {
    cli::cli_abort("`bert_df` must be a data.frame or tibble.")
  }
  if (!all(c(year_col, embeddings_col) %in% colnames(bert_df))) {
    cli::cli_abort(
      "`bert_df` must contain columns {year_col} and {embeddings_col}."
    )
  }

  # Build per-year embedding matrices: list of numeric matrices (n_sentences x dim)
  per_year <- bert_df |>
    dplyr::filter(!is.na(.data[[embeddings_col]])) |>
    dplyr::group_by(year = .data[[year_col]]) |>
    dplyr::summarise(
      emb_mat = list({
        # coerce list of numeric vectors -> numeric matrix (rows = sentences)
        vecs <- .data[[embeddings_col]]
        if (length(vecs) == 0L) {
          matrix(numeric(0), nrow = 0, ncol = 0)
        } else {
          # ensure all vectors have the same length
          lens <- vapply(vecs, length, integer(1))
          if (length(unique(lens)) != 1L) {
            cli::cli_abort(
              "Embeddings for year {unique(year)} have inconsistent dimensions."
            )
          }
          do.call(rbind, vecs)
        }
      }),
      n = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::arrange(year)

  # If no years remain, return empty matrix
  if (nrow(per_year) == 0L) {
    cli::cli_alert_info(
      "No years with embeddings found; returning empty matrix."
    )
    return(matrix(NA_real_, nrow = 0, ncol = 0))
  }

  years <- as.character(per_year$year)
  n_years <- length(years)
  M <- matrix(NA_real_, n_years, n_years, dimnames = list(years, years))

  total_sentences <- sum(per_year$n, na.rm = TRUE)
  n_empty_years <- sum(per_year$n == 0L)
  cli::cli_alert_info(
    "Found {n_years} years with a total of {total_sentences} sentences; {n_empty_years} empty years will be skipped for APD computation."
  )

  # Identify non-empty years to avoid unnecessary work / NA results
  non_empty_idx <- which(per_year$n > 0L)
  if (length(non_empty_idx) < 2L) {
    cli::cli_alert_info(
      "Not enough non-empty years ({length(non_empty_idx)}) to compute pairwise APD; returning matrix with NA diagonals."
    )
    return(M)
  }

  # Build list of unordered pairs to compute so we can show a single progress bar
  pairs_mat <- utils::combn(non_empty_idx, 2L)
  total_pairs <- ncol(pairs_mat)

  cli::cli_progress_bar("Computing APD across year pairs", total = total_pairs)
  on.exit(cli::cli_progress_done(), add = TRUE)

  # Loop over pairs (vectorized chunking handled inside apd_from_mats)
  for (k in seq_len(total_pairs)) {
    i <- pairs_mat[1L, k]
    j <- pairs_mat[2L, k]

    Ai <- per_year$emb_mat[[i]]
    Bj <- per_year$emb_mat[[j]]

    # defensive checks (shouldn't be necessary because we filtered non_empty_idx)
    if (nrow(Ai) == 0L || nrow(Bj) == 0L) {
      cli::cli_progress_update()
      next
    }

    val <- apd_from_mats(Ai, Bj, chunk_size = as.integer(chunk_size))
    M[i, j] <- val
    M[j, i] <- val

    cli::cli_progress_update()
  }

  cli::cli_alert_success("Computed APD for {total_pairs} year pairs.")

  M
}

# Mean pairwise cosine distance between rows of A and B, vectorized
#' @title Average Pairwise Distance (APD) between two sets of row-vectors
#' @description
#' Compute the average pairwise distance (APD) between the rows of two numeric
#' matrices based on cosine similarity. APD is defined as the mean of
#' (1 - cosine_similarity) over all row pairs (one row from `A`, one row from `B`).
#'
#' @param A numeric matrix with rows representing vectors (embedding matrix).
#'   Expected shape: numeric matrix with `ncol(A) = d` (d >= 1) and `nrow(A) >= 0`.
#'   Rows may contain zeros; behavior for zero-norm rows depends on the helper
#'   `.row_normalize` (see Implementation notes). NA values in `A` will typically
#'   propagate to the result or produce errors during normalization/multiplication.
#' @param B numeric matrix with rows representing vectors (embedding matrix).
#'   Expected shape: numeric matrix with `ncol(B) = d` (must match `ncol(A)`)
#'   and `nrow(B) >= 0`. See `A` for NA/zero-handling notes.
#' @param chunk_size integer scalar (positive) controlling the number of rows of
#'   `A` processed per block when computing similarities. Default `5000L`.
#'   Must be a positive integer; non-positive or non-integer values will cause
#'   underlying functions (e.g. `seq.int`) to error. Chunking trades memory
#'   for repeated matrix multiplies (smaller `chunk_size` uses less memory).
#'
#' @return
#' Numeric scalar (double) equal to the APD:
#' the mean value of `1 - cosine(a_i, b_j)` across all `i=1..nrow(A)`,
#' `j=1..nrow(B)`. If either `A` or `B` has zero rows (`nrow(...) == 0`),
#' the function returns `NA_real_` because the APD is undefined in that case.
#' If matrix dimensions are incompatible (different `ncol`), the function will
#' error when attempting matrix multiplication.
#'
#' @details
#' At a high level, this function:
#' - row-normalizes `A` and `B` so each row has unit (or defined) norm,
#' - computes cosine similarities between rows of `A` and `B` in memory-bounded
#'   chunks, and
#' - returns the average of `1 - cosine_similarity` across all cross-pairs.
#'
#' The APD computed is:
#' \deqn{APD(A,B) = \frac{1}{|A||B|} \sum_{i=1}^{|A|}\sum_{j=1}^{|B|} \left[1 - \cos(a_i, b_j)\right],}
#' where \eqn{\cos(a_i, b_j)} is the cosine similarity between row vectors
#' `a_i` (from `A`) and `b_j` (from `B`).
#'
#' Implementation notes:
#' - High-level algorithm and major steps:
#'   1. Call `row_normalize(A)` and `row_normalize(B)` to (attempt to)
#'      normalize each row to unit length. The function relies on this helper
#'      to handle zero-norm rows or to signal errors for invalid input.
#'   2. If either matrix has zero rows after normalization (`nrow(A) == 0` or
#'      `nrow(B) == 0`), return `NA_real_` because no pairwise distances exist.
#'   3. Iterate over `A` in blocks of `chunk_size` rows. For each block `Ai`,
#'      compute `S_chunk <- Ai %*% t(B)` which yields pairwise cosine
#'      similarities for that block vs all rows of `B`. Accumulate
#'      `sum(1 - S_chunk)` across blocks and divide by `nrow(A) * nrow(B)` at the end.
#' - Memory and performance:
#'   - The chunking strategy bounds memory by materializing only one similarity
#'     block at a time (size `min(chunk_size, nrow(A)) x nrow(B)`).
#'   - Time complexity is O(nrow(A) * nrow(B) * d) where `d = ncol(A)`.
#'   - Choosing `chunk_size` trades memory (larger = fewer matrix multiplies)
#'     for peak memory usage.
#' - Assumptions and preconditions:
#'   - `A` and `B` are numeric matrices with the same number of columns.
#'   - `.row_normalize` is available in the environment and performs row-wise
#'     normalization (it must not silently drop rows; it should preserve row
#'     counts or the function's NA check will not behave as intended).
#' - Edge-case handling and failure modes:
#'   - Returns `NA_real_` if either matrix has zero rows (undefined APD).
#'   - If `A` or `B` contains rows with zero norm, the result depends on
#'     `row_normalize`'s behavior (e.g. it may return zero rows, `NaN`s, or
#'     error). If `row_normalize` produces non-finite values, matrix
#'     multiplication and the sum will propagate them.
#'   - If `ncol(A) != ncol(B)` the `%*%` operation will error.
#' - Alternatives and trade-offs:
#'   - One could compute full similarity matrix in-memory when data is small,
#'     avoiding repeated multiplications; chunking is chosen here for
#'     scalability to larger datasets.
#' - Dependencies and side-effects:
#'   - Uses base R matrix multiplication. Requires a `row_normalize` helper
#'     function to exist in scope. The function does not mutate global state
#'     or write files.
#'
#' @implementation
#' Blocked matrix multiplication over `A` rows: normalize rows -> iterate blocks
#' of `A` -> compute `Ai %*% t(B)` -> accumulate `sum(1 - similarities)` ->
#' divide by total number of pairs. This minimizes peak memory while remaining
#' straightforward and numerically stable for typical dense numeric matrices.
#'
#' @examples
#' # normal case: small random matrices (rows are vectors)
#' set.seed(1)
#' A <- matrix(rnorm(6), nrow = 2) # 2 x 3
#' B <- matrix(rnorm(9), nrow = 3) # 3 x 3
#' # assume .row_normalize exists and normalizes rows; for example:
#' .row_normalize <- function(m) {
#'   if (nrow(m) == 0) return(m)
#'   norms <- sqrt(rowSums(m * m))
#'   # avoid division by zero: leave zero rows as zeros
#'   nz <- norms > 0
#'   m[nz, , drop = FALSE] <- m[nz, , drop = FALSE] / norms[nz]
#'   m
#' }
#' apd_from_mats(A, B, chunk_size = 1L)
#'
#' # edge case: one input has zero rows -> returns NA_real_
#' A0 <- matrix(numeric(0), nrow = 0, ncol = 3)
#' apd_from_mats(A0, B)
#'
#' # edge case: zero-norm row (depends on .row_normalize handling)
#' A_zero <- rbind(c(0, 0, 0), c(1, 0, 0))
#' apd_from_mats(A_zero, B, chunk_size = 2L)
#'
#' @author GitHub Copilot
#' @keywords internal
#' @family similarity
#' @seealso base::`%*%`, stats::`dist`
apd_from_mats <- function(A, B, chunk_size = 5000L) {
  A <- row_normalize(A)
  B <- row_normalize(B)
  nA <- nrow(A)
  nB <- nrow(B)
  if (nA == 0L || nB == 0L) {
    return(NA_real_)
  } # undefined if any side empty or all-zero

  # Chunk over the larger side to bound memory of the similarity matrix
  # Computes mean(1 - S) without materializing all chunks at once
  total_pairs <- as.double(nA) * as.double(nB)
  sum_one_minus_cos <- 0.0

  # choose chunking on A
  idx_starts <- seq.int(1L, nA, by = chunk_size)
  for (s in idx_starts) {
    e <- min(s + chunk_size - 1L, nA) # end index for this chunk
    Ai <- A[s:e, , drop = FALSE]
    S_chunk <- Ai %*% t(B) # cosine similarities
    sum_one_minus_cos <- sum_one_minus_cos + sum(1 - S_chunk)
  }
  sum_one_minus_cos / total_pairs
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

#' Compute Average Pairwise Distance (APD) matrix across years
#'
#' @title Compute APD matrix for sentence embeddings by year
#' @description
#' Build per-year embedding matrices from a sentence-level tibble and compute the
#' average pairwise distance (APD = mean(1 - cosine)) for every unordered pair of years.
#'
#' @param bert_df data.frame or tibble. Must contain a column named by `year_col`
#'   (one value per sentence row) and a list-column named by `embeddings_col`
#'   where each element is a numeric vector (embedding). One row represents one
#'   sentence. Rows with `NA` in the embedding column are filtered out prior to grouping.
#' @param year_col character scalar. Name of the column in `bert_df` that contains
#'   year labels. Default: `"year"`. Values are treated as grouping keys;
#'   they are coerced to `character` for matrix dimnames. NA year values are preserved
#'   as a group if present.
#' @param embeddings_col character scalar. Name of the list-column containing numeric
#'   embedding vectors. Default: `"embedding"`. Each list element must be a numeric
#'   vector of identical length for all embeddings within a year (and ideally across years).
#'   Inconsistent lengths trigger an error.
#' @param chunk_size integer scalar >= 1. Number of rows of `A` processed per block
#'   inside `apd_from_mats()` to limit peak memory usage. Default: `5000L`. Smaller
#'   values reduce memory at the cost of more matrix multiplies.
#'
#' @return numeric matrix (double) of shape (n_years x n_years) with row and column
#'   names set to the character representation of the grouped `year` values. The
#'   matrix is symmetric; off-diagonal entries are the APD between the corresponding
#'   years. Diagonal entries are `NA_real_` (not computed). If no years with embeddings
#'   are found the function returns a 0x0 numeric matrix. If fewer than two non-empty
#'   years exist the returned matrix contains `NA` values (no pairwise computations).
#'
#' @details
#' The function groups `bert_df` by `year_col`, coerces each year's list of embeddings
#' into a numeric matrix with rows = sentences and columns = embedding dimensions, and
#' then computes APD for every unordered pair of non-empty years using `apd_from_mats()`.
#'
#' Implementation notes:
#' - High-level sequence:
#'   1. Validate inputs and required columns early to provide clear errors.
#'   2. Filter out rows with missing embeddings, group by year, and build a list-column
#'      `emb_mat` where each element is a numeric matrix (rows = sentences).
#'   3. Return an empty 0x0 matrix if no years remain.
#'   4. Create an n_years x n_years result matrix `M` initialised with `NA_real_`.
#'   5. Identify non-empty years and compute APD only for unordered pairs of these years
#'      to avoid needless work; compute in a loop while updating a single progress bar.
#'   6. For each pair call `apd_from_mats(Ai, Bj, chunk_size)` which performs blocked
#'      matrix multiplication and returns the scalar APD; assign symmetrically in `M`.
#' - Assumptions and preconditions:
#'   - `bert_df` is a data.frame/tibble with the named columns.
#'   - Each list element in `embeddings_col` is a numeric vector; vectors within a year
#'     must share the same length. The function does not coerce non-numeric embeddings.
#' - Edge-case handling and failure modes:
#'   - Years with zero sentences produce empty matrices and are skipped for pairwise
#'     computation (entries remain `NA`).
#'   - If fewer than two non-empty years exist the function returns the `NA`-filled matrix.
#'   - If embedding lengths are inconsistent within a year the function errors.
#'   - If `apd_from_mats()` encounters zero-row inputs it returns `NA_real_`, which
#'     propagates to the result.
#' - Trade-offs:
#'   - The function avoids building a full (n_total_sentences)^2 similarity matrix
#'     by computing APD per-year-pair and using chunked multiplications inside `apd_from_mats()`.
#' - Dependencies and side-effects:
#'   - Uses `dplyr`, `tidyr`, `tibble`, `cli` and `utils` for grouping, shaping, and user feedback.
#'   - Does not mutate global state or write files.
#'
#' @implementation
#' The implementation materialises per-year matrices, enumerates unordered pairs via
#' `utils::combn()`, and computes each APD by calling `apd_from_mats()` which performs
#' blocked matrix multiplications (Ai %*% t(B)) and accumulates `sum(1 - similarity)`.
#' Progress is reported with a single `cli` progress bar. Result matrix `M` is symmetric.
#'
#' @examples
#' library(tibble)
#' # normal case: two years with two 3-d embeddings each
#' df <- tibble::tibble(
#'   year = c(2000, 2000, 2001, 2001),
#'   embedding = list(
#'     c(1, 0, 0),
#'     c(0, 1, 0),
#'     c(1, 1, 0),
#'     c(0, 0, 1)
#'   )
#' )
#' compute_apd_by_years(df, year_col = "year", embeddings_col = "embedding", chunk_size = 2L)
#'
#' # edge case: a year with no embeddings (row filtered out) -> returns matrix with NAs
#' df2 <- tibble::tibble(
#'   year = c(2000, 2001),
#'   embedding = list(NA, c(1, 0, 0))
#' )
#' compute_apd_by_years(df2, year_col = "year", embeddings_col = "embedding")
#'
#' @seealso apd_from_mats, proto_distance_matrix
#' @keywords similarity
#' @export
#' @author GitHub Copilot
#' @family similarity
compute_apd_by_years <- function(
  bert_df,
  year_col = "year",
  embeddings_col = "embedding",
  chunk_size = 5000L
) {
  # Basic validations
  if (!is.data.frame(bert_df)) {
    cli::cli_abort("`bert_df` must be a data.frame or tibble.")
  }
  if (!all(c(year_col, embeddings_col) %in% colnames(bert_df))) {
    cli::cli_abort(
      "`bert_df` must contain columns {year_col} and {embeddings_col}."
    )
  }

  # Build per-year embedding matrices: list of numeric matrices (n_sentences x dim)
  per_year <- bert_df |>
    dplyr::filter(!is.na(.data[[embeddings_col]])) |>
    dplyr::group_by(year = .data[[year_col]]) |>
    dplyr::summarise(
      emb_mat = list({
        # coerce list of numeric vectors -> numeric matrix (rows = sentences)
        vecs <- .data[[embeddings_col]]
        if (length(vecs) == 0L) {
          matrix(numeric(0), nrow = 0, ncol = 0)
        } else {
          # ensure all vectors have the same length
          lens <- vapply(vecs, length, integer(1))
          if (length(unique(lens)) != 1L) {
            cli::cli_abort(
              "Embeddings for year {unique(year)} have inconsistent dimensions."
            )
          }
          do.call(rbind, vecs)
        }
      }),
      n = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::arrange(year)

  # If no years remain, return empty matrix
  if (nrow(per_year) == 0L) {
    cli::cli_alert_info(
      "No years with embeddings found; returning empty matrix."
    )
    return(matrix(NA_real_, nrow = 0, ncol = 0))
  }

  years <- as.character(per_year$year)
  n_years <- length(years)
  M <- matrix(NA_real_, n_years, n_years, dimnames = list(years, years))

  total_sentences <- sum(per_year$n, na.rm = TRUE)
  n_empty_years <- sum(per_year$n == 0L)
  cli::cli_alert_info(
    "Found {n_years} years with a total of {total_sentences} sentences; {n_empty_years} empty years will be skipped for APD computation."
  )

  # Identify non-empty years to avoid unnecessary work / NA results
  non_empty_idx <- which(per_year$n > 0L)
  if (length(non_empty_idx) < 2L) {
    cli::cli_alert_info(
      "Not enough non-empty years ({length(non_empty_idx)}) to compute pairwise APD; returning matrix with NA diagonals."
    )
    return(M)
  }

  # Build list of unordered pairs to compute so we can show a single progress bar
  pairs_mat <- utils::combn(non_empty_idx, 2L)
  total_pairs <- ncol(pairs_mat)

  cli::cli_progress_bar("Computing APD across year pairs", total = total_pairs)
  on.exit(cli::cli_progress_done(), add = TRUE)

  # Loop over pairs (vectorized chunking handled inside apd_from_mats)
  for (k in seq_len(total_pairs)) {
    i <- pairs_mat[1L, k]
    j <- pairs_mat[2L, k]

    Ai <- per_year$emb_mat[[i]]
    Bj <- per_year$emb_mat[[j]]

    # defensive checks (shouldn't be necessary because we filtered non_empty_idx)
    if (nrow(Ai) == 0L || nrow(Bj) == 0L) {
      cli::cli_progress_update()
      next
    }

    val <- apd_from_mats(Ai, Bj, chunk_size = as.integer(chunk_size))
    M[i, j] <- val
    M[j, i] <- val

    cli::cli_progress_update()
  }

  cli::cli_alert_success("Computed APD for {total_pairs} year pairs.")

  M
}

# Mean pairwise cosine distance between rows of A and B, vectorized
#' @title Average Pairwise Distance (APD) between two sets of row-vectors
#' @description
#' Compute the average pairwise distance (APD) between the rows of two numeric
#' matrices based on cosine similarity. APD is defined as the mean of
#' (1 - cosine_similarity) over all row pairs (one row from `A`, one row from `B`).
#'
#' @param A numeric matrix with rows representing vectors (embedding matrix).
#'   Expected shape: numeric matrix with `ncol(A) = d` (d >= 1) and `nrow(A) >= 0`.
#'   Rows may contain zeros; behavior for zero-norm rows depends on the helper
#'   `.row_normalize` (see Implementation notes). NA values in `A` will typically
#'   propagate to the result or produce errors during normalization/multiplication.
#' @param B numeric matrix with rows representing vectors (embedding matrix).
#'   Expected shape: numeric matrix with `ncol(B) = d` (must match `ncol(A)`)
#'   and `nrow(B) >= 0`. See `A` for NA/zero-handling notes.
#' @param chunk_size integer scalar (positive) controlling the number of rows of
#'   `A` processed per block when computing similarities. Default `5000L`.
#'   Must be a positive integer; non-positive or non-integer values will cause
#'   underlying functions (e.g. `seq.int`) to error. Chunking trades memory
#'   for repeated matrix multiplies (smaller `chunk_size` uses less memory).
#'
#' @return
#' Numeric scalar (double) equal to the APD:
#' the mean value of `1 - cosine(a_i, b_j)` across all `i=1..nrow(A)`,
#' `j=1..nrow(B)`. If either `A` or `B` has zero rows (`nrow(...) == 0`),
#' the function returns `NA_real_` because the APD is undefined in that case.
#' If matrix dimensions are incompatible (different `ncol`), the function will
#' error when attempting matrix multiplication.
#'
#' @details
#' At a high level, this function:
#' - row-normalizes `A` and `B` so each row has unit (or defined) norm,
#' - computes cosine similarities between rows of `A` and `B` in memory-bounded
#'   chunks, and
#' - returns the average of `1 - cosine_similarity` across all cross-pairs.
#'
#' The APD computed is:
#' \deqn{APD(A,B) = \frac{1}{|A||B|} \sum_{i=1}^{|A|}\sum_{j=1}^{|B|} \left[1 - \cos(a_i, b_j)\right],}
#' where \eqn{\cos(a_i, b_j)} is the cosine similarity between row vectors
#' `a_i` (from `A`) and `b_j` (from `B`).
#'
#' Implementation notes:
#' - High-level algorithm and major steps:
#'   1. Call `row_normalize(A)` and `row_normalize(B)` to (attempt to)
#'      normalize each row to unit length. The function relies on this helper
#'      to handle zero-norm rows or to signal errors for invalid input.
#'   2. If either matrix has zero rows after normalization (`nrow(A) == 0` or
#'      `nrow(B) == 0`), return `NA_real_` because no pairwise distances exist.
#'   3. Iterate over `A` in blocks of `chunk_size` rows. For each block `Ai`,
#'      compute `S_chunk <- Ai %*% t(B)` which yields pairwise cosine
#'      similarities for that block vs all rows of `B`. Accumulate
#'      `sum(1 - S_chunk)` across blocks and divide by `nrow(A) * nrow(B)` at the end.
#' - Memory and performance:
#'   - The chunking strategy bounds memory by materializing only one similarity
#'     block at a time (size `min(chunk_size, nrow(A)) x nrow(B)`).
#'   - Time complexity is O(nrow(A) * nrow(B) * d) where `d = ncol(A)`.
#'   - Choosing `chunk_size` trades memory (larger = fewer matrix multiplies)
#'     for peak memory usage.
#' - Assumptions and preconditions:
#'   - `A` and `B` are numeric matrices with the same number of columns.
#'   - `.row_normalize` is available in the environment and performs row-wise
#'     normalization (it must not silently drop rows; it should preserve row
#'     counts or the function's NA check will not behave as intended).
#' - Edge-case handling and failure modes:
#'   - Returns `NA_real_` if either matrix has zero rows (undefined APD).
#'   - If `A` or `B` contains rows with zero norm, the result depends on
#'     `row_normalize`'s behavior (e.g. it may return zero rows, `NaN`s, or
#'     error). If `row_normalize` produces non-finite values, matrix
#'     multiplication and the sum will propagate them.
#'   - If `ncol(A) != ncol(B)` the `%*%` operation will error.
#' - Alternatives and trade-offs:
#'   - One could compute full similarity matrix in-memory when data is small,
#'     avoiding repeated multiplications; chunking is chosen here for
#'     scalability to larger datasets.
#' - Dependencies and side-effects:
#'   - Uses base R matrix multiplication. Requires a `row_normalize` helper
#'     function to exist in scope. The function does not mutate global state
#'     or write files.
#'
#' @implementation
#' Blocked matrix multiplication over `A` rows: normalize rows -> iterate blocks
#' of `A` -> compute `Ai %*% t(B)` -> accumulate `sum(1 - similarities)` ->
#' divide by total number of pairs. This minimizes peak memory while remaining
#' straightforward and numerically stable for typical dense numeric matrices.
#'
#' @examples
#' # normal case: small random matrices (rows are vectors)
#' set.seed(1)
#' A <- matrix(rnorm(6), nrow = 2) # 2 x 3
#' B <- matrix(rnorm(9), nrow = 3) # 3 x 3
#' # assume .row_normalize exists and normalizes rows; for example:
#' .row_normalize <- function(m) {
#'   if (nrow(m) == 0) return(m)
#'   norms <- sqrt(rowSums(m * m))
#'   # avoid division by zero: leave zero rows as zeros
#'   nz <- norms > 0
#'   m[nz, , drop = FALSE] <- m[nz, , drop = FALSE] / norms[nz]
#'   m
#' }
#' apd_from_mats(A, B, chunk_size = 1L)
#'
#' # edge case: one input has zero rows -> returns NA_real_
#' A0 <- matrix(numeric(0), nrow = 0, ncol = 3)
#' apd_from_mats(A0, B)
#'
#' # edge case: zero-norm row (depends on .row_normalize handling)
#' A_zero <- rbind(c(0, 0, 0), c(1, 0, 0))
#' apd_from_mats(A_zero, B, chunk_size = 2L)
#'
#' @author GitHub Copilot
#' @keywords internal
#' @family similarity
#' @seealso base::`%*%`, stats::`dist`
apd_from_mats <- function(A, B, chunk_size = 5000L) {
  A <- row_normalize(A)
  B <- row_normalize(B)
  nA <- nrow(A)
  nB <- nrow(B)
  if (nA == 0L || nB == 0L) {
    return(NA_real_)
  } # undefined if any side empty or all-zero

  # Chunk over the larger side to bound memory of the similarity matrix
  # Computes mean(1 - S) without materializing all chunks at once
  total_pairs <- as.double(nA) * as.double(nB)
  sum_one_minus_cos <- 0.0

  # choose chunking on A
  idx_starts <- seq.int(1L, nA, by = chunk_size)
  for (s in idx_starts) {
    e <- min(s + chunk_size - 1L, nA) # end index for this chunk
    Ai <- A[s:e, , drop = FALSE]
    S_chunk <- Ai %*% t(B) # cosine similarities
    sum_one_minus_cos <- sum_one_minus_cos + sum(1 - S_chunk)
  }
  sum_one_minus_cos / total_pairs
}

#' Extract APD series for a given anchor year
#'
#' @title Anchor series from APD matrix
#' @description
#' Extracts the Average Pairwise Distance (APD) values comparing every year
#' in an APD matrix to a specified anchor year, returning a tidy two-column
#' tibble of `year` and `apd`.
#'
#' @param APD numeric matrix. A matrix (usually square) whose row names and
#'   column names are years (character). Rows represent source years and
#'   columns represent target/anchor years. NA values are allowed.
#' @param anchor_year integer scalar or character scalar. Year to use as the
#'   anchor (e.g. `1920` or `"1920"`). Must match a row name (or a row name
#'   coercible to integer). If not found the function errors.
#'
#' @return A tibble with two columns:
#'   - `year` (integer): the compared year,
#'   - `apd` (numeric): APD between `year` and `anchor_year`.
#'   Rows with `NA` APD are removed and the anchor year itself is omitted.
#'   If all comparisons to the anchor are `NA` the function returns a zero-row
#'   tibble with the correct columns.
#'
#' @details
#' The function looks up the anchor along both rows and columns of `APD` and
#' coalesces the row-wise and column-wise comparisons so it works when the
#' matrix stores comparisons in either orientation or is non-square.
#'
#' Implementation notes:
#' - Validate that `APD` has row names and that `anchor_year` is present (or
#'   coercible to a present row name). The function errors early with a clear
#'   message if these preconditions are unmet.
#' - Coerce `anchor_year` to character for lookup; extract the anchor row (if
#'   present) and the anchor column (if present). Either may be missing.
#' - Use `dplyr::coalesce()` to combine the row and column numeric vectors so
#'   the first non-missing value is used for each compared year.
#' - Build a tibble, drop `NA` APD entries and the anchor row itself, and
#'   return results ordered by year.
#' - Dependencies: uses `tibble::tibble()` and `dplyr::coalesce()`; it does not
#'   mutate global state.
#'
#' Edge cases and failure modes:
#' - Errors if `APD` has no row names or if `anchor_year` is not found among
#'   the row names (after integer coercion).
#' - If anchor row/column exists but all values are `NA`, the returned tibble
#'   will have zero rows.
#'
#' @implementation See the "Implementation notes" subsection in @details for a
#' step-by-step description of the algorithm.
#' @examples
#' # Normal case: small square APD matrix with years 1920:1922
#' APD <- matrix(
#'   c(0, 0.1, 0.2,
#'     0.1, 0, 0.3,
#'     0.2, 0.3, 0),
#'   nrow = 3, byrow = TRUE
#' )
#' rownames(APD) <- colnames(APD) <- as.character(1920:1922)
#' anchor_series_from_apd(APD, 1921)
#'
#' # Edge case: anchor present but all comparisons are NA -> returns zero-row tibble
#' APD2 <- APD
#' APD2["1921", ] <- NA_real_
#' APD2[, "1921"] <- NA_real_
#' anchor_series_from_apd(APD2, "1921")
#'
#' @keywords internal
#' @family apd drift
#' @author
#' agoutsmedt
anchor_series_from_apd <- function(APD, anchor_year) {
  # Read row names (string years)
  yrs_chr <- rownames(APD)

  # Validate prerequisites with informative errors
  if (is.null(yrs_chr)) {
    stop("APD must have row names representing years", call. = FALSE)
  }

  # Allow anchor as integer or character matching row names (coerced)
  anchor_present <- (as.character(anchor_year) %in% yrs_chr) ||
    (anchor_year %in% as.integer(yrs_chr))

  if (!anchor_present) {
    stop(
      "anchor_year '",
      anchor_year,
      "' is not present in APD row names: ",
      paste(head(yrs_chr, 10), collapse = ", "),
      call. = FALSE
    )
  }

  # Coerce anchor to character for direct matrix lookup
  a <- as.character(anchor_year)

  # Extract anchor row if present, otherwise produce NA vector matching columns.
  # This handles APD matrices that store comparisons row-wise.
  row_vec <- if (a %in% rownames(APD)) {
    APD[a, , drop = TRUE]
  } else {
    rep(NA_real_, ncol(APD))
  }

  # Extract anchor column if present, otherwise produce NA vector matching rows.
  # This handles APD matrices that store comparisons column-wise.
  col_vec <- if (a %in% colnames(APD)) {
    APD[, a, drop = TRUE]
  } else {
    rep(NA_real_, nrow(APD))
  }

  # Combine row-wise and column-wise comparisons: prefer the first non-missing
  # value for each year (useful if matrix is asymmetric or non-square).
  v <- dplyr::coalesce(as.numeric(row_vec), as.numeric(col_vec))

  # Build tidy result: `year` as integer, `apd` numeric; drop NAs and the anchor itself,
  # and return ordered by year.
  tibble::tibble(
    year = as.integer(yrs_chr),
    apd = v
  ) |>
    dplyr::filter(!is.na(apd), year != as.integer(anchor_year)) |>
    dplyr::arrange(year)
}

#' Rank sentence drivers for a year pair by projection onto the year-to-year drift
#'
#' @title Rank driver sentences for a year pair
#'
#' @description
#' For a consecutive year pair (t, t+1) compute the unit change direction
#' between representative vectors in `mat`, project sentence embeddings from
#' each year onto that direction and return the top driving sentences from the
#' earlier and later year (those that most strongly project against or with the
#' direction).
#'
#' @param mat numeric matrix. Representative vectors with rows = years and
#'   columns = embedding dimensions. Row names must be character year labels
#'   (e.g. `"2000"`). `mat` must be finite numeric; rows with `NA` or
#'   inconsistent lengths are not accepted.
#' @param year_t integer scalar. Start year `t` for the pair `(t, t+1)`.
#'   Coerced to integer. Error if either `t` or `t+1` is not present in
#'   `rownames(mat)`.
#' @param data_path character scalar or NULL. Base path where per-year sentence
#'   feather files live under `sentences_embeddings/`. If `NULL` the option
#'   `ejhet.data_path` is consulted and, if missing, `here::here()` is used.
#'   Files are expected at `file.path(data_path, "sentences_embeddings",
#'   glue::glue("sentence_embeddings_{yr}.feather"))`.
#' @param year_col character scalar. Column name in the per-year files that
#'   contains the year identifier. Default: `"year"`. Must exist
#'   in the feather files; values are used to filter rows for the requested year.
#' @param embedding_col character scalar. Name of the list-column holding numeric
#'   embedding vectors (each element a numeric vector of length `ncol(mat)`).
#'   Default: `"embedding"`. Missing or non-list columns cause an error.
#' @param top_n integer scalar >= 1. Number of top drivers to return from each
#'   year. If fewer rows are available the function returns all available rows.
#'   Default: `50L`. Non-integer values are coerced with `as.integer()`.
#' @param normalize_rows logical scalar. If `TRUE` sentence embeddings are
#'   row-normalised (L2) before projection; zero-length rows are left as zeros
#'   (their norm treated as 1 to avoid division-by-zero). Default: `TRUE`.
#' @param chunk_threshold integer scalar. When a year's sentence table contains
#'   more than this many rows, processing is done in on-disk chunks of this
#'   size to bound memory. Default: `200000L`. Must be positive.
#'
#' @return A tibble with the top driver rows from the earlier (`type = "old"`)
#'   and later (`type = "new"`) year. Columns retained (when present in the
#'   source files) include `id` (same type as in files), the year column named
#'   by `year_col` (returned as `year`), `sentence` (character),
#'   and `projection_score` (numeric). The tibble has an attribute `"dir_vec"`
#'   containing the numeric unit direction vector used for projection (length =
#'   `ncol(mat)`). If no drift is detected the function returns a tibble with
#'   zero rows and `attr(..., "dir_vec")` set to a numeric `NA` vector of the
#'   appropriate length; in this case `projection_score` values would be `NA`.
#'
#' @details
#' The function identifies which sentences best explain the change from year
#' `t` to `t+1` by projecting sentence embeddings onto the direction vector
#' between the two representative vectors. It reads per-year embedding files on
#' disk (Feather via `arrow::read_feather()`), computes projection scores with
#' a matrix multiply (fast and memory-efficient), and returns the top scoring
#' sentences from each year.
#'
#' Implementation notes:
#' - Major steps in the implementation:
#'   1. Validate `mat` and that both `t` and `t+1` are present in `rownames(mat)`.
#'   2. Compute the change vector Δ = rep_{t+1} - rep_{t} and its L2 norm.
#'      If the norm is zero or not finite the function emits a warning and
#'      returns an empty result with `dir_vec` set to `NA_real_`.
#'   3. Build a numeric matrix of sentence embeddings for a year by unlisting
#'      the `embedding_col` and reshaping into a matrix (`matrix(..., byrow = TRUE)`).
#'      The helper `build_matrix()` validates embedding lengths and optionally
#'      normalises rows. Zero-length sentence embeddings are protected by
#'      replacing zero norms with 1 before division so they remain zero vectors.
#'   4. Score sentences by computing `scores = embeddings_matrix %*% dir_vec`.
#'      Using a single matrix multiplication per chunk is considerably faster
#'      than iterating per row.
#'   5. When a year's table is large (`nrow > chunk_threshold`) the file's rows
#'      are processed in chunks; per-chunk top candidates are kept and merged
#'      to maintain only the `top_n` best rows (streaming top-k).
#'   6. Combine the top `old` and `new` drivers, attach `dir_vec` as an
#'      attribute and return the result.
#'
#' - Important assumptions and preconditions:
#'   * Each element in the `embedding_col` list-column is a numeric vector of
#'     length equal to `ncol(mat)`. Inconsistent lengths raise an error.
#'   * The per-year Feather files exist and contain the requested columns.
#'   * The function relies on `arrow`, `here`, `glue`, `dplyr`, `tibble`, and
#'     `rlang` being available at runtime.
#'
#' - Edge-case handling & failure modes:
#'   * Missing files or missing columns cause an immediate error with a
#'     descriptive message.
#'   * Identical representative vectors (zero Δ) cause an early warning and an
#'     empty tibble return (with `dir_vec = NA`).
#'   * If rows contain `NA` projection scores they are filtered out before
#'     ranking.
#'   * If `top_n` exceeds available rows the function returns all available
#'     rows (no padding).
#'
#' - Trade-offs:
#'   * The implementation favours streaming and chunking to limit peak memory at
#'     the cost of repeated matrix multiplies when chunking is necessary.
#'   * Normalising sentence rows improves comparability to unit-direction vectors
#'     but may be skipped by setting `normalize_rows = FALSE`.
#'
#' @implementation
#' Vectorised projection pipeline:
#' - Compute `dir_vec` = (rep_{t+1} - rep_t) / ||...||.
#' - For each year: read feather file, filter rows for that year, convert the
#'   embedding list-column to a numeric matrix, optionally normalize rows,
#'   compute `scores = emb_mat %*% dir_vec`, and keep top-K by sorting.
#' - For large tables, process sequential chunks, keep per-chunk top-K and
#'   merge to retain global top-K (streaming top-k).
#'
#' @examples
#' # Minimal runnable example
#' data_path <- tempdir()
#' dir.create(file.path(data_path, "sentences_embeddings"), showWarnings = FALSE)
#' df2000 <- tibble::tibble(
#'   id = 1L,
#'   year = 2000L,
#'   sentence = "old sense",
#'   embedding = list(c(0, 0, 1))
#' )
#' df2001 <- tibble::tibble(
#'   id = 2L,
#'   year = 2001L,
#'   sentence = "new sense",
#'   embedding = list(c(0, 1, 0))
#' )
#' arrow::write_feather(df2000, file.path(data_path, "sentences_embeddings",
#'                                        "sentence_embeddings_2000.feather"))
#' arrow::write_feather(df2001, file.path(data_path, "sentences_embeddings",
#'                                        "sentence_embeddings_2001.feather"))
#' mat <- matrix(c(0, 0, 1, 0, 1, 0), nrow = 2, byrow = TRUE)
#' rownames(mat) <- c("2000", "2001")
#' res <- rank_drivers_for_year_pair(mat, 2000, data_path = data_path,
#'                                   year_col = "year",
#'                                   embedding_col = "embedding", top_n = 1)
#' res
#'
#' @seealso compute_apd_by_years, proto_distance_matrix, plot_semantic_drift,
#'   arrow::read_feather, here::here, glue::glue
#' @keywords utilities drivers
#' @export
#' @author Your Name
rank_drivers_for_year_pair <- function(
  mat,
  year_t,
  data_path = NULL,
  year_col = "year",
  embedding_col = "embedding",
  top_n = 50L,
  normalize_rows = TRUE,
  chunk_threshold = 200000L
) {
  # validate inputs
  if (!is.matrix(mat) && !is.data.frame(mat)) {
    rlang::abort(
      "`mat` must be a matrix or matrix-like object with rownames for years."
    )
  }
  rn <- rownames(mat)
  if (is.null(rn)) {
    rlang::abort("`mat` must have rownames representing years.")
  }
  year_t <- as.integer(year_t)
  year_next <- year_t + 1L
  if (!as.character(year_t) %in% rn || !as.character(year_next) %in% rn) {
    rlang::abort(glue::glue(
      "Years {year_t} or {year_next} not present in `mat` rownames"
    ))
  }

  # resolve data_path
  if (is.null(data_path)) {
    data_path <- getOption("ejhet.data_path", default = here::here())
  }

  cli::cli_inform(glue::glue("Processing year pair {year_t} → {year_next}"))

  # compute direction vector
  delta_t <- as.numeric(mat[as.character(year_next), , drop = TRUE]) -
    as.numeric(mat[as.character(year_t), , drop = TRUE])
  norm_delta <- sqrt(sum(delta_t^2))
  if (!is.finite(norm_delta) || norm_delta == 0) {
    cli::cli_alert_warning(glue::glue(
      "No drift detected between {year_t} and {year_next}"
    ))
    # return empty tibble with expected columns and NA dir_vec attribute
    empty_tbl <- tibble::tibble(
      id = integer(0),
      year = integer(0),
      sentence = character(0),
      projection_score = numeric(0),
      type = character(0)
    )
    attr(empty_tbl, "dir_vec") <- rep(NA_real_, length(delta_t))
    return(empty_tbl)
  }
  dir_vec <- delta_t / norm_delta
  d <- length(dir_vec)

  # helper: build numeric matrix (rows = sentences) from list-column
  build_matrix <- function(emb_list) {
    if (length(emb_list) == 0L) {
      return(matrix(numeric(0), nrow = 0L, ncol = d))
    }
    lens <- vapply(emb_list, length, integer(1))
    if (any(lens != d)) {
      rlang::abort(
        "Inconsistent embedding lengths or mismatch with representative vector dimension"
      )
    }
    # Build matrix by unlisting then shaping by row; this is fast and memory efficient.
    m <- matrix(unlist(emb_list, use.names = FALSE), ncol = d, byrow = TRUE)
    if (normalize_rows && nrow(m) > 0L) {
      # Compute row L2 norms and avoid division by zero by replacing zeros with 1.
      rnms <- sqrt(rowSums(m * m))
      rnms[rnms == 0] <- 1
      m <- m / rnms
    }
    m
  }

  # helper: read/process one year and return top candidates (keeps only requested columns)
  process_year <- function(
    yr,
    direction = c("old", "new"),
    top_n_local = top_n
  ) {
    direction <- match.arg(direction)
    path <- here::here(
      data_path,
      "sentences_embeddings",
      glue::glue("sentence_embeddings_{yr}.feather")
    )
    if (!file.exists(path)) {
      rlang::abort(glue::glue("No sentence file found for year {yr}: {path}"))
    }

    tbl <- arrow::read_feather(path)
    if (!year_col %in% colnames(tbl)) {
      rlang::abort(glue::glue(
        "Year column '{year_col}' not found in file for {yr}"
      ))
    }
    if (!embedding_col %in% colnames(tbl)) {
      rlang::abort(glue::glue(
        "Embedding column '{embedding_col}' not found in file for {yr}"
      ))
    }

    tbl <- tibble::as_tibble(tbl) |> dplyr::filter(.data[[year_col]] == yr)
    n_total <- nrow(tbl)
    if (n_total == 0L) {
      return(
        tbl |>
          dplyr::mutate(projection_score = numeric(0)) |>
          dplyr::slice_head(n = 0)
      )
    }

    score_and_select <- function(df_chunk) {
      emb_mat <- build_matrix(df_chunk[[embedding_col]])
      scores <- if (nrow(emb_mat) == 0L) {
        numeric(0)
      } else {
        # Matrix multiplication projects every row onto dir_vec in one fast operation.
        as.numeric(emb_mat %*% dir_vec)
      }
      df_chunk$projection_score <- scores
      df_chunk[[embedding_col]] <- NULL
      df_chunk |> dplyr::filter(!is.na(.data$projection_score))
    }

    if (n_total <= chunk_threshold) {
      out <- score_and_select(tbl)
      if (nrow(out) == 0L) {
        return(out |> dplyr::slice_head(n = 0))
      }
      if (direction == "old") {
        out <- out |>
          dplyr::arrange(projection_score) |>
          utils::head(top_n_local)
      } else {
        out <- out |>
          dplyr::arrange(dplyr::desc(projection_score)) |>
          utils::head(top_n_local)
      }
      return(out)
    }

    # large file: process in chunks and keep running top_n_local
    starts <- seq.int(1L, n_total, by = chunk_threshold)
    best_tbl <- NULL

    for (s in starts) {
      e <- min(s + chunk_threshold - 1L, n_total)
      chunk <- tbl[s:e, , drop = FALSE]
      scored <- score_and_select(chunk)
      if (nrow(scored) == 0L) {
        next
      }

      if (direction == "old") {
        scored_best <- scored |>
          dplyr::arrange(projection_score) |>
          utils::head(top_n_local)
      } else {
        scored_best <- scored |>
          dplyr::arrange(dplyr::desc(projection_score)) |>
          utils::head(top_n_local)
      }

      best_tbl <- if (is.null(best_tbl)) {
        scored_best
      } else {
        cand <- dplyr::bind_rows(best_tbl, scored_best)
        if (direction == "old") {
          cand |> dplyr::arrange(projection_score) |> utils::head(top_n_local)
        } else {
          cand |>
            dplyr::arrange(dplyr::desc(projection_score)) |>
            utils::head(top_n_local)
        }
      }
      rm(chunk, scored, scored_best)
      gc()
    }

    if (is.null(best_tbl)) {
      return(
        tbl |>
          dplyr::slice_head(n = 0) |>
          dplyr::mutate(projection_score = numeric(0))
      )
    }
    best_tbl
  }

  # process both years sequentially to limit memory
  tbl_t <- process_year(year_t, direction = "old", top_n_local = top_n)
  drivers_old <- tbl_t |>
    dplyr::arrange(projection_score) |>
    utils::head(top_n) |>
    dplyr::select(dplyr::any_of(c(
      "id",
      year_col,
      "sentence",
      "projection_score"
    ))) |>
    dplyr::rename(year = dplyr::any_of(year_col)) |>
    dplyr::mutate(type = "old")
  rm(tbl_t)
  gc()

  tbl_tp1 <- process_year(year_next, direction = "new", top_n_local = top_n)
  drivers_new <- tbl_tp1 |>
    dplyr::arrange(dplyr::desc(projection_score)) |>
    utils::head(top_n) |>
    dplyr::select(dplyr::any_of(c(
      "id",
      year_col,
      "sentence",
      "projection_score"
    ))) |>
    dplyr::rename(year = dplyr::any_of(year_col)) |>
    dplyr::mutate(type = "new")
  rm(tbl_tp1)
  gc()

  result <- dplyr::bind_rows(drivers_old, drivers_new)
  attr(result, "dir_vec") <- dir_vec
  result
}

#' @title Process multiple year-centroid matrices to rank sentence drivers
#' @description
#' Run `rank_drivers_for_year_pair()` over a set of named year-by-dimension matrices,
#' persist per-year results to disk, and combine per-matrix outputs into a single
#' data.table per matrix. This function is resume-friendly: it skips years already
#' processed on disk.
#' @param matrices named list of numeric matrices. Each matrix must have rownames
#'   that represent years (e.g., `"1900"`, `"1901"`). Rows are years, columns are
#'   embedding dimensions. NA rownames or non-integer year names are ignored.
#' @param data_path character scalar. Base path where per-matrix output directories
#'   and combined RDS files are written. Must be writable. NA not allowed.
#' @param jstor_data_path character scalar. Path forwarded to
#'   `rank_drivers_for_year_pair()` via `data_path` argument; typically the dataset
#'   root. NA not allowed.
#' @param years_range integer vector. Years to consider for processing (default
#'   1900:2008). Years are intersected with matrix rownames and with already
#'   processed years on disk.
#' @return
#' Invisibly returns a named list (same names as `matrices`) of length equal to
#' `length(matrices)`. Each element is either:
#' - a `data.table` containing the combined per-year driver results for that matrix
#'   (with a column `year_pair_start` and `sentence_id`), or
#' - `NULL` if no per-year results were available to combine.
#' The function also writes per-year files named `drivers_<YEAR>.rds` inside
#' `file.path(data_path, paste0("top_sentence_drivers_year_pairs_", <name>))`
#' and a combined RDS `top_sentence_drivers_all_years_<name>.rds` in `data_path`.
#' @details
#' This helper automates running `rank_drivers_for_year_pair()` across several
#' year-centroid matrices and persists intermediate and combined results. It is
#' intentionally conservative: it checks for existing per-year and combined files
#' and skips work already done to support resumable long-running workflows.
#'
#' Side-effects:
#' - creates per-matrix directories under `data_path` (if missing),
#' - writes per-year RDS files (`drivers_<YEAR>.rds`),
#' - writes one combined RDS per matrix (`top_sentence_drivers_all_years_<name>.rds`).
#'
#' Implementation notes:
#' - High-level algorithm:
#'   1. Validate inputs and iterate over named matrices.
#'   2. For each matrix, determine available years from `rownames(mat)`.
#'   3. Determine which years still need processing by comparing `years_range`,
#'      available years, and already written per-year files in the output directory.
#'   4. For each year to process, call `rank_drivers_for_year_pair()` and write
#'      the result to `drivers_<YEAR>.rds`. Errors from the ranking function are
#'      caught and logged; processing continues.
#'   5. After per-year files are present, read them all, bind into a single
#'      `data.table` (with `idcol = "year_pair_start"`), assign `sentence_id`
#'      and save the combined file.
#' - Assumptions and preconditions:
#'   - `matrices` is a named list and each matrix rownames (if present) are parseable
#'     as integers representing years.
#'   - `rank_drivers_for_year_pair()` exists in the environment and returns an
#'     object coercible to a `data.table`/data.frame.
#' - Edge-case handling and failure modes:
#'   - If `rank_drivers_for_year_pair()` errors for a year, the error is logged
#'     and processing continues; that year is not saved.
#'   - If no per-year files are present for a matrix, the function returns `NULL`
#'     for that matrix and logs a warning.
#' - Trade-offs:
#'   - The function writes per-year outputs to disk to enable resuming and avoid
#'     re-running expensive work; this increases I/O but improves robustness.
#' - Dependencies:
#'   - Relies on `glue`, `stringr`, `purrr`, `data.table`, and `cli` for logging and
#'     file handling; these packages must be available at runtime.
#' - Global state mutated:
#'   - Creates directories and writes RDS files under `data_path`.
#' @implementation
#' The implementation favors simplicity and resumability: file-existence checks
#' are used to skip work, `tryCatch()` isolates failures per-year, and results
#' are combined with `data.table::rbindlist()` for performance.
#' @examples
#' # Minimal example: create two tiny matrices for two years and a mock ranker.
#' rank_drivers_for_year_pair <- function(mat, year_t, ..., top_n = 10L) {
#'   # return a small data.frame resembling a driver result
#'   data.frame(
#'     token = paste0("tok_", seq_len(3)),
#'     projection_score = runif(3),
#'     stringsAsFactors = FALSE
#'   )
#' }
#'
#' m1 <- matrix(runif(4), nrow = 2, dimnames = list(c("2000", "2001"), NULL))
#' m2 <- matrix(runif(4), nrow = 2, dimnames = list(c("2000", "2001"), NULL))
#' tmp <- tempdir()
#' res <- process_matrices_for_drivers(
#'   matrices = list(a = m1, b = m2),
#'   data_path = tmp,
#'   jstor_data_path = tmp,
#'   years_range = 2000:2001
#' )
#' str(res)
#' @seealso rank_drivers_for_year_pair, readRDS, saveRDS, data.table::rbindlist
#' @family drivers
#' @keywords internal
process_matrices_for_drivers <- function(
  matrices,
  data_path,
  jstor_data_path,
  years_range = 1900:2008
) {
  stopifnot(is.list(matrices), length(matrices) > 0)
  combined_results <- list()

  for (nm in names(matrices)) {
    mat_i <- matrices[[nm]]

    # create a per-matrix output directory (idempotent)
    output_dir <- file.path(
      data_path,
      glue::glue("top_sentence_drivers_year_pairs_{nm}")
    )
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

    # extract available years from matrix rownames; ignore NA or missing rownames
    years_available <- if (!is.null(rownames(mat_i))) {
      as.integer(rownames(mat_i))
    } else {
      integer(0)
    }
    years_available <- years_available[!is.na(years_available)]

    # determine years already processed by reading filenames in output_dir
    years_already_processed <- list.files(
      output_dir,
      pattern = "^drivers_\\d{4}\\.rds$",
      full.names = FALSE
    ) %>%
      stringr::str_extract("\\d{4}") %>%
      as.integer()

    # years to process = intersection of requested range and available years,
    # excluding years already processed
    years_to_process <- intersect(years_range, years_available) |>
      setdiff(years_already_processed)
    processed_files <- character(0)

    for (yr in years_to_process) {
      cli::cli_inform(glue::glue("[{nm}] Starting year {yr}"))
      out_path <- file.path(output_dir, glue::glue("drivers_{yr}.rds"))

      if (file.exists(out_path)) {
        # redundant check to avoid race-conditions if a file appeared between listing and loop
        cli::cli_inform(glue::glue(
          "[{nm}] Skipping {yr} — output exists at {out_path}"
        ))
        processed_files <- c(processed_files, out_path)
        next
      }

      # isolate errors/warnings from the ranking function so processing can continue
      res <- tryCatch(
        {
          rank_drivers_for_year_pair(
            mat = mat_i,
            year_t = yr,
            year_col = "year",
            embedding_col = "embedding",
            top_n = 200L,
            normalize_rows = TRUE,
            chunk_threshold = 100000L,
            data_path = jstor_data_path
          )
        },
        error = function(e) {
          cli::cli_alert_danger(glue::glue(
            "[{nm}] Error processing {yr}: {e$message}"
          ))
          NULL
        },
        warning = function(w) {
          cli::cli_alert_warning(glue::glue(
            "[{nm}] Warning processing {yr}: {w$message}"
          ))
          invokeRestart("muffleWarning")
        }
      )

      if (is.null(res)) {
        next
      }

      saveRDS(res, out_path)
      processed_files <- c(processed_files, out_path)

      # free memory promptly for long loops
      rm(res)
      gc()
      cli::cli_inform(glue::glue("[{nm}] Saved results for {yr} → {out_path}"))
    }

    # combine per-year files into single RDS for this matrix if not already combined
    combined_path <- file.path(
      data_path,
      glue::glue("top_sentence_drivers_all_years_{nm}.rds")
    )
    if (!file.exists(combined_path) && length(processed_files) > 0) {
      all_processed_files <- list.files(
        output_dir,
        pattern = "^drivers_\\d{4}\\.rds$",
        full.names = TRUE
      )

      # extract years from filenames to use as names when binding
      years_processed <- all_processed_files %>%
        stringr::str_extract("\\d{4}") %>%
        as.integer()

      # read all per-year RDS files into a list
      all_list <- purrr::map(all_processed_files, readRDS)
      names(all_list) <- paste0(years_processed)

      # bind into a single data.table with an id column 'year_pair_start'
      all_list <- data.table::rbindlist(all_list, idcol = "year_pair_start")
      all_list[, sentence_id := .I]
      data.table::setDT(all_list, key = "sentence_id")

      saveRDS(all_list, combined_path)
      cli::cli_inform(glue::glue(
        "[{nm}] Combined file written to {combined_path}"
      ))
      combined_results[[nm]] <- all_list
    } else if (file.exists(combined_path)) {
      # load existing combined file to return
      combined_results[[nm]] <- readRDS(combined_path)
      cli::cli_inform(glue::glue(
        "[{nm}] Loaded combined file from {combined_path}"
      ))
    } else {
      cli::cli_alert_warning(glue::glue(
        "[{nm}] No processed files found to combine."
      ))
      combined_results[[nm]] <- NULL
    }
  }

  invisible(combined_results)
}

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

#' Heatmap of pairwise prototype distances (years × years)
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

#: Method for text analysis-------------------------

#' Extract n-grams from text with basic filtering and grouping
#'
#' @title Extract n-grams from text
#' @description Tokenise text into n-grams (unigrams, bigrams, etc.) per group, remove
#'   tokens containing digits or stop words, and return a compact data.table of tokens.
#'
#' @param df data.frame or data.table containing the input rows. Must include the columns named
#'   in `grouping_cols` and `text_col`. Note: the function calls `data.table::setDT(df)` and
#'   therefore will convert and mutate `df` by reference; pass `data.table::copy(df)` if you
#'   want to avoid in-place modification.
#' @param ngrams integer scalar or integer vector. If scalar (e.g. `2L`) it is interpreted
#'   as `1:ngrams` (i.e. all n from 1 to that value). If a vector (e.g. `c(1L,2L)`), those
#'   exact n values are used. Values are coerced to integers.
#' @param grouping_cols character vector of column names to keep as grouping keys.
#' These columns are preserved in the output and used to group token rows.
#' @param text_col character scalar. Name of the text column containing sentences to tokenise
#'   (default: `"sentence"`). NA values in the text column are handled as empty input to the
#'   tokenizer (they will not produce tokens).
#' @param min_nchar integer scalar. Minimum number of characters a token must have to be kept.
#'   Defaults to `2L`. Tokens shorter than this are removed.
#' @param stop_words NULL or character vector of words to treat as stop words. If `NULL`
#'   the function uses `tidytext::stop_words$word`. Matching is case-insensitive: all
#'   stop words are lower-cased before comparison.
#'
#' @return A data.table with columns:
#'   - the `grouping_cols` (in the same order as provided),
#'   - `token` (character scalar; multi-word tokens have internal spaces replaced with `_`),
#'   - `ngram` (integer scalar).
#'   Returns an empty data.table with those columns if no tokens survive filtering.
#'   The function throws an error if required packages are missing or if required columns
#'   are not present in `df`.
#'
#' @details This function produces n-grams per row of `df`, preserves the grouping columns,
#'   filters tokens that contain digits or any stop word, and normalises multi-word tokens by
#'   replacing spaces with underscores. It is intended for downstream term-frequency and
#'   TF–IDF computations on grouped text.
#'
#' Implementation notes:
#' - Steps:
#'   1. Validate required namespaces (`tokenizers`, `tidytext`, `stringr`) are available.
#'   2. Convert `df` to a `data.table` in-place (fast, but mutates `df`).
#'   3. Compute the set of `ngram` sizes to generate (either `1:ngrams` when scalar or the
#'      provided vector).
#'   4. For each `n`, call `tokenizers::tokenize_ngrams()` to obtain a list-column of tokens,
#'      then unnest to one token per row.
#'   5. Remove tokens shorter than `min_nchar`, tokens containing digits, or tokens that
#'      contain any stop word component (checked per token word).
#'   6. Replace internal spaces with underscores for multi-word tokens and return a data.table.
#' - Assumptions and preconditions:
#'   - `df` contains the named grouping and text columns.
#'   - `tokenizers::tokenize_ngrams()` returns a list of character vectors per row.
#' - Edge-case handling and failure modes:
#'   - If required packages are not installed the function stops with an informative message.
#'   - If required columns are missing the function stops listing the missing names.
#'   - If no tokens survive filtering the function returns an empty data.table with the
#'     expected column set rather than `NULL`.
#' - Trade-offs:
#'   - The function uses `data.table` for speed and memory efficiency; this also means the
#'     input `df` is modified by reference which can be surprising — callers should copy if
#'     needed.
#' - Dependencies: `tokenizers`, `tidytext`, `stringr`, `data.table`.
#'
#' @implementation Uses `tokenizers::tokenize_ngrams()` for token generation and `data.table`
#'   operations for efficient unnesting and filtering. Stop words are lower-cased and matched
#'   at the component-word level; digits are detected using a simple `grepl("[0-9]", ...)`.
#'
#' @examples
#' # minimal example
#' df <- data.frame(
#'   year_pair_start = c("1900", "1910"),
#'   type = c("new", "old"),
#'   sentence = c("Rationality matters", "A new rational method"),
#'   stringsAsFactors = FALSE
#' )
#' # extract unigrams and bigrams
#' if (requireNamespace("tokenizers", quietly = TRUE)) {
#'   out <- extract_ngrams(df, ngrams = 2L, grouping_cols = c("year_pair_start", "type"))
#'   head(out)
#' }
#'
#' # edge-case: tokens with digits are removed
#' df2 <- data.frame(
#'   year_pair_start = "2000",
#'   type = "new",
#'   sentence = "Model 42 predicts 8 outcomes",
#'   stringsAsFactors = FALSE
#' )
#' if (requireNamespace("tokenizers", quietly = TRUE)) {
#'   extract_ngrams(df2, ngrams = 1L)
#' }
#'
#' @keywords internal
#' @seealso tokenizers::tokenize_ngrams, tidytext::stop_words
#' @author Your Name
extract_ngrams <- function(
  df,
  ngrams = 2L,
  grouping_cols = NULL,
  text_col = "text",
  min_nchar = 2L,
  stop_words = NULL
) {
  # Ensure required packages are available before doing any in-place changes
  if (!requireNamespace("tokenizers", quietly = TRUE)) {
    stop("Please install the 'tokenizers' package.")
  }
  if (!requireNamespace("tidytext", quietly = TRUE)) {
    stop("Please install the 'tidytext' package.")
  }
  if (!requireNamespace("stringr", quietly = TRUE)) {
    stop("Please install the 'stringr' package.")
  }

  # Convert to data.table in-place for performance. This mutates `df` by reference.
  # If the caller wants to preserve the original, they should call data.table::copy(df).
  data.table::setDT(df)

  # Default stop words from tidytext if none provided; normalise to lower-case
  if (is.null(stop_words)) {
    stop_words <- unique(tidytext::stop_words$word)
  }
  stop_words <- tolower(stop_words)

  # Validate required columns exist
  required_cols <- unique(c(
    grouping_cols,
    text_col
  ))
  missing_cols <- setdiff(required_cols, names(df))
  if (length(missing_cols) > 0) {
    stop(
      "Missing required columns in df: ",
      paste(missing_cols, collapse = ", ")
    )
  }

  # Normalize ngrams input: if scalar -> 1:max, else use provided vector
  if (length(ngrams) == 1L) {
    ng_range <- seq_len(as.integer(ngrams))
  } else {
    ng_range <- as.integer(ngrams)
  }

  # For each requested ngram size generate a temporary data.table with a list-column `token`
  token_list <- lapply(ng_range, function(n) {
    # copy only needed columns to keep memory use low (grouping + text)
    tmp <- df[, c(grouping_cols, text_col), with = FALSE]

    # tokenizers::tokenize_ngrams returns a list of character vectors (one element per row).
    # Use get() to refer to the text column by name inside data.table's environment.
    tmp[,
      token := tokenizers::tokenize_ngrams(
        get(text_col),
        n = as.integer(n),
        lowercase = TRUE,
      )
    ]

    # remove the original text column (we only need grouping + token list)
    tmp[, (text_col) := NULL]

    # record the ngram size for later filtering/analysis
    tmp[, ngram := as.integer(n)]

    tmp
  })

  # Stack all ngram tables into one
  tokens <- data.table::rbindlist(token_list, use.names = TRUE, fill = TRUE)

  # Unnest the list-column of tokens into one token per row, preserving grouping + ngram
  # `unlist()` flattens each element. The by= ensures grouping columns remain as columns.
  tokens <- tokens[, .(token = unlist(token)), by = c(grouping_cols, "ngram")]

  # Filter out tokens that are too short
  tokens <- tokens[nchar(token) >= as.integer(min_nchar), ]

  # faster vectorised splitting (stringi is much quicker than base strsplit)
  word_columns <- stringr::str_c("word_", seq_len(max(ng_range)))
  tokens[, (word_columns) := tstrsplit(token, " ", fixed = TRUE)]

  # detect digits in any component word (NA -> FALSE)
  tokens[,
    has_digit := Reduce(
      `|`,
      lapply(.SD, function(x) {
        xi <- as.character(x)
        !is.na(xi) & grepl("[0-9]", xi)
      })
    ),
    .SDcols = word_columns
  ]

  # detect stop words in any component word (stop_words assumed lower-case)
  tokens[,
    has_stop := Reduce(
      `|`,
      lapply(.SD, function(x) {
        xi <- as.character(x)
        !is.na(xi) & (xi %in% stop_words)
      })
    ),
    .SDcols = word_columns
  ]

  # Keep only tokens without digits and without stop words
  tokens <- tokens[!has_digit & !has_stop]

  # Keep only the requested output columns; replace spaces with underscores in multi-word tokens
  tokens <- tokens[, c(grouping_cols, "token", "ngram"), with = FALSE]
  tokens[, token := stringr::str_replace_all(token, " ", "_")]

  # Return the result as a data.table (tokens[] ensures printing semantics in interactive use)
  tokens[]
}

#' Compute TF–IDF (optionally weighted) for tokens per document
#'
#' @title Compute TF–IDF for tokenized data
#' @description
#' Calculate term-frequency (TF), inverse document frequency (IDF) and TF–IDF
#' for tokens across one or more document identifiers. Supports optional
#' per-occurrence numeric `weight_col` to produce weighted TF values.
#'
#' @param df data.frame or data.table. Token-level table where each row
#'   represents a token occurrence. The function coercively copies `df` to a
#'   data.table and does not mutate the caller's object.
#' @param token_col character scalar. Name of the column containing token
#'   strings (single-word or multi-word tokens). Default: `"token"`.
#'   Must be present in `df`. Token values are treated as character.
#' @param document_col character scalar or character vector. Column name(s)
#'   that together identify a document (e.g. `"doc_id"` or `c("year","id")`).
#'   Values are coerced to character and concatenated with a `"\r"` separator
#'   internally when multiple columns are provided. Returned result restores
#'   the original document columns.
#' @param weight_col character scalar or NULL. Optional column name in `df`
#'   containing numeric per-occurrence weights (e.g. token importance). If
#'   provided, values are coerced to numeric, `NA`s are replaced with `0`
#'   (with a single warning), and absolute values are used. Default: `NULL`
#'   (each token occurrence counts as weight = 1).
#'
#' @return A data.table with one row per (token, document) pair and these
#'   columns (names may vary slightly when multiple `document_col` are used):
#'   - token (character): the token (name preserved as `token_col`).
#'   - <document_col(s)>: restored document identifier columns (character or integer-like).
#'   - corpus_tf (integer): total number of occurrences of `token` across the corpus
#'     (unweighted count of rows that contained the token).
#'   - nb_doc_word (numeric): total weight of all tokens in the given document.
#'   - df (integer): number of distinct documents containing the token.
#'   - idf (numeric): inverse document frequency computed as `log(total_docs / df)`.
#'   - tf or weighted_tf (numeric): per-document term frequency; named `weighted_tf`
#'     when `weight_col` was provided (equals token_doc_weight / nb_doc_word).
#'   - tf_idf (numeric): product of `tf` (or `weighted_tf`) and `idf`.
#'
#'   The function returns a `data.table` (visible in examples). If a division by
#'   zero occurs for `nb_doc_word == 0` the resulting `tf` will be `NaN` for that row.
#'
#' @details
#' High-level behaviour:
#' - The input `df` is copied and coerced to `data.table` for efficient grouping.
#' - If multiple `document_col` values are supplied they are combined into a
#'   temporary composite key (separator `"\r"`) for grouping and later split back
#'   into original columns in the result.
#' - When `weight_col` is given the function builds a positive weight `.weight`
#'   from `abs(weight_col)` and treats `NA` as `0` (with a warning). Otherwise
#'   each occurrence contributes weight `1.0`.
#' - Corpus-level frequency `corpus_tf` is computed as the (unweighted) count
#'   of occurrences of each token in `df`.
#' - Per-document weighted sums and document totals are computed and used to
#'   derive `tf`, `idf`, and `tf_idf` where `idf = log(total_docs / df)`.
#'
#' Implementation notes:
#' - Steps implemented in code:
#'   1. Validate presence of `token_col` and `document_col` and coerce types.
#'   2. Create a safe temporary composite document key when multiple document
#'      columns are provided; choose a helper name that does not collide.
#'   3. Standardise the token column to the name `token` internally to simplify
#'      data.table expressions, restoring the original name before returning.
#'   4. Compute `corpus_tf` by token, then compute per-(token,document)
#'      weighted sums (`token_doc_weight`) and per-document totals (`nb_doc_word`).
#'   5. Compute `tf = token_doc_weight / nb_doc_word` (may be NaN if denominator 0),
#'      `df` (number of documents containing token), `idf = log(total_docs / df)`,
#'      and `tf_idf = tf * idf`.
#'   6. Clean helper columns, restore original column names, and return the table.
#'
#' - Assumptions and preconditions:
#'   * `token_col` and all `document_col` names exist in `df`.
#'   * If provided, `weight_col` is coercible to numeric.
#'   * `token_col` must be distinct from every `document_col`.
#'
#' - Edge cases and failure modes:
#'   * Missing required columns triggers an informative `stop()`.
#'   * `weight_col` NA values are replaced with `0` (warning); negative weights
#'     are made positive via `abs()`.
#'   * If `nb_doc_word == 0` for a document the computed `tf` will be `NaN`;
#'     callers should filter these rows if needed.
#'   * If multiple `document_col` are provided, the composite separator `"\r"`
#'     is used; unusual document values containing `"\r"` may lead to unexpected
#'     splitting but this separator was chosen to minimise collisions.
#'
#' - Trade-offs:
#'   * Uses `data.table` for speed and memory efficiency. The function copies the
#'     input to avoid mutating caller data at the cost of an extra allocation.
#'
#' @implementation
#' The implementation relies on grouping operations in `data.table`:
#' compute corpus counts, aggregate per-(token,document) weights, merge
#' document totals, derive TF/IDF, and restore original column names. Weighting
#' is optional and sign-agnostic (absolute values taken).
#'
#' @examples
#' # normal case: simple corpus, unweighted
#' df <- data.frame(
#'   doc_id = c("a", "a", "b", "b", "b"),
#'   token = c("x", "y", "x", "x", "z"),
#'   stringsAsFactors = FALSE
#' )
#' compute_tf_idf(df, document_col = "doc_id", token_col = "token")
#'
#' # weighted example: per-occurrence weights (NA treated as 0)
#' df2 <- data.frame(
#'   doc = c("d1", "d1", "d2"),
#'   token = c("t", "t", "t"),
#'   w = c(2, NA, 1)
#' )
#' compute_tf_idf(df2, document_col = "doc", token_col = "token", weight_col = "w")
#'
#' @keywords internal
#' @author Your Name
compute_tf_idf <- function(
  df,
  token_col = "token",
  document_col = "document",
  weight_col = NULL
) {
  # Coerce to data.table and operate on a copy to avoid mutating caller data.
  df <- data.table::as.data.table(df)
  df <- data.table::copy(df)

  # Ensure inputs are character vectors
  document_col <- as.character(document_col)
  token_col <- as.character(token_col)

  # Validate required columns exist; provide a clear error if not.
  if (!all(document_col %in% colnames(df))) {
    stop(
      "Input must contain document column(s): ",
      paste(document_col, collapse = ", "),
      call. = FALSE
    )
  }
  if (!token_col %in% colnames(df)) {
    stop("Input must contain token column: ", token_col, call. = FALSE)
  }

  # Capture original classes / metadata for document columns so we can restore types later
  orig_classes <- vapply(
    document_col,
    function(col) {
      cl <- class(df[[col]])[1L]
      if (is.null(cl)) "character" else cl
    },
    character(1),
    USE.NAMES = TRUE
  )
  orig_levels <- lapply(document_col, function(col) {
    if (is.factor(df[[col]])) levels(df[[col]]) else NULL
  })
  names(orig_levels) <- document_col
  orig_tzone <- lapply(document_col, function(col) {
    if (inherits(df[[col]], "POSIXt")) attr(df[[col]], "tzone") else NULL
  })
  names(orig_tzone) <- document_col

  # Validate weight column if provided
  if (!is.null(weight_col)) {
    weight_col <- as.character(weight_col)
    if (!weight_col %in% colnames(df)) {
      stop("weight_col '", weight_col, "' not found in input", call. = FALSE)
    }
    # coerce to numeric and replace NA with 0 (warn once)
    if (!is.numeric(df[[weight_col]])) {
      df[, (weight_col) := as.numeric(.SD[[1]]), .SDcols = weight_col]
    }
    if (any(is.na(df[[weight_col]]))) {
      warning("NA values found in weight_col; treating as 0 for weighting")
      df[is.na(get(weight_col)), (weight_col) := 0]
    }
    df[, .weight := abs(df[[weight_col]])] # use absolute value to avoid negative weights
  } else {
    # default unweighted behaviour: weight = 1 per token occurrence (as before)
    df[, .weight := 1.0]
  }

  # Prevent collision: token_col must not be one of the document grouping columns
  if (token_col %in% document_col) {
    stop("`token_col` must be distinct from `document_col`", call. = FALSE)
  }

  # Create a temporary composite document key when multiple document columns are provided.
  # Use a name unlikely to collide with existing columns.
  doc_key <- ".document_tmp_key"
  i <- 1L
  while (doc_key %in% colnames(df)) {
    doc_key <- paste0(".document_tmp_key", i)
    i <- i + 1L
  }

  # Build composite key from the original values coerced to character for safe concatenation.
  if (length(document_col) == 1L) {
    # keep a character representation in doc_key but remember original class to restore later
    df[, (doc_key) := as.character(.SD[[1]]), .SDcols = document_col]
  } else {
    df[,
      (doc_key) := do.call(paste, c(lapply(.SD, as.character), sep = "\r")),
      .SDcols = document_col
    ]
  }

  # Temporarily standardise token column name to `token` to simplify expressions.
  if (token_col != "token") {
    data.table::setnames(df, token_col, "token")
    token_was_renamed <- TRUE
  } else {
    token_was_renamed <- FALSE
  }

  # corpus_tf: total (unweighted) count of appearances of token across all rows
  df[, corpus_tf := .N, by = "token"]

  # Compute per-document total weight (nb_doc_word) and per token-document weighted sum
  doc_totals <- df[, .(nb_doc_word = sum(.weight)), by = doc_key]
  token_doc <- df[,
    .(token_doc_weight = sum(.weight)),
    by = c("token", doc_key, "corpus_tf")
  ]

  # merge nb_doc_word into token_doc to compute tf
  token_doc <- merge(
    token_doc,
    doc_totals,
    by = doc_key,
    sort = FALSE,
    all.x = TRUE
  )

  # tf: weighted token frequency within document (token_doc_weight / nb_doc_word)
  # guard against division by zero (nb_doc_word == 0) — produce NaN which can be filtered downstream
  token_doc[, tf := token_doc_weight / nb_doc_word]

  # Document frequency: number of distinct documents containing each token
  df_dt <- token_doc[, .(df = .N), by = token]

  # total distinct documents
  total_docs <- uniqueN(token_doc[[doc_key]])

  # merge df into token_doc
  token_doc <- merge(token_doc, df_dt, by = "token", all.x = TRUE, sort = FALSE)

  # IDF and TF–IDF (natural log)
  token_doc[, idf := log(total_docs / df)]
  token_doc[, tf_idf := tf * idf]

  # Restore token original name
  if (token_was_renamed) {
    data.table::setnames(token_doc, "token", token_col)
  }

  # Restore original document columns with original types
  if (length(document_col) == 1L) {
    # single column: convert doc_key back to original class
    col <- document_col[1]
    typ <- orig_classes[col]
    if (typ == "integer") {
      token_doc[, (col) := as.integer(get(doc_key))]
    } else if (typ %in% c("numeric", "double")) {
      token_doc[, (col) := as.numeric(get(doc_key))]
    } else if (typ == "logical") {
      token_doc[, (col) := as.logical(get(doc_key))]
    } else if (typ == "factor") {
      token_doc[, (col) := factor(get(doc_key), levels = orig_levels[[col]])]
    } else if (typ == "Date") {
      token_doc[, (col) := as.Date(get(doc_key))]
    } else if (typ %in% c("POSIXct", "POSIXt")) {
      tz <- orig_tzone[[col]]
      token_doc[, (col) := as.POSIXct(get(doc_key), tz = tz)]
    } else {
      # fallback: character
      token_doc[, (col) := as.character(get(doc_key))]
    }
    token_doc[, (doc_key) := NULL]
  } else {
    # multiple columns: split then coerce each to its original class
    token_doc[,
      (document_col) := data.table::tstrsplit(get(doc_key), "\r", fixed = TRUE)
    ]
    token_doc[, (doc_key) := NULL]

    for (col in document_col) {
      typ <- orig_classes[col]
      if (typ == "integer") {
        token_doc[, (col) := as.integer(get(col))]
      } else if (typ %in% c("numeric", "double")) {
        token_doc[, (col) := as.numeric(get(col))]
      } else if (typ == "logical") {
        token_doc[, (col) := as.logical(get(col))]
      } else if (typ == "factor") {
        token_doc[, (col) := factor(get(col), levels = orig_levels[[col]])]
      } else if (typ == "Date") {
        token_doc[, (col) := as.Date(get(col))]
      } else if (typ %in% c("POSIXct", "POSIXt")) {
        tz <- orig_tzone[[col]]
        token_doc[, (col) := as.POSIXct(get(col), tz = tz)]
      } else {
        token_doc[, (col) := as.character(get(col))]
      }
    }
  }

  # Remove helper weight column from result if present
  token_doc[, c("token_doc_weight") := NULL]

  if (!is.null(weight_col)) {
    data.table::setnames(token_doc, "tf", "weighted_tf")
  }

  # Return the data.table with restored column types
  token_doc[]
}

#' Compute and apply a per-group quantile threshold to filter rows
#'
#' @title Filter rows by per-group quantile threshold
#' @description
#' Compute a quantile threshold from a numeric `metric` within each group and
#' return rows whose `metric` exceeds (or is at least) that per-group threshold.
#'
#' @param dt data.table or data.frame. Table of observations. If a `data.table`
#'   is supplied the function may modify it by reference (adds a temporary
#'   `threshold` column). To avoid in-place mutation, pass `data.table::copy(dt)`.
#' @param group_cols character vector. Names of column(s) used to form groups.
#'   Groups are computed with `data.table`'s `by=`. `NA` values in grouping
#'   columns are treated as a distinct group value.
#' @param metric character scalar. Name of the numeric column to compute the
#'   quantile from (default: `"tf"`). Must exist in `dt` and be coercible to
#'   numeric; missing or non-numeric values in the metric are handled by
#'   `quantile(..., na.rm = TRUE)` (groups with all-`NA` produce `NA` threshold).
#' @param probs numeric scalar in (0, 1). Quantile probability used to compute
#'   the threshold (default: `0.75`). Only a single probability is supported.
#' @param inclusive logical scalar. If `TRUE` rows with `metric >= threshold`
#'   are kept; otherwise only rows with `metric > threshold` are kept.
#' @param keep_threshold logical scalar. If `TRUE` the returned table includes
#'   the computed `threshold` column; otherwise the `threshold` column is
#'   removed before returning (default: `FALSE`).
#'
#' @return A `data.table` (same columns as input, possibly plus `threshold`)
#'   containing the subset of rows that satisfy the per-group comparison.
#'   If no rows match the comparison, an empty `data.table` with the same
#'   columns is returned. If a group's quantile is `NA` (e.g. all `metric`
#'   values are `NA`), no rows from that group will be selected because any
#'   comparison with `NA` yields `NA` (treated as `FALSE` for subsetting).
#'
#' @details
#' The function computes a single scalar quantile per group (using
#' `stats::quantile(..., na.rm = TRUE)`) and then filters rows in that group
#' by comparing the row's `metric` to the group threshold. It is designed for
#' simple per-group thresholding (e.g. keep top 25% by some score within each
#' group).
#'
#' Implementation notes:
#' - Steps performed:
#'   1. Coerce `dt` to a `data.table` (no defensive copy). If the caller passed a
#'      `data.table`, the call will mutate it by adding a `threshold` column.
#'   2. Compute the requested quantile per group with `by = group_cols` and
#'      assign it to a new `threshold` column. The metric column is accessed via
#'      `.SD[[1]]` together with `.SDcols = metric` to avoid NSE and simplify
#'      lookups by name.
#'   3. Subset rows using `>=` or `>` depending on `inclusive`.
#'   4. Optionally drop the `threshold` helper column and return the filtered
#'      `data.table`.
#' - Assumptions and preconditions:
#'   * `metric` and `group_cols` names exist in `dt`.
#'   * `probs` is a single numeric in (0,1).
#' - Edge cases and failure modes:
#'   * If a group contains only `NA` values for `metric` the computed
#'     `threshold` is `NA` and no rows from that group will be returned.
#'   * If `metric` is missing or not coercible to numeric an error may be
#'     raised by `quantile()` or subsequent comparisons.
#'   * This function does not support vector `probs`; supply a scalar.
#' - Trade-offs:
#'   * Uses `data.table` grouping for performance. To prevent in-place
#'     modification of a `data.table` input, the caller must copy before call.
#'
#' @examples
#' library(data.table)
#' dt <- data.table::data.table(
#'   group = c("a", "a", "a", "b", "b"),
#'   tf = c(1, 2, 3, 1, 10)
#' )
#' # keep rows with tf > 75th percentile per group (default)
#' filter_group_quantile(dt, group_cols = "group", metric = "tf", probs = 0.75)
#'
#' # include threshold column and use inclusive comparison
#' filter_group_quantile(dt, group_cols = "group", metric = "tf",
#'   probs = 0.5, inclusive = TRUE, keep_threshold = TRUE)
#'
#' # edge case: group with only NA metric values -> no rows returned for that group
#' dt2 <- data.table::data.table(group = c("x","x"), tf = c(NA_real_, NA_real_))
#' filter_group_quantile(dt2, group_cols = "group", metric = "tf")
#'
#' @keywords internal
#' @seealso stats::quantile, data.table::data.table
#' @author Your Name
filter_group_quantile <- function(
  dt,
  group_cols,
  metric = "tf",
  probs = 0.75,
  inclusive = FALSE, # if TRUE use >=, otherwise >
  keep_threshold = FALSE # if TRUE return the threshold column in result
) {
  # Coerce to data.table for efficient grouping. Note: this will not make a
  # defensive copy — if `dt` is already a data.table the function will mutate it
  # by reference when adding the `threshold` column. Callers that need to preserve
  # the original should pass `data.table::copy(dt)`.
  if (!data.table::is.data.table(dt)) {
    dt <- data.table::as.data.table(dt)
  }

  # Compute threshold per group. Use .SD[[1]] with .SDcols = metric so we can
  # refer to the metric column by name without non-standard evaluation.
  # `na.rm = TRUE` ensures missing metric values are ignored when possible.
  dt[,
    threshold := as.numeric(quantile(.SD[[1]], probs = probs, na.rm = TRUE)),
    by = group_cols,
    .SDcols = metric
  ]

  # Apply comparison using the requested operator. Comparisons that produce NA
  # (e.g. when threshold is NA) will not select the row.
  if (inclusive) {
    res <- dt[get(metric) >= threshold]
  } else {
    res <- dt[get(metric) > threshold]
  }

  # Optionally drop the helper `threshold` column before returning.
  if (!keep_threshold) {
    res[, threshold := NULL]
  }
  # Return a data.table (use [] to preserve printing semantics)
  res[]
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
    # Helper to ensure DT font size is 11px for all tables.
    make_dt <- function(
      data,
      ...,
      options = list(),
      escape = TRUE,
      rownames = FALSE
    ) {
      dt <- DT::datatable(
        data,
        options = options,
        escape = escape,
        rownames = rownames,
        ...
      )
      dt <- DT::formatStyle(dt, columns = names(data), fontSize = "11px")
      dt
    }

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

      make_dt(
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

      # enforce font size 11px
      tbl <- DT::formatStyle(tbl, columns = names(out), fontSize = "11px")
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

      # Use helper to enforce font size
      make_dt(
        shown,
        escape = -which(cols %in% c("role", "Titre")),
        rownames = FALSE,
        options = list(
          dom = "lfrtip",
          searchHighlight = TRUE #,
          # rowCallback = js_row_cb,
          # columnDefs = col_defs
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
      make_dt(
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
      tab <- main_refs_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(Nom, Annee, Revue_Abbrege, nb_cit)
      make_dt(tab, options = list(pageLength = 20), rownames = FALSE)
    })

    output$cluster_refs_without_id <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      main_refs_cluster <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(top_references_without_id)
      tab <- main_refs_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(Nom, Annee, Revue_Abbrege, nb_cit)
      make_dt(tab, options = list(pageLength = 10), rownames = FALSE)
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
      tab <- tf_idf_for_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(term, tf_idf) %>%
        mutate(tf_idf = round(tf_idf, 4))
      make_dt(tab, options = list(pageLength = 20), rownames = FALSE)
    })

    output$cluster_origins_table <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      origins <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(cluster_origins)
      tab <- origins %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(previous_cluster, origin_percent) %>%
        mutate(origin_percent = sprintf("%.1f%%", 100 * origin_percent))
      make_dt(tab, options = list(pageLength = 10), rownames = FALSE)
    })

    output$cluster_destinies_table <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      destinies <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(cluster_destinies)

      tab <- destinies %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(forward_cluster, destiny_percent) %>%
        dplyr::mutate(
          destiny_percent = sprintf("%.1f%%", 100 * destiny_percent)
        )

      make_dt(
        tab,
        options = list(pageLength = 10),
        rownames = FALSE
      ) %>%
        DT::formatStyle(
          columns = names(tab),
          fontSize = '11px' # keep explicit for this table too
        )
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
