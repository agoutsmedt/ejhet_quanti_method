################## Finding inter-temporal clusters from BERT rational paragraph ----------------------
# ---------------------- LIBRAIRIES ---------------------- #

source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(arrow,
               tidymodels,
               tidyclust,
               irlba,
               doParallel)
# Detect and use all available cores (minus 1 for safety)
n_cores <- floor(parallel::detectCores() /2.5)  
registerDoParallel(cores = n_cores)

bert_df <- read_feather(here::here(jstor_raw_data, "embeddings_bert-base-uncased.feather")) %>% 
  mutate(doc_id = str_c(id, "_", paragraph_id)) %>% 
  arrange(doc_id)  

#econ_df <- read_feather(here::here(jstor_raw_data, "embeddings_econbert.feather"))

# ---------------------- PCA ---------------------- #
# Define time windows
time_windows <- list(
  c(1950, 1954),
  c(1955, 1959),
  c(1960, 1964)
)

# Function to process each window
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
    grid = tibble(num_clusters = 4:8),
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
    mutate(cluster = extract_cluster_assignment(final_fit)$.cluster,
           nb_cluster = best_k,
           window = paste(years[1], years[2], sep = "-"))
  
  # Return results
  return(bert)
}

# Process all windows (parallel if needed)
results <- map(time_windows, ~process_window(.x, bert_df))

pca_results <- prcomp_irlba(bert_mat, n = 2, center = TRUE, scale. = TRUE)  # Top 50 PCs
bert_tbl <- bert_tbl %>% 
  mutate(PC1 = pca_results$x[, 1], 
         PC2 = pca_results$x[, 2],
         cluster = extract_cluster_assignment(final_fit)$.cluster)

# ---------------------- PLOTS ---------------------- #
plot_bert <- ggplot(bert_tbl, aes(x = PC1, y = PC2, color = cluster)) +
  geom_point(size = 0.5) +
  theme_minimal() + 
  see::scale_color_oi() +
  labs(title = "BERT base", x = "PC1", y = "PC2")




# Get centroids
centroids <- extract_centroids(final_fit)
