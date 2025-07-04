################## Finding Inter-Temporal Clusters from BERT Embeddings ##################
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
bert_df <- read_feather(here::here(jstor_raw_data, "embeddings_bert-base-uncased.feather")) %>% 
  mutate(doc_id = str_c(id, "_", paragraph_id)) %>% 
  arrange(doc_id)  

#econ_df <- read_feather(here::here(jstor_raw_data, "embeddings_econbert.feather"))

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
    grid = tibble(num_clusters = 4:6),
    metrics = cluster_metric_set(silhouette_avg),
    control = control_grid(parallel_over = "everything", save_pred = TRUE)
  )
  
  # Select best k
  best_k <- collect_metrics(tune_res) %>%
    filter(.metric == "silhouette_avg") %>%
    arrange(desc(mean)) %>%
    slice(1) %>%
    pull(num_clusters)
  
  # Final model with selected k
  final_fit <- workflow() %>%
    add_recipe(clust_recipe) %>%
    add_model(k_means(num_clusters = best_k) %>% set_engine("stats")) %>%
    fit(data = bert_tbl)
  
  bert <- bert_tbl %>% 
    select(id) %>% 
    mutate(cluster = extract_cluster_assignment(final_fit)$.cluster,
           nb_cluster = best_k,
           window = paste(years[1], years[2], sep = "-"))
  centroids <- tidyclust::extract_centroids(final_fit) %>% 
    mutate(window = paste(years[1], years[2], sep = "-"))
  
  # Return results
  return(list("documents_partition" = bert,
              "centroids" = centroids))
}
results <- map(time_windows, ~process_window(.x, bert_df))

similarity_threshold <- 0.95
documents_partition <- map(1:length(results), ~pluck(results, ., "documents_partition")) %>% 
  bind_rows
centroids <- map(1:length(results), ~pluck(results, ., "centroids")) %>% 
  bind_rows %>% 
  mutate(cluster_original_id = 1:n())

centroid_matrix <- centroids %>%
  select(-.cluster, -window) %>%
  as.matrix()
cosine_sim <- lsa::cosine(t(centroid_matrix))
cosine_tbl <- as.data.frame(cosine_sim) %>%
  mutate(cluster_A = centroids$cluster_original_id) %>%
  pivot_longer(-cluster_A, names_to = "cluster_B", values_to = "similarity") %>%
  mutate(cluster_B = str_remove(cluster_B, "V") %>% as.integer()) %>% 
  filter(cluster_A < cluster_B) %>%  # Remove duplicates and self-comparisons
  arrange(desc(similarity)) %>% 
  left_join(select(centroids, original_cluster_A = .cluster, window_A = window, cluster_A = cluster_original_id)) %>% 
  left_join(select(centroids, original_cluster_B = .cluster, window_B = window, cluster_B = cluster_original_id)) 

similarity_threshold <- 0.95
clusters_to_merge <- cosine_tbl %>% 
  filter(similarity > similarity_threshold) %>% 
  select(cluster_A, cluster_B) %>% 
  arrange(cluster_A, cluster_B) %>% 
  mutate(new_cluster = min(cluster_A), .by = cluster_A) %>% 
  pivot_longer(cluster_A:cluster_B, values_to = "cluster_original_id") %>% 
  select(-name) %>% 
  unique() %>% 
  mutate(new_cluster = str_c("intertemporal_cluster_", min(new_cluster)), .by = cluster_original_id) %>% 
  unique() %>% 
  arrange(new_cluster) %>% 
  right_join(select(centroids, window, cluster = .cluster, cluster_original_id)) %>% 
  mutate(new_cluster = if_else(is.na(new_cluster), str_c("intertemporal_cluster_", cluster_original_id), new_cluster))

documents_partition <- documents_partition %>% 
  mutate(cluster = as.character(cluster)) %>% 
  left_join(clusters_to_merge, by = c("window", "cluster"))

documents_partition %>%
  count(window, new_cluster) %>%
  mutate(percent = n / sum(n), .by = window) %>%
  ggplot(aes(x = window, y = percent, fill = fct_rev(new_cluster))) +
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
  see::scale_fill_oi()

