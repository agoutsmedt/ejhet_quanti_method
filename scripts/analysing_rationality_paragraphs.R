################## Analysing Inter-Temporal Clusters##################

# LOADING DATA AND LIBRARIES----------------------
source(file.path("scripts", "paths_and_packages.R"))
p_load(see)

## Bert rational paragraph loading--------------------
bert_df <- read_feather(here::here(jstor_raw_data, "embeddings_bert-base-uncased.feather")) %>% 
  filter(between(publication_year, 1900, 2019)) %>% 
  mutate(doc_id = str_c(id, "_", paragraph_id)) %>% 
  arrange(doc_id)  

metadata <- read_rds(file.path(data_path, "full_metadata_journals_cleaned.rds")) %>% 
  # Only keep research articles for now because other types are quite messy and avoid overloading the memory
  .[ refined_sub_type == "research-article" & language == "eng", .(id, is_part_of, title, creator, publication_year)] %>% 
  .[order(publication_year)] 

documents_cluster <- readRDS(file.path(data_path, "paragraphs_intertemporal_cluster.rds")) %>% 
  rename(doc_id = id) %>% 
  mutate(id = str_remove(doc_id, "_\\d+$")) %>% 
  left_join(metadata)

# Join cluster info to bert_df
bert_df <- bert_df %>%
  left_join(documents_cluster %>% select(doc_id, new_cluster, time_window = window, is_part_of, title), by = c("doc_id")) 

# Naming clusters ---------------------
setDT(bert_df)
unigrams <- bert_df[, .(doc_id, window, new_cluster)][, token := tokenizers::tokenize_words(window, lowercase = TRUE)][, -("window")]
bigrams <- bert_df[, .(doc_id, window, new_cluster)][, token := tokenizers::tokenize_ngrams(window, n= 2, lowercase = TRUE)][, -("window")]
tokens <- rbind(unigrams,
                bigrams)
tokens <- tokens[, .(token = unlist(token)), by = new_cluster]
tokens <- tokens[nchar(token) >= 2, ]
tokens <- tokens[, c("word_1", "word_2") := tstrsplit(token, " ")]

stop_words <- tidytext::stop_words$word %>% 
  unique()
tokens <- tokens[
  # Remove any digits in either word
  !grepl("[0-9]", word_1) & (is.na(word_2) | !grepl("[0-9]", word_2)) &
  # Remove stopwords in either word
    !(word_1 %in% stop_words) &
    (is.na(word_2) | !(word_2 %in% stop_words))
]
tokens <- tokens[, .(new_cluster, token)]

tokens[, absolute_tf := .N, by = token]
tokens[, nb_word := .N, by = new_cluster]
tokens[, tf := .N/nb_word, by = .(new_cluster, token)]
tokens_count <- unique(tokens)
# Calculating tf-idf
tf_dt <- tokens[, .N, by = .(new_cluster, token)]  # N = term frequency
setnames(tf_dt, "N", "tf")

df_dt <- tokens_count[, .N, by = token]  # each token per document, once
setnames(df_dt, "N", "df")

total_docs <- uniqueN(tokens_count$new_cluster)
# Merge TF with DF
tokens_count <- merge(tokens_count, df_dt, by = "token", all.x = TRUE)

# Compute IDF and TF-IDF
tokens_count[, idf := log(total_docs / df)]
tokens_count[, tf_idf := tf * idf]

# Get top 4 tf-idf tokens per cluster
labels_dt <- tokens_count[order(-tf_idf)][absolute_tf > 15, head(.SD, 4), by = new_cluster][, .(new_cluster, token)]
labels_dt <- labels_dt[, .(label = paste(token, collapse = ", ")), by = new_cluster]

bert_df <- merge(bert_df, labels_dt, all.x = TRUE, by = "new_cluster")

# Top tf-idf terms
top_terms <- tokens_count[order(-tf_idf)][absolute_tf > 15, head(.SD, 15), by = new_cluster]

top_terms %>% 
  mutate(token = reorder_within(token, tf_idf, new_cluster)) %>% 
