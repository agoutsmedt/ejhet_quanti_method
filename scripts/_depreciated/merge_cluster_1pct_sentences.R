################## Finding Inter-Temporal Clusters from BERT Sentence Embeddings ##################
# This script analyzes textual data using BERT embeddings to identify persistent thematic
# clusters across different time periods. It performs:
# 1. Inter-temporal cluster merging based on centroid similarity
# 2. Visualization of results

# LOADING DATA AND LIBRARIES----------------------

source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(
  tidymodels,
  tidyclust, # Clustering tools
  irlba, # Fast PCA
  doParallel,
  see
) # Color scales

# Set up parallel processing (using half of available cores)
n_cores <- floor(parallel::detectCores() / 2.5)
registerDoParallel(cores = n_cores)


#' If necessary, load data with embeddings:
#' `bert_df <- readRDS(file.path(data_path, "closest_sentences_0.01_rationality_score_filtered_with_embeddings.rds"))`

# Matching kept sentences with their vectors------------

## Running a PCA to reduce dimensionality-----------------
balanced_sample <- bert_df %>%
  mutate(
    time_window = cut(
      publication_year,
      breaks = c(1900, 1920, seq(1940, 2020, by = 10)),
      labels = paste0(
        c(1900, 1920, seq(1940, 2010, by = 10)),
        "-",
        c(1919, seq(1939, 2019, by = 10))
      )
    )
  ) %>%
  group_by(time_window) %>%
  slice_sample(n = 4000) %>%
  ungroup()

# 2. Fit PCA on this sample
sample_embeddings <- do.call(rbind, balanced_sample$embedding)
pc_global <- prcomp_irlba(
  sample_embeddings,
  n = 100,
  center = TRUE,
  scale. = TRUE
)

project_pc <- function(df, pc) {
  X <- do.call(rbind, df$embedding)
  Xs <- scale(X, center = pc$center, scale = pc$scale)
  as.matrix(Xs %*% pc$rotation[, 1:ncol(pc$rotation)])
}

# CLUSTERING PIPELINE-------------------

#' Process documents within a time window
#'
#' @param years Vector of two years (start, end)
#' @param df Dataframe containing documents and embeddings
#' @return List with two elements:
#'   - documents_partition: Cluster assignments
#'   - centroids: Cluster centroids
process_window <- function(years, df) {
  message(glue::glue("Starting window {years[1]}-{years[2]}"))

  # Filter documents in current window
  window_data <- df %>%
    filter(between(publication_year, years[1], years[2]))

  reduced_data <- project_pc(window_data, pc_global) %>%
    as_tibble() %>%
    mutate(sentence_id = window_data$sentence_id, .before = everything())
  rm(window_data)

  # Preprocessing recipe
  clust_recipe <- recipe(~., data = reduced_data) %>%
    update_role(sentence_id, new_role = "id") %>%
    step_normalize(all_predictors())

  # Define clustering workflow
  if ("ClusterR" %in% installed.packages()) {
    p_load(ClusterR)
    kmeans_wf <- workflow() %>%
      add_recipe(clust_recipe) %>%
      add_model(
        k_means(num_clusters = tune()) %>%
          set_engine("ClusterR", num_init = 10, max_iters = 100, verbose = TRUE)
      )
  } else {
    message("Package 'ClusterR' not installed. Using stats::kmeans instead.")
    # Fallback to stats::kmeans if ClusterR is not available
    kmeans_wf <- workflow() %>%
      add_recipe(clust_recipe) %>%
      add_model(
        k_means(num_clusters = tune()) %>%
          set_engine(
            "stats",
            algorithm = "Hartigan-Wong",
            iter.max = 100,
            nstart = 20
          )
      )
  }

  # Tune number of clusters (k) using silhouette score
  set.seed(89)
  tune_res <- tune_cluster(
    kmeans_wf,
    resamples = vfold_cv(reduced_data, v = 4),
    grid = tibble(num_clusters = 5:30),
    metrics = cluster_metric_set(sse_ratio),
    control = control_grid(parallel_over = "everything", allow_par = TRUE)
  )

  metrics_df <- collect_metrics(tune_res) %>%
    filter(.metric == "sse_ratio") %>%
    arrange(num_clusters) %>% # normally ok
    select(num_clusters, mean)

  metrics_df <- metrics_df %>%
    mutate(
      norm_k = (num_clusters - min(num_clusters)) /
        (max(num_clusters) - min(num_clusters)),
      norm_sse = (mean - min(mean)) / (max(mean) - min(mean)),
      difference = (1 - norm_k) - norm_sse
    )

  # Find the point with the maximum difference (the elbow)
  selected_k <- metrics_df %>%
    filter(difference == max(difference)) %>%
    pull(num_clusters)

  print(glue::glue(
    "Selected number of clusters using Kneedle algorithm: {selected_k}"
  ))

  # Final model with selected k
  final_fit <- workflow() %>%
    add_recipe(clust_recipe) %>%
    add_model(
      k_means(num_clusters = selected_k) %>%
        set_engine(
          "stats",
          algorithm = "Hartigan-Wong",
          iter.max = 100,
          nstart = 20
        )
    ) %>%
    fit(data = reduced_data)

  # Prepare results
  list(
    documents_partition = reduced_data %>%
      select(sentence_id) %>%
      mutate(
        cluster = extract_cluster_assignment(final_fit)$.cluster,
        nb_cluster = selected_k,
        window = paste(years[1], years[2], sep = "-")
      ),
    centroids = extract_centroids(final_fit) %>%
      mutate(window = paste(years[1], years[2], sep = "-"))
  )
}
# Process all time windows
results <- map(time_windows, ~ process_window(.x, bert_df))
saveRDS(results, file.path(data_path, "clustering_rational_sentences.rds"))

