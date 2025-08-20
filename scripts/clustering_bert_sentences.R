################## Finding Inter-Temporal Clusters from BERT Sentence Embeddings ##################
# This script analyzes textual data using BERT embeddings to identify persistent thematic 
# clusters across different time periods. It performs:
# 1. Time window creation (decadal)
# 2. K-means clustering within each window
# 3. Inter-temporal cluster merging based on centroid similarity
# 4. Visualization of results

# LOADING DATA AND LIBRARIES----------------------

source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(tidymodels,
               tidyclust, # Clustering tools
               irlba, # Fast PCA
               doParallel,
               see) # Color scales

# Set up parallel processing (using half of available cores)
n_cores <- floor(parallel::detectCores() /2.5)  
registerDoParallel(cores = n_cores)

## Bert rational paragraph loading--------------------
bert_df <- read_rds(here::here(data_path, "closest_sentences_0.01_rationality_score.rds")) %>% 
  bind_rows %>% 
  as.data.table()

# Choosing thresholds for similarity----------------

# 1) Mean similarity by year (already computed per sentence; take the unique per year)
bert_df[, sd_similarity := sd(similarity, na.rm = TRUE)]
mean_year <- bert_df[, .(mean_year_similarity = unique(mean_year_similarity)[1],
                         sd_similarity = unique(sd_similarity)[1]),
                     by = publication_year][order(publication_year)]

# Plot mean ± sd per year
ggplot(mean_year, aes(x = publication_year, y = mean_year_similarity)) +
  geom_line(color = "black") +
  geom_point() +
  geom_ribbon(aes(ymin = mean_year_similarity - sd_similarity,
                    ymax = mean_year_similarity + sd_similarity),
                alpha = 0.3) +
  labs(
    title = "Mean similarity per year with standard deviation",
    x = "Publication Year",
    y = "Mean similarity ± SD"
  )

# 2) How many sentences per year if cutoff = 0.60 or 0.55
#    Note: this counts within your kept subset (top 1%), not the full corpus.
counts <- bert_df[, .(
  prop_062 = mean(similarity >= 0.62, na.rm = TRUE),
  prop_060 = mean(similarity >= 0.60, na.rm = TRUE),
  prop_058 = mean(similarity >= 0.58, na.rm = TRUE),
  kept   = .N
), by = publication_year][order(publication_year)]

# Plot both thresholds
counts_long <- melt(counts,
                    id.vars = "publication_year",
                    measure.vars = c("prop_062", "prop_060", "prop_058"),
                    variable.name = "cutoff",
                    value.name = "count")

ggplot(counts_long, aes(publication_year, count, linetype = cutoff, color = cutoff)) +
  geom_point() +
  geom_smooth(span = 0.3) +
  scale_color_see_d() +
  labs(x = "Year", y = "Count ≥ cutoff") +
  theme_minimal()

# For now, we take a cutoff of 0.58 for similarity
final_cutoff <- 0.58
bert_df <- bert_df[similarity > final_cutoff]

# Matching kept sentences with their vectors------------


## Time window set up------------------
# Generate decade breaks (1900-2020)
decades <- seq(1900, 2020, by = 10)

