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
