#' Fast P and z metrics for Guimera-Amaral role analysis
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
#' @note To obtain discrete roles (e.g., R1-R7), learn thresholds on
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
#' Guimera, R., & Amaral, L. A. N. (2005). Functional cartography of complex
#' metabolic networks. *Nature*, 433, 895-900.
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
