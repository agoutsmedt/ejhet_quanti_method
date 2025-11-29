################## Inter-Temporal Cluster Tracking ##################
# Merge clusters across time windows based on centroid similarity
# Using cosine similarity between centroids extracted from HDBSCAN results
#####################################################################

source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(
  backbone
)

# ---------------------------------------------------------
# 1. LOAD CLUSTERIZED SENTENCES
# ---------------------------------------------------------

sentence_dataset <- arrow::open_dataset(
  file.path(
    data_path,
    "hdbscan_all_sentences_with_clusters_min_sample_1.feather"
  ),
  format = "feather"
)

sentence_clusterized <- sentence_dataset %>%
  filter(is_noise == "real_cluster") %>% # Remove noise clusters
  collect()

# Check euclidian distances between UMAP centroids
check_umap_distance <- FALSE
if (!check_umap_distance) {
  message("Skipping UMAP distance check...")
} else {
  message("Checking UMAP distances between centroids...")
  centroids_umap <- sentence_clusterized %>%
    group_by(window, cluster) %>%
    summarise(
      centroid_vec = list(colMeans(do.call(rbind, umap))),
      .groups = "drop"
    )

  centroid_umap_matrix <- centroids_umap$centroid_vec %>%
    do.call(rbind, .) %>%
    as.matrix()

  # Calculate euclidian distance matrix
  euclidian_umap_dist <- as.matrix(dist(
    centroid_umap_matrix,
    method = "euclidean"
  ))

  cluster_distance <- as.data.frame(euclidian_umap_dist) %>%
    # transform matrix to long format
    mutate(cluster_A = 1:n()) |>
    pivot_longer(
      -cluster_A,
      names_to = "cluster_B",
      values_to = "euclidian_distance"
    ) %>%
    mutate(cluster_B = str_remove(cluster_B, "V") |> as.integer()) %>%
    # Remove self-similarity
    filter(cluster_A != cluster_B)

  # Preparing network -------------
  cluster_attributes <- tibble(
    window = centroids_umap$window,
    cluster = centroids_umap$cluster
  ) %>%
    mutate(cluster_id = 1:n())

  # 1) Nodes: gather node attributes
  cluster_edges_distance <- cluster_distance %>%
    # distinct(cluster_id = cluster_A) %>%
    left_join(cluster_attributes, by = c("cluster_A" = "cluster_id")) %>%
    rename(window_A = window, cluster_A_num = cluster) %>%
    left_join(cluster_attributes, by = c("cluster_B" = "cluster_id")) %>%
    rename(window_B = window, cluster_B_num = cluster) %>%
    filter(window_A == window_B) %>%
    # undirected graph: keep only one direction
    filter(cluster_A < cluster_B, euclidian_distance < 1)
}

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

# Check similarity distribution
cluster_similarity %>%
  ggplot(aes(x = similarity)) +
  geom_histogram(bins = 100) +
  theme_minimal() +
  labs(
    title = "Distribution of cosine similarities between cluster centroids",
    x = "Cosine Similarity",
    y = "Count"
  )

# Preparing network -------------
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
set.seed(89)
g <- tbl_graph(nodes = nodes, edges = edges, directed = FALSE) %>%
  backbone::backbone_from_weighted(model = "lans", alpha = 0.02) %>%
  as_tbl_graph() %>%
  mutate(
    community = group_leiden(
      objective_function = "modularity",
      n = 1000,
      resolution = 1
    ) %>%
      as.factor()
  )

# search number of components
g %>%
  mutate(comp = group_components()) %>%
  as_tibble() %>%
  count(comp, sort = T) %>%
  print(n = Inf)


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
