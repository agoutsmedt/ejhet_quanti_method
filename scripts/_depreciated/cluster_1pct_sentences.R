################## Finding Inter-Temporal Clusters from BERT Sentence Embeddings ##################
# This script analyzes textual data using BERT embeddings to identify persistent thematic
# clusters across different time periods. It performs:
# 1. Time window creation (decadal)
# 2. K-means clustering within each window
# 3. Inter-temporal cluster merging based on centroid similarity
# 4. Visualization of results

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