documents_partition %>%
  count(window, new_cluster) %>% 
  mutate(percent = n / sum(n), .by = window) %>%
  mutate(new_cluster = fct_rev(new_cluster)) %>% 
  ggplot(aes(x = window, y = percent, stratum = new_cluster, alluvium = new_cluster,
             fill = new_cluster, label = new_cluster)) +
  geom_flow(alpha = 0.7) +
  geom_stratum() +
  geom_text(stat = "stratum", size = 3) +
  labs(title = "Cluster Persistence Across Time Windows",
       x = "Time Period",
       y = "Percentage of Documents",
       fill = "Intertemporal Cluster") +
  theme_minimal() +
  see::scale_fill_oi()  # Better color palette
# Function to process each window

# Filter data and create matrix
window_data <- bert_df %>% 
  filter(between(publication_year, min(unlist(time_windows)), max(unlist(time_windows))))
bert_mat <- do.call(rbind, window_data$bert_embedding_concat)
# Run PCA (2 components)
pca <- prcomp_irlba(bert_mat, n = 2, center = TRUE, scale. = TRUE)
# Create tibble with results
all_articles_pca <- tibble(
  id = window_data$doc_id,
  PC1 = pca$x[, 1],
  PC2 = pca$x[, 2],
  # Add your existing cluster assignments here
) %>% 
  left_join(select(documents_partition, id, new_cluster))
# ---------------------- PLOTS ---------------------- #
plot_bert <- ggplot(all_articles_pca, aes(x = PC1, y = PC2, color = fct_rev(new_cluster))) +
  geom_point(size = 0.5) +
  theme_minimal() + 
  see::scale_color_oi() +
  labs(title = "BERT base", x = "PC1", y = "PC2")

source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(arrow,
               tidymodels,
               tidyclust,
               irlba,
               doParallel,
               ggalluvial)
# Detect and use all available cores (minus 1 for safety)
n_cores <- floor(parallel::detectCores() /2.5)  
registerDoParallel(cores = n_cores)

bert_df <- read_feather(here::here(jstor_raw_data, "embeddings_bert-base-uncased.feather")) %>% 
  mutate(doc_id = str_c(id, "_", paragraph_id)) %>% 
  arrange(doc_id)  

# Other possible file (ECONBERT): (here::here(jstor_raw_data, "embeddings_econbert.feather"))

# ---------------------- PCA ---------------------- #

# Generate decade breaks (1900-2020)
decades <- seq(1900, 2020, by = 10) 

# Create window labels (e.g., "1900-1909", "1910-1919")
time_windows <- map2(decades[-length(decades)], decades[-1] - 1, 
                     ~c(.x, .y)) %>%
  set_names(paste0(decades[-length(decades)], "-", decades[-1] - 1))

# Function to process each window
process_window <- function(years, df) {
  message(glue::glue("Starting window {years[1]}-{years[2]}"))
  # Filter data
  window_data <- df %>% 
    filter(between(publication_year, years[1], years[2]))
  
  # Create embeddings matrix and tibble
  bert_mat <- do.call(rbind, window_data$bert_embedding_concat)
  bert_tbl <- as_tibble(bert_mat) %>% 
    mutate(id = window_data$doc_id, .before = everything())
  
  # Recipe
  clust_recipe <- recipe(~ ., data = bert_tbl) %>%
    update_role(id, new_role = "id") %>% 
    step_normalize()
  
  # Tuning workflow
  kmeans_wf <- workflow() %>%
    add_recipe(clust_recipe) %>%
    add_model(k_means(num_clusters = tune()) %>% set_engine("stats"))
  
  # Tune clusters
  set.seed(89)
  tune_res <- tune_cluster(
    kmeans_wf,
    resamples = vfold_cv(bert_tbl, v = 3),
    grid = tibble(num_clusters = 4:6),
    metrics = cluster_metric_set(silhouette_avg),
    control = control_grid(parallel_over = "everything", save_pred = TRUE)
  )
  
  # Get best k
  best_k <- collect_metrics(tune_res) %>%
    filter(.metric == "silhouette_avg") %>%
    arrange(desc(mean)) %>%
    slice(1) %>%
    pull(num_clusters)
  
  # Final fit
  final_fit <- workflow() %>%
    add_recipe(clust_recipe) %>%
    add_model(k_means(num_clusters = best_k) %>% set_engine("stats")) %>%
    fit(data = bert_tbl)
  
  bert <- bert_tbl %>% 
    select(id) %>% 
    mutate(cluster = extract_cluster_assignment(final_fit)$.cluster,
           nb_cluster = best_k,
           window = paste(years[1], years[2], sep = "-"))
  centroids <- tidyclust::extract_centroids(final_fit) %>% 
    mutate(window = paste(years[1], years[2], sep = "-"))
  
  # Return results
  return(list("documents_partition" = bert,
              "centroids" = centroids))
}
results <- map(time_windows, ~process_window(.x, bert_df))