#' If necessary: `results <- readRDS(file.path(data_path, "clustering_rational_sentences.rds"))`

# INTER-TEMPORAL CLUSTER MERGING ----------------------
# Combine results from all windows
documents_partition <- map(
  1:length(results),
  ~ pluck(results, ., "documents_partition")
) %>%
  bind_rows
centroids <- map(1:length(results), ~ pluck(results, ., "centroids")) %>%
  bind_rows %>%
  mutate(cluster_original_id = 1:n())

# Calculate cosine similarity between all centroids
centroid_matrix <- centroids %>%
  select(-.cluster, -window, -cluster_original_id) %>%
  as.matrix()
cosine_sim <- lsa::cosine(t(centroid_matrix))

# distribution of cosine similarities
similarities <- data.frame(similarity = as.vector(cosine_sim)) %>%
  arrange(desc(similarity)) %>%
  filter(similarity < 1) # Filter out self-comparisons (diagonal)

ggplot(similarities, aes(x = similarity)) +
  geom_boxplot() +
  labs(
    title = "Distribution of Cosine Similarities Between Centroids",
    x = "Cosine Similarity",
    y = "Frequency"
  ) +
  theme_minimal()

# Extract window names in order
window_order <- data.frame(
  window = names(time_windows),
  window_index = seq_along(time_windows)
)

similarity_threshold <- 0.7
cosine_tbl <- as.data.frame(cosine_sim) %>%
  mutate(cluster_A = centroids$cluster_original_id) %>%
  pivot_longer(-cluster_A, names_to = "cluster_B", values_to = "similarity") %>%
  mutate(cluster_B = as.integer(str_remove(cluster_B, "V"))) %>%
  filter(cluster_A < cluster_B) %>%
  left_join(select(
    centroids,
    cluster_A = cluster_original_id,
    window_A = window
  )) %>%
  left_join(select(
    centroids,
    cluster_B = cluster_original_id,
    window_B = window
  )) %>%
  left_join(window_order, by = c("window_A" = "window")) %>%
  rename(index_A = window_index) %>%
  left_join(window_order, by = c("window_B" = "window")) %>%
  rename(index_B = window_index) %>%
  filter(similarity > similarity_threshold, abs(index_A - index_B) == 1) %>%
  arrange(index_A, cluster_A, similarity) %>%
  distinct(window_A, cluster_A, window_B, .keep_all = TRUE) %>% # only one matching in the future (if a t clusters is close to 2 t+1 clusers, we take the first one)
  distinct(window_B, cluster_B, window_A, .keep_all = TRUE) # only one matching in the past (if a t+1 clusters is close to 2 t clusers, we take the first one)

g <- graph_from_data_frame(cosine_tbl, directed = FALSE)
components <- components(g)
cluster_map <- data.frame(
  cluster_original_id = names(components$membership) %>% as.integer(),
  new_cluster = components$membership
) %>%
  mutate(new_cluster = min(cluster_original_id), .by = new_cluster) %>%
  filter(cluster_original_id != new_cluster)
cli::cli_alert_info(
  "Number of merged clusters: {nrow(cluster_map)}.
                     Total clusters before merging: {nrow(centroids)}.
                     Total clusters after merging: {nrow(centroids) - nrow(cluster_map)}."
)

final_clusters <- centroids %>%
  left_join(cluster_map, by = "cluster_original_id") %>%
  mutate(
    new_cluster = ifelse(
      is.na(new_cluster),
      paste0("intertemporal_cluster_", cluster_original_id),
      paste0("intertemporal_cluster_", new_cluster)
    )
  )

