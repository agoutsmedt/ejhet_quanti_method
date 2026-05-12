#' Data-driven cut points for Guimera-Amaral role assignment
#'
#' Learn thresholds to classify nodes into Guimera-Amaral roles using observed
#' distributions of within-cluster z-scores and participation coefficients.
#' The function estimates:
#' \itemize{
#'   \item a global hub threshold on \code{z} via a high quantile;
#'   \item three non-hub \code{P} cut points (k=4 clusters -> 3 cuts) by 1-D k-means;
#'   \item two hub \code{P} cut points  (k=3 clusters -> 2 cuts) by 1-D k-means.
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