# Create window labels (e.g., "1900-1909", "1910-1919")
time_windows <- map2(decades[-length(decades)], decades[-1] - 1, 
                     ~c(.x, .y)) %>%
  set_names(paste0(decades[-length(decades)], "-", decades[-1] - 1))

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
  
  # Create embedding matrix
  bert_mat <- do.call(rbind, window_data$bert_embedding_concat)
  bert_tbl <- as_tibble(bert_mat) %>% 
    mutate(id = window_data$doc_id, .before = everything())
  
  # Preprocessing recipe
  clust_recipe <- recipe(~ ., data = bert_tbl) %>%
    update_role(id, new_role = "id") %>% 
    step_normalize()
  
  # Define clustering workflow
  kmeans_wf <- workflow() %>%
    add_recipe(clust_recipe) %>%
    add_model(k_means(num_clusters = tune()) %>% set_engine("stats"))
  
  # Tune number of clusters (k) using silhouette score
  set.seed(89)
  tune_res <- tune_cluster(
    kmeans_wf,
    resamples = vfold_cv(bert_tbl, v = 3),
    grid = tibble(num_clusters = 3:8),
    metrics = cluster_metric_set(sse_ratio),
    control = control_grid(parallel_over = "everything")
  )
  
  metrics_df <- collect_metrics(tune_res) %>%
    filter(.metric == "sse_ratio") %>%
    arrange(num_clusters) %>% # normally ok
    select(num_clusters, mean)
  
  metrics_df <- metrics_df %>%
    mutate(
      norm_k = (num_clusters - min(num_clusters)) / (max(num_clusters) - min(num_clusters)),
      norm_sse = (mean - min(mean)) / (max(mean) - min(mean)),
      difference = (1 - norm_k) - norm_sse
    )
  
  # Find the point with the maximum difference (the elbow)
  selected_k <- metrics_df %>%
    filter(difference == max(difference)) %>%
    pull(num_clusters)
  
  print(glue::glue("Selected number of clusters using Kneedle algorithm: {selected_k}"))
  
  # Final model with selected k
  final_fit <- workflow() %>%
    add_recipe(clust_recipe) %>%
    add_model(k_means(num_clusters = selected_k) %>% set_engine("stats")) %>%
    fit(data = bert_tbl)
  
  # Prepare results
  list(
    documents_partition = bert_tbl %>% 
      select(id) %>% 
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
results <- map(time_windows, ~process_window(.x, bert_df))
saveRDS(results, file.path(data_path, "clustering_rational_paragraphs.rds"))

#' If necessary: `results <- readRDS(file.path(data_path, "clustering_rational_paragraphs.rds"))`

# INTER-TEMPORAL CLUSTER MERGING ----------------------
# Combine results from all windows
documents_partition <- map(1:length(results), ~pluck(results, ., "documents_partition")) %>% 
  bind_rows
centroids <- map(1:length(results), ~pluck(results, ., "centroids")) %>% 
  bind_rows %>% 
  mutate(cluster_original_id = 1:n())

# Calculate cosine similarity between all centroids
centroid_matrix <- centroids %>%
  select(-.cluster, -window) %>%
  as.matrix()
cosine_sim <- lsa::cosine(t(centroid_matrix))

# Extract window names in order
window_order <- data.frame(
  window = names(time_windows),
  window_index = seq_along(time_windows)
)

similarity_threshold <- 0.97
cosine_tbl <- as.data.frame(cosine_sim) %>%
  mutate(cluster_A = centroids$cluster_original_id) %>%
  pivot_longer(-cluster_A, names_to = "cluster_B", values_to = "similarity") %>%
  mutate(cluster_B = as.integer(str_remove(cluster_B, "V"))) %>%
  filter(cluster_A < cluster_B) %>%
  left_join(select(centroids, cluster_A = cluster_original_id, window_A = window)) %>%
  left_join(select(centroids, cluster_B = cluster_original_id, window_B = window)) %>%
  left_join(window_order, by = c("window_A" = "window")) %>%
  rename(index_A = window_index) %>%
  left_join(window_order, by = c("window_B" = "window")) %>%
  rename(index_B = window_index) %>%
  filter(similarity > similarity_threshold, abs(index_A - index_B) == 1) %>%
  # we don't want to merge clusters from the same window
  distinct(cluster_A, window_A, window_B, .keep_all = TRUE) %>% # We merge only with the closest cluster in the window, to avoid merging to cluster together in a window
  distinct(cluster_B, window_A, window_B, .keep_all = TRUE) # We merge only with the closest cluster in the window, to avoid merging to cluster together in a window
  
g <- graph_from_data_frame(cosine_tbl, directed = FALSE)
components <- components(g)
cluster_map <- data.frame(cluster_original_id = names(components$membership) %>% as.integer(),
                          new_cluster = components$membership) %>% 
  mutate(new_cluster = min(cluster_original_id), .by = new_cluster)

final_clusters <- centroids %>%
  left_join(cluster_map, by = "cluster_original_id") %>% 
  mutate(new_cluster = ifelse(is.na(new_cluster), paste0("intertemporal_cluster_", cluster_original_id), paste0("intertemporal_cluster_", new_cluster)))

# 
# # Convert similarity matrix to tidy format
# cosine_tbl <- as.data.frame(cosine_sim) %>%
#   mutate(cluster_A = centroids$cluster_original_id) %>%
#   pivot_longer(-cluster_A, names_to = "cluster_B", values_to = "similarity") %>%
#   mutate(cluster_B = str_remove(cluster_B, "V") %>% as.integer()) %>% 
#   filter(cluster_A < cluster_B) %>%  # Remove duplicates and self-comparisons
#   arrange(desc(similarity)) %>% 
#   left_join(select(centroids, original_cluster_A = .cluster, window_A = window, cluster_A = cluster_original_id)) %>% 
#   left_join(select(centroids, original_cluster_B = .cluster, window_B = window, cluster_B = cluster_original_id)) 
# 
# # Merge similar clusters (threshold = 0.95 cosine similarity)
# 
# clusters_to_merge <- cosine_tbl %>% 
#   filter(similarity > similarity_threshold) %>% 
#   filter(window_A != window_B) %>% # we don't want to merge clusters from the same window
#   distinct(cluster_A, window_A, window_B, .keep_all = TRUE) %>% # We merge only with the closest cluster in the window, to avoid merging to cluster together in a window
#   distinct(original_cluster_B, window_A, window_B, .keep_all = TRUE) %>% # We merge only with the closest cluster in the window, to avoid merging to cluster together in a window
#   select(cluster_A, cluster_B) %>% 
#   arrange(cluster_A, cluster_B) %>% 
#   mutate(new_cluster = min(cluster_A), .by = cluster_A) %>% 
#   mutate(new_cluster = min(new_cluster), .by = cluster_B) %>% 
#   mutate(new_cluster = min(new_cluster), .by = cluster_A) %>% 
#   pivot_longer(cluster_A:cluster_B, values_to = "cluster_original_id") %>% 
#   select(-name) %>% 
#   unique() %>% 
#   mutate(new_cluster = str_c("intertemporal_cluster_", min(new_cluster)), .by = cluster_original_id) %>% 
#   unique() %>% 
#   arrange(new_cluster) %>% 
#   right_join(select(centroids, window, cluster = .cluster, cluster_original_id)) %>% 
#   mutate(new_cluster = if_else(is.na(new_cluster), str_c("intertemporal_cluster_", cluster_original_id), new_cluster))

# Apply merged clusters to documents
documents_partition <- documents_partition %>% 
  mutate(cluster = as.character(cluster)) %>% 
  left_join(select(final_clusters, cluster = .cluster, window, new_cluster), by = c("window", "cluster"))

saveRDS(documents_partition, file.path(data_path, "paragraphs_intertemporal_cluster.rds"))

# VISUALIZATION ----------------------

set.seed(1989)
all_clusters <- levels(factor(documents_partition$new_cluster)) %>% sample()
# Preview the default 'see' palette to get the colors
palette_colors <- c(see::see_colors(), see::oi_colors())  # Example for the see_d palette
# If you use another palette, replace accordingly
# Let's say you use 8 clusters and 8 colors from the palette
cluster_colors <- palette_colors[1:length(all_clusters)]
names(cluster_colors) <- all_clusters

# 1. Stacked bar plot of cluster proportions
documents_partition %>%
  count(window, new_cluster) %>%
  mutate(percent = n / sum(n), .by = window,
         new_cluster = factor(new_cluster, levels= all_clusters)) %>%
  ggplot(aes(x = window, y = percent, fill = new_cluster)) +
  geom_col(position = "stack") +
  geom_text(aes(label = percent(percent, accuracy = 1)), 
            position = position_stack(vjust = 0.5), 
            color = "white", size = 3) +
  scale_y_continuous(labels = percent) +
  labs(title = "Share of Documents by Cluster (Stacked)",
       x = "Time Window",
       y = "Percentage of Documents",
       fill = "Intertemporal Cluster") +
  theme_minimal() +
  scale_fill_manual(values = cluster_colors)  # HARD color lock
  
# 2. Alluvial plot showing cluster persistence
documents_partition %>%
  count(window, new_cluster) %>% 
  mutate(percent = n / sum(n), .by = window) %>%
  mutate(new_cluster = factor(new_cluster, levels= all_clusters)) %>% 
  ggplot(aes(x = window, y = percent, stratum = new_cluster, alluvium = new_cluster,
             fill = new_cluster, label = new_cluster)) +
  geom_flow(alpha = 0.9) +
  geom_stratum() +
  geom_text(stat = "stratum", size = 3) +
  labs(title = "Cluster Persistence Across Time Windows",
       x = "Time Period",
       y = "Percentage of Documents",
       fill = "Intertemporal Cluster") +
  theme_minimal() +
  theme(legend.position = "bottom") +
  scale_fill_manual(values = cluster_colors)  # HARD color lock

ggsave(file.path("pictures", "intertemporal_clusters_alluvial.png"),
       units = "cm",
       width = 30,
       height = 30,
       dpi = 300)

# 3. PCA visualization of all documents
window_data <- bert_df %>% 
  filter(between(publication_year, min(unlist(time_windows)), max(unlist(time_windows))))
bert_mat <- do.call(rbind, window_data$bert_embedding_concat)
pca <- prcomp_irlba(bert_mat, n = 2, center = TRUE, scale. = TRUE)

top_clusters <- documents_partition %>% 
  count(new_cluster) %>% 
  mutate(share = n/sum(n)) %>% 
  filter(share > 0.03)

# Create tibble with results
all_articles_pca <- tibble(
  id = window_data$doc_id,
  PC1 = pca$x[, 1],
  PC2 = pca$x[, 2],
) %>% 
  left_join(select(documents_partition, id, new_cluster)) %>% 
  mutate(label_cluster = if_else(new_cluster %in% top_clusters$new_cluster, new_cluster, NA),
         label_cluster = factor(label_cluster, levels = all_clusters))

# PCA plot colored by intertemporal clusters
plot_bert <- ggplot(all_articles_pca, aes(x = PC1, y = PC2, color = label_cluster)) +
  geom_point(size = 0.5) +
  theme_minimal() + 
  scale_color_manual(values = cluster_colors, na.value = "gray") +  # HARD color lock
#  see::scale_color_see_d(na.value = "gray") +
  labs(title = "BERT base", x = "PC1", y = "PC2")

ggsave(file.path("pictures", "intertemporal_clusters_pca.png"),
       plot_bert,
       units = "cm",
       width = 30,
       height = 30,
       dpi = 300)

