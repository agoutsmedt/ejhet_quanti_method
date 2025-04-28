# ------------------------- load libraries --------------------------- #

source(file.path("scripts", "paths_and_packages.R"))

# ------------------------- load data --------------------------- #

df <- arrow::read_feather(file.path(jstor_raw_data, "bert_vectors", "paragraphs_with_concat_embeddings.feather"))
setDT(df)
# ------------------------- K mean and PCA --------------------------- #

library(cluster)  # silhouette
library(stats)    # kmeans
library(purrr)   

# vectors in matrix 

matrix_vectors <- do.call(rbind, df$bert_embedding_concat)

# # silhouette 
# 
# k_range <- 2:10
# 
# # Function to run 10 times for each K
# get_best_kmeans_silhouette <- function(k, data) {
#   results <- vector("list", 10)  # store kmeans models
#   distortions <- numeric(10)     # store distortions
#   
#   for (i in 1:10) {
#     km <- kmeans(data, centers = k, nstart = 1)
#     results[[i]] <- km
#     distortions[i] <- km$tot.withinss  # total within-cluster sum of squares (distortion)
#   }
#   
#   # Find best model (minimal distortion)
#   best_idx <- which.min(distortions)
#   best_km <- results[[best_idx]]
#   
#   # Calculate silhouette score for best clustering
#   sil <- silhouette(best_km$cluster, dist(data))
#   mean(sil[, 3])  # Return mean silhouette score
# }

# Apply for each K

# future::plan(multisession, core = 8) # Use multiple cores for parallel processing
# silhouette_scores <- furrr::future_map_dbl(k_range, get_best_kmeans_silhouette, data = matrix_vectors)


best_k <- 5 # Set the best k manually for now

final_kmeans <- kmeans(matrix_vectors, centers = best_k, nstart = 25)

# Ajoute cluster
df[, cluster := final_kmeans$cluster]


# ------------------------- INTERPRET CLUSTERS --------------------------- #
# strategy: get top 5 paragraphs the closer to the centroid by cluster

# compute centroids of clusters

cluster_centroids <- df[, .(centroid = list(colMeans(do.call(rbind, bert_embedding_concat)))), by = cluster]


df <- merge(df, cluster_centroids, by = "cluster")

# Compute distance between paragraph vector and cluster centroid
df[, distance_to_centroid :=
     sqrt(rowSums((
       do.call(rbind, bert_embedding_concat) - do.call(rbind, centroid)
     )^2))]

# Rank paragraphs by distance within each cluster
df[, rank := rank(distance_to_centroid), by = cluster]

# Select top 5 closest paragraphs per cluster, keep only the relevant columns
top5_per_cluster <- df[rank <= 5][, .(id, cluster, rank, paragraph_text, target_word)]

# Optional: order nicely
setorder(top5_per_cluster, cluster, rank)

# tribble with name clusters (draft)

cluster_names <- tribble(
  ~cluster, ~name,
  1, "Cluster 1: Rational behaviors",
  2, "Cluster 2: Constraints",
  3, "Cluster 3: Rational expectations",
  4, "Cluster 4: Uncertainty",
  5, "Cluster 5: Modeling rationality"
)

# add color from ggsci::npg to each cluster
setDT(cluster_names)
cluster_names[, color := ggsci::pal_npg()(nrow(cluster_names))]


# add names to clusters
df <- merge(df, cluster_names, by = "cluster", all.x = TRUE)


# ------------------------- CLUSTER THROUGH TIME --------------------------- #

# estimate normalized frequency of each cluster in each year

# convert year to integer (problem with arrow)
df[, year := as.integer(publicationYear)]

cluster_freq <- df[, .N, by = .(year, cluster, name, color)] %>% 
  .[, freq := N / sum(N), by = year] 


# plot in a geom area (switch to tidyverse)

cluster_freq %>%
  ggplot(aes(x = as.integer(year), 
             y = freq, 
             fill = name)) +  
  # geom_area(position = "fill") +
  geom_density(aes(y = ..density..), 
               alpha = 0.5, 
               position = "fill",
               adjust = 0.5) +  
  scale_fill_manual(values = setNames(cluster_freq$color, cluster_freq$name)) +
  theme_minimal() +
  labs(x = "Year",
       y = "",
       fill = "Cluster") +  # <-- correct label for fill
  theme(legend.position = "bottom")


# ------------------------- CLUSTER IN PCA --------------------------- #

# PCA

pca_result <- prcomp(matrix_vectors, center = TRUE, scale. = TRUE)
pca_result$rotation <- pca_result$rotation[, 1:2] # Keep only first two components

# plot with clusters 

pca_result_dt <- as.data.table(pca_result$x)
pca_result_dt[, cluster := factor(final_kmeans$cluster)]

# merge with name 
cluster_names$cluster <- as.factor(cluster_names$cluster)
pca_result_dt <- merge(pca_result_dt, cluster_names, by = "cluster", all.x = TRUE)
                      
ggplot(pca_result_dt, aes(x = PC1, y = PC2, color = name)) +
  geom_point(alpha = 0.5) +
  scale_color_manual(values = setNames(pca_result_dt$color, pca_result_dt$name)) + 
  theme_void() +
  labs(color = "Cluster") + 
  theme(legend.position = "bottom") +
  guides(color = guide_legend(override.aes = list(size = 5))) # make legend points bigger