similarity_threshold <- 0.95
documents_partition <- map(1:length(results), ~pluck(results, ., "documents_partition")) %>% 
  bind_rows
centroids <- map(1:length(results), ~pluck(results, ., "centroids")) %>% 
  bind_rows %>% 
  mutate(cluster_original_id = 1:n())

centroid_matrix <- centroids %>%
  select(-.cluster, -window) %>%
  as.matrix()
cosine_sim <- lsa::cosine(t(centroid_matrix))
cosine_tbl <- as.data.frame(cosine_sim) %>%
  mutate(cluster_A = centroids$cluster_original_id) %>%
  pivot_longer(-cluster_A, names_to = "cluster_B", values_to = "similarity") %>%
  mutate(cluster_B = str_remove(cluster_B, "V") %>% as.integer()) %>% 
  filter(cluster_A < cluster_B) %>%  # Remove duplicates and self-comparisons
  arrange(desc(similarity)) %>% 
  left_join(select(centroids, original_cluster_A = .cluster, window_A = window, cluster_A = cluster_original_id)) %>% 
  left_join(select(centroids, original_cluster_B = .cluster, window_B = window, cluster_B = cluster_original_id)) 

similarity_threshold <- 0.95
clusters_to_merge <- cosine_tbl %>% 
  filter(similarity > similarity_threshold) %>% 
  select(cluster_A, cluster_B) %>% 
  arrange(cluster_A, cluster_B) %>% 
  mutate(new_cluster = min(cluster_A), .by = cluster_A) %>% 
  pivot_longer(cluster_A:cluster_B, values_to = "cluster_original_id") %>% 
  select(-name) %>% 
  unique() %>% 
  mutate(new_cluster = str_c("intertemporal_cluster_", min(new_cluster)), .by = cluster_original_id) %>% 
  unique() %>% 
  arrange(new_cluster) %>% 
  right_join(select(centroids, window, cluster = .cluster, cluster_original_id)) %>% 
  mutate(new_cluster = if_else(is.na(new_cluster), str_c("intertemporal_cluster_", cluster_original_id), new_cluster))

documents_partition <- documents_partition %>% 
  mutate(cluster = as.character(cluster)) %>% 
  left_join(clusters_to_merge, by = c("window", "cluster"))

documents_partition %>%
  count(window, new_cluster) %>%
  mutate(percent = n / sum(n), .by = window) %>%
  ggplot(aes(x = window, y = percent, fill = fct_rev(new_cluster))) +
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
  see::scale_fill_oi()

documents_partition %>%
  count(window, new_cluster) %>% 
  mutate(percent = n / sum(n), .by = window) %>%
  mutate(new_cluster = fct_rev(new_cluster)) %>% 
  ggplot(aes(x = window, y = percent, stratum = new_cluster, alluvium = new_cluster,
             fill = new_cluster, label = new_cluster)) +
  geom_flow(alpha = 0.7) +
  geom_stratum() +
  geom_text(stat = "stratum", size = 3) +
  labs(title = "Cluster Persistence Across Time Windows",
       x = "Time Period",
       y = "Percentage of Documents",
       fill = "Intertemporal Cluster") +
  theme_minimal() +
  see::scale_fill_oi()  # Better color palette
# Function to process each window

# Filter data and create matrix
window_data <- bert_df %>% 
  filter(between(publication_year, min(unlist(time_windows)), max(unlist(time_windows))))
bert_mat <- do.call(rbind, window_data$bert_embedding_concat)
# Run PCA (2 components)
pca <- prcomp_irlba(bert_mat, n = 2, center = TRUE, scale. = TRUE)
# Create tibble with results
all_articles_pca <- tibble(
  id = window_data$doc_id,
  PC1 = pca$x[, 1],
  PC2 = pca$x[, 2],
  # Add your existing cluster assignments here
) %>% 
  left_join(select(documents_partition, id, new_cluster))
# ---------------------- PLOTS ---------------------- #
plot_bert <- ggplot(all_articles_pca, aes(x = PC1, y = PC2, color = fct_rev(new_cluster))) +
  geom_point(size = 0.5) +
  theme_minimal() + 
  see::scale_color_oi() +
  labs(title = "BERT base", x = "PC1", y = "PC2")
