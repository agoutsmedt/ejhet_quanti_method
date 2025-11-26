################## Inter-Temporal Cluster Tracking ##################
# Merge clusters across time windows based on centroid similarity
# Using cosine similarity between centroids extracted from HDBSCAN results
#####################################################################

source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(
  dplyr,
  tidyr,
  purrr,
  stringr,
  ggplot2,
  arrow,
  backbone
)

# ---------------------------------------------------------
# 1. LOAD CLUSTERIZED SENTENCES
# ---------------------------------------------------------

sentence_clusterized <- arrow::read_feather(
  file.path(data_path, "hdbscan_all_sentences_with_clusters.feather")
)

# Remove noise clusters
sentence_clusterized <- sentence_clusterized %>%
  filter(!is_noise)

# ---------------------------------------------------------
# 2. EXTRACT CENTROIDS (one per window x cluster)
# ---------------------------------------------------------

centroids <- sentence_clusterized %>%
  group_by(window, cluster) %>%
  summarise(
    centroid_vec = list(colMeans(do.call(rbind, centroid))),
    .groups = "drop"
  )

message("Number of clusters before merging: ", nrow(centroids))

# ---------------------------------------------------------
# 3. BUILD CENTROID MATRIX
# ---------------------------------------------------------

centroid_matrix <- centroids$centroid_vec %>%
  do.call(rbind, .) %>%
  as.matrix()

# ---------------------------------------------------------
# 4. COSINE SIMILARITY MATRIX
# ---------------------------------------------------------

cosine_sim <- centroid_matrix %*% t(centroid_matrix)
norms <- sqrt(rowSums(centroid_matrix^2))
cosine_sim <- cosine_sim / outer(norms, norms)

# ---------------------------------------------------------
# 5. BUILD CLUSTER SIMILARITY NETWORK
# ---------------------------------------------------------

cluster_similarity <- as.data.frame(cosine_sim) %>%
  # transform matrix to long format
  mutate(cluster_A = 1:n()) |>
  pivot_longer(-cluster_A, names_to = "cluster_B", values_to = "similarity") %>%
  mutate(cluster_B = str_remove(cluster_B, "V") |> as.integer()) %>%
  # Remove self-similarity
  filter(cluster_A != cluster_B)

cluster_attributes <- tibble(
  window = centroids$window,
  cluster = centroids$cluster
) %>%
  mutate(cluster_id = 1:n())

# 1) Nodes: gather node attributes
nodes <- cluster_similarity %>%
  distinct(cluster_id = cluster_A) %>%
  left_join(cluster_attributes, by = "cluster_id")

# 2) Edges = average similarity across windows (undirected)
edges <- cluster_similarity %>%
  transmute(from = cluster_A, to = cluster_B, w = similarity) %>%
  # we now remove duplicate edges by averaging
  mutate(a = pmin(from, to), b = pmax(from, to)) %>%
  group_by(a, b) %>%
  summarise(weight = mean(w, na.rm = TRUE), .groups = "drop") %>%
  rename(from = a, to = b) %>%
  # remove self-loops and non-finite weights if any
  filter(from != to, is.finite(weight))

# 3) Graph
g <- tbl_graph(nodes = nodes, edges = edges, directed = FALSE) %>%
  backbone::backbone_from_weighted(model = "disparity", alpha = 0.3) %>%
  as_tbl_graph() %>%
  mutate(
    community = group_leiden(
      objective_function = "modularity",
      n = 1000,
      resolution = 3
    ) %>%
      as.factor()
  )

g |> as_tibble() %>% count(community, sort = T) %>% print(n = Inf)
write_rds(g, file.path(data_path, "backbone_network_of_sentences_clusters.rds"))


# --------------------------------------------
# 6. BUILD TABLES FOR FURTHER ANALYSES
# --------------------------------------------

# Apply backbone-leiden communities to documents
nodes_tbl <- g %>%
  as_tibble() %>%
  select(cluster_id, window, cluster, backbone_community = community)

documents_partition <- sentence_clusterized %>%
  left_join(
    nodes_tbl,
    by = c("window", "cluster")
  ) %>%
  rename(HDBSCAN_cluster = cluster)

arrow::write_feather(
  documents_partition,
  file.path(data_path, "sentences_intertemporal_cluster.feather")
)


test <- arrow::read_feather(
  file.path(data_path, "sentences_intertemporal_cluster.feather")
)