# Apply merged clusters to documents
documents_partition <- documents_partition %>%
  mutate(cluster = as.character(cluster)) %>%
  left_join(
    select(final_clusters, cluster = .cluster, window, new_cluster),
    by = c("window", "cluster")
  )

saveRDS(
  documents_partition,
  file.path(data_path, "sentences_intertemporal_cluster.rds")
)

# VISUALIZATION ----------------------

set.seed(1989)
all_clusters <- levels(factor(documents_partition$new_cluster)) %>% sample()
# Preview the default 'see' palette to get the colors
palette_colors <- c(
  see::see_colors(),
  see::oi_colors()[1:7],
  scico::scico(n = 8, palette = "roma"),
  scico::scico(n = 8, palette = "tokyo"),
  scico::scico(n = 8, palette = "hawaii"),
  scico::scico(n = 8, palette = "batlowK"),
  scico::scico(n = 7, palette = "bamako"),
  scico::scico(n = 7, palette = "glasgow")
)
# If you use another palette, replace accordingly
# Let's say you use 8 clusters and 8 colors from the palette
cluster_colors <- palette_colors[1:length(all_clusters)]
names(cluster_colors) <- all_clusters


# 1. Alluvial plot showing cluster persistence
documents_partition %>%
  count(window, new_cluster) %>%
  mutate(percent = n / sum(n), .by = window) %>%
  mutate(new_cluster = factor(new_cluster, levels = all_clusters)) %>%
  ggplot(aes(
    x = window,
    y = percent,
    stratum = new_cluster,
    alluvium = new_cluster,
    fill = new_cluster,
    label = new_cluster
  )) +
  geom_flow(alpha = 0.9) +
  geom_stratum() +
  geom_text(stat = "stratum", size = 3) +
  labs(
    title = "Cluster Persistence Across Time Windows",
    x = "Time Period",
    y = "Percentage of Documents",
    fill = "Intertemporal Cluster"
  ) +
  theme_bw() +
  theme(legend.position = "none") +
  scale_fill_manual(values = cluster_colors) # HARD color lock

ggsave(
  file.path("pictures", "intertemporal_clusters_alluvial.png"),
  units = "cm",
  width = 30,
  height = 30,
  dpi = 300
)

# Test clustering by network analysis and backbone-----------------------
p_load(backbone)
cluster_similarity <- as.data.frame(cosine_sim) %>%
  mutate(cluster_A = 1:n()) |>
  pivot_longer(-cluster_A, names_to = "cluster_B", values_to = "similarity") %>%
  mutate(cluster_B = str_remove(cluster_B, "V") |> as.integer()) %>%
  filter(cluster_A != cluster_B)

cluster_attributes <- tibble(
  window = centroids$window,
  cluster = centroids$.cluster
) |>
  mutate(cluster_id = 1:n())

# 1) Nodes: gather node attributes
nodes <- cluster_similarity %>%
  distinct(cluster_id = cluster_A) |>
  left_join(cluster_attributes, by = "cluster_id")

# 2) Edges = average similarity across windows (undirected)
edges <- cluster_similarity %>%
  transmute(from = cluster_A, to = cluster_B, w = similarity) %>%
  mutate(a = pmin(from, to), b = pmax(from, to)) %>%
  group_by(a, b) %>%
  summarise(weight = mean(w, na.rm = TRUE), .groups = "drop") %>%
  rename(from = a, to = b) %>%
  filter(from != to, is.finite(weight)) %>%
  filter(weight > 0) # keep positive similarity; adjust threshold if needed

# 3) Graph
g <- tbl_graph(nodes = nodes, edges = edges, directed = FALSE) %>%
  backbone_from_weighted(model = "disparity") %>%
  as_tbl_graph() %>%
  mutate(
    community = group_leiden(
      objective_function = "modularity",
      n = 1000,
      resolution = 3
    ) %>%
      as.factor()
  )

g |> as_tibble() |> count(community, sort = T) |> print(n = Inf)
write_rds(g, file.path(data_path, "sentences_clusters_backbone_network.rds"))

# Apply backbone-leiden communities to documents
nodes_tbl <- g |> as_tibble()

documents_partition <- documents_partition %>%
  mutate(cluster = as.character(cluster)) %>%
  left_join(
    nodes_tbl %>%
      select(
        window,
        cluster,
        backbone_community = community,
        kmean_cluster_id = cluster_id
      ),
    by = c("window", "cluster")
  )

saveRDS(
  documents_partition,
  file.path(data_path, "sentences_intertemporal_cluster.rds")
)
