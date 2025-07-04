################## Analysing Inter-Temporal Clusters##################


# LOADING DATA AND LIBRARIES----------------------
source(file.path("scripts", "paths_and_packages.R"))

## Bert rational paragraph loading--------------------
bert_df <- read_feather(here::here(jstor_raw_data, "embeddings_bert-base-uncased.feather")) %>% 
  filter(between(publication_year, 1900, 2019)) %>% 
  mutate(doc_id = str_c(id, "_", paragraph_id)) %>% 
  arrange(doc_id)  

# Join cluster info to bert_df
bert_clustered <- bert_df %>%
  left_join(documents_cluster %>% select(doc_id, new_cluster), by = c("doc_id"))

metadata <- read_rds(file.path(data_path, "full_metadata_journals_cleaned.rds")) %>% 
  # Only keep research articles for now because other types are quite messy and avoid overloading the memory
  .[ refined_sub_type == "research-article" & language == "eng", .(id, is_part_of, title, creator, publication_year)] %>% 
  .[order(publication_year)] 

documents_cluster <- readRDS(file.path(data_path, "paragraphs_intertemporal_cluster.rds")) %>% 
  rename(doc_id = id) %>% 
  mutate(id = str_remove(doc_id, "_\\d+$")) %>% 
  left_join(metadata)


# Distribution by year-------------
# Plot distribution by year and cluster
bert_clustered %>%
  count(publication_year, new_cluster) %>%
  ggplot(aes(x = publication_year, y = n, color = new_cluster)) +
  geom_line() +
  theme_minimal() +
  labs(title = "Document Distribution by Year and Cluster",
       x = "Publication Year", y = "Number of Documents", color = "Cluster") +
  scale_color_see()

# Calculate proportions per year
yearly_cluster_dist <- bert_clustered %>%
  count(publication_year, new_cluster) %>%
  mutate(proportion = n / sum(n), .by = publication_year)

ggplot(bert_clustered, aes(x = publication_year, y = after_stat(count), fill = new_cluster)) +
  geom_density(position = "fill", show.legend = TRUE) +
  theme_minimal() +
  labs(title = "Proportion of Clusters Over Time",
       x = "Publication Year",
       y = "Proportion of Documents",
       fill = "Cluster") +
  scale_y_continuous(labels = scales::percent_format()) +
  theme(legend.position = "bottom") +
  scale_fill_see()


# Top Journals----------
# Join journal info with cluster assignments
journal_totals <- documents_cluster %>%
  count(is_part_of, name = "total_journal_docs") %>% 
  filter(total_journal_docs > 200)

cluster_journal_counts <- documents_cluster %>%
  count(new_cluster, is_part_of, name = "cluster_docs")

top_journals_cluster <- cluster_journal_counts %>%
  left_join(journal_totals, by = "is_part_of") %>%
  mutate(proportion = cluster_docs / total_journal_docs) %>%
  mutate(is_part_of = str_wrap(is_part_of, 20)) %>%
  slice_max(proportion, n = 5, by = new_cluster)

# Plot top journals per cluster
top_journals_cluster %>% 
  mutate(is_part_of = reorder_within(is_part_of, proportion, new_cluster)) %>% 
ggplot(aes(x = reorder(is_part_of, proportion), y = proportion, fill = new_cluster)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ new_cluster, scales = "free") +
  coord_flip() +
  theme_minimal() +
  scale_x_reordered() +
  labs(title = "Top Journals per Cluster", x = "Journal", y = "Number of Documents") +
  scale_fill_see()

# Top words---------------------
# Top target words per cluster
top_words_cluster <- bert_clustered %>%
  count(new_cluster, target_word, sort = TRUE) %>%
  mutate(proportion = n/sum(n)) %>% 
  group_by(new_cluster) %>%
  slice_max(n, n = 5) %>%
  ungroup()

# Plot top words per cluster
ggplot(top_words_cluster, aes(x = reorder(target_word, proportion), y = proportion, fill = new_cluster)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ new_cluster, scales = "free") +
  coord_flip() +
  theme_minimal() +
  labs(title = "Top Words per Cluster", x = "Target Word", y = "Frequency") +
  scale_fill_see()

# Top paragraphs----------------------------------
# Build embedding matrix

# Convert to data.table
bert_dt <- as.data.table(bert_clustered)

# Expand bert_embedding_concat list into separate columns
# Assume each embedding is length 3072
bert_dt <- bert_dt[, as.data.table(do.call(rbind, bert_embedding_concat))]
bert_dt$new_cluster <- bert_clustered$new_cluster
bert_dt$doc_id <- bert_clustered$doc_id

# Calculate mean of each dimension by new_cluster
cluster_centroids <- bert_dt[, lapply(.SD, mean), by = new_cluster]

# Ensure embedding columns are correctly selected
embedding_cols <- setdiff(names(bert_dt), "new_cluster")

# Build paragraph matrix with doc_id as row names
paragraph_mat <- as.matrix(bert_dt[, ..embedding_cols])
rownames(paragraph_mat) <- bert_df$doc_id

# Build centroid matrix with new_cluster as row names
centroid_mat <- as.matrix(cluster_centroids[, ..embedding_cols])
rownames(centroid_mat) <- cluster_centroids$new_cluster

# Calculate cosine similarity between paragraphs and centroids
#similarity_matrix <- text2vec::sim2(x = paragraph_mat, y = centroid_mat, method = "cosine", norm = "l2")

# Get the list of clusters
clusters <- unique(bert_dt$new_cluster)

# Set how many top paragraphs you want
top_n <- 10

# Run the similarity search per cluster
top_paragraphs_per_cluster <- map_dfr(clusters, function(cluster) {
  
  # Select paragraphs from this cluster
  cluster_paragraphs <- bert_dt[new_cluster == cluster]
  cluster_mat <- as.matrix(cluster_paragraphs[, ..embedding_cols])
  rownames(cluster_mat) <- cluster_paragraphs$doc_id
  
  # Extract the centroid for this cluster
  centroid_vec <- centroid_mat[cluster, , drop = FALSE]
  
  # Calculate cosine similarity for this cluster
  sim_vec <- text2vec::sim2(x = cluster_mat, y = centroid_vec, method = "cosine", norm = "l2")[, 1]
  
  # Get top N most similar paragraphs
  top_idx <- order(sim_vec, decreasing = TRUE)[1:top_n]
  
  data.table(
    new_cluster = cluster,
    doc_id = names(sim_vec)[top_idx],
    similarity = sim_vec[top_idx],
    rank = 1:top_n
  )
})

top_paragraphs_per_cluster <- top_paragraphs_per_cluster  %>% 
  left_join(select(bert_df, doc_id, window, publication_year))