ggplot(aes(x = token, y = tf_idf)) +
  geom_col(fill = "#2C77B8") +
  facet_wrap(~ new_cluster, scales = "free_y") +
  coord_flip() +
  scale_x_reordered() +
  labs(title = "Top 10 TF-IDF Tokens per Intertemporal Cluster",
       x = "Token", y = "TF-IDF") +
  theme_minimal(base_size = 12)
ggsave("pictures/tf_idf_cluster_rationality.png",
       width = 60,
       height = 40,
       units = "cm",
       dpi = 300)

# Distribution by year-------------
# Plot distribution by year and cluster
bert_df %>%
  count(publication_year, new_cluster) %>%
  ggplot(aes(x = publication_year, y = n, color = new_cluster)) +
  geom_line() +
  theme_minimal() +
  labs(title = "Document Distribution by Year and Cluster",
       x = "Publication Year", y = "Number of Documents", color = "Cluster") +
  scale_color_see()


tf_dt <- tokens_clean[, .N, by = .(new_cluster, token)]  # N = term frequency# Calculate proportions per year
yearly_cluster_dist <- bert_df %>%
  count(publication_year, new_cluster) %>%
  mutate(proportion = n / sum(n), .by = publication_year)

areas_cluster <- ggplot(bert_df, aes(x = publication_year, y = after_stat(count), fill = label)) +
  geom_density(position = "fill", show.legend = TRUE) +
  theme_minimal() +
  labs(title = "Proportion of Clusters Over Time",
       x = "Publication Year",
       y = "Proportion of Documents",
       fill = "Cluster") +
  scale_y_continuous(labels = scales::percent_format()) +
  theme(legend.position = "bottom") +
  scale_fill_see() 
plotly::ggplotly(areas_cluster)

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

# Top words-----------------------
# Top target words per cluster
top_words_cluster <- bert_df %>%
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
bert_dt <- as.data.table(bert_df)

# Expand bert_embedding_concat list into separate columns
# Assume each embedding is length 3072
bert_dt <- bert_dt[, as.data.table(do.call(rbind, bert_embedding_concat))]
bert_dt$new_cluster <- bert_df$new_cluster

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

# Run similarity search per cluster and per window
top_paragraphs_per_cluster_window <- map_dfr(clusters, function(cluster) {
  
  # Filter paragraphs for this cluster
  bert_dt$time_window <- bert_df$time_window
  bert_dt$doc_id <- bert_df$doc_id
  cluster_paragraphs <- bert_dt[new_cluster == cluster]
  
  # Get unique time windows in this cluster
  time_windows <- unique(bert_df$time_window)
  
  # Extract the centroid for this cluster
  centroid_vec <- centroid_mat[cluster, , drop = FALSE]
  
  # Run similarity search per time window
  map_dfr(time_windows, function(window) {
    
    # Select paragraphs in this window
    window_paragraphs <- cluster_paragraphs[time_window == window]
    if (nrow(window_paragraphs) == 0) return(NULL)  # Skip empty groups
    
    window_mat <- as.matrix(window_paragraphs[, ..embedding_cols])
    rownames(window_mat) <- window_paragraphs$doc_id
    
    # Calculate cosine similarity for this window
    sim_vec <- text2vec::sim2(x = window_mat, y = centroid_vec, method = "cosine", norm = "l2")[, 1]
    
    # Get top N most similar paragraphs in this window
    top_idx <- order(sim_vec, decreasing = TRUE)[1:min(5, length(sim_vec))]
    
    data.table(
      new_cluster = cluster,
      time_window = window,
      doc_id = names(sim_vec)[top_idx],
      similarity = sim_vec[top_idx],
      rank = 1:length(top_idx)
    )
  })
})

top_paragraphs_per_cluster_window <- top_paragraphs_per_cluster_window  %>% 
  left_join(select(bert_df, doc_id, window, publication_year))

# Now we just keep the n most important paragraphs for the whole cluster (among the selection of top_n per window)
top_paragraphs_per_cluster <- top_paragraphs_per_cluster_window %>% 
  slice_max(order_by = similarity, by = new_cluster, n = 10)
