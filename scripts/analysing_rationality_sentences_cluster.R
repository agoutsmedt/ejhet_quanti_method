################## Analysing Inter-Temporal Clusters##################

# LOADING DATA AND LIBRARIES----------------------
source(file.path("scripts", "paths_and_packages.R"))
p_load(see)

## Bert rational paragraph loading--------------------
bert_df <- readRDS(file.path(data_path, "closest_sentences_0.01_rationality_score_with_embeddings.rds")) #%>% 
  # mutate(doc_id = str_c(id, "_", paragraph_id)) %>% 
  # arrange(doc_id)  

metadata <- read_rds(file.path(data_path, "full_metadata_journals_cleaned.rds")) %>% 
  # Only keep research articles for now because other types are quite messy and avoid overloading the memory
  .[ refined_sub_type == "research-article" & language == "eng", .(id, is_part_of, title, creator, publication_year)] %>% 
  .[order(publication_year)] 

documents_cluster <- readRDS(file.path(data_path, "sentences_intertemporal_cluster.rds")) %>% 
  left_join(select(bert_df, id, sentence, sentence_id)) %>% 
  left_join(metadata)

# Naming clusters ---------------------
setDT(documents_cluster)
unigrams <- documents_cluster[, .(sentence_id, sentence, new_cluster)][, token := tokenizers::tokenize_words(sentence, lowercase = TRUE)][, -("sentence")]
bigrams <- documents_cluster[, .(sentence_id, sentence, new_cluster)][, token := tokenizers::tokenize_ngrams(sentence, n= 2, lowercase = TRUE)][, -("sentence")]
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

tokens_count <- compute_tf_idf(tokens, 
               token_col = "token", 
               document_col = "new_cluster")

# Get top 4 tf-idf tokens per cluster
labels_dt <- tokens_count[order(-tf_idf)][absolute_tf > 20, head(.SD, 5), by = new_cluster][, .(new_cluster, token)]
labels_dt <- labels_dt[, .(label = paste(token, collapse = ", ")), by = new_cluster]

documents_cluster <- merge(documents_cluster, labels_dt, all.x = TRUE, by = "new_cluster")

# Top tf-idf terms
top_terms <- tokens_count[order(-tf_idf)][absolute_tf > 20, head(.SD, 15), by = new_cluster]

top_terms %>% 
  mutate(token = reorder_within(token, tf_idf, new_cluster)) %>% 
ggplot(aes(x = token, y = tf_idf)) +
  geom_col(fill = "#2C77B8") +
  facet_wrap(~ new_cluster, scales = "free") +
  coord_flip() +
  scale_x_reordered() +
  labs(title = "Top 10 TF-IDF Tokens per Intertemporal Cluster",
       x = "Token", y = "TF-IDF") +
  theme_bw(base_size = 12)
ggsave("pictures/tf_idf_cluster_rationality.png",
       width = 60,
       height = 40,
       units = "cm",
       dpi = 300)

# Distribution by year-------------
# Plot distribution by year and cluster
distribution_by_year <- documents_cluster %>%
  count(publication_year, new_cluster) %>%
  ggplot(aes(x = publication_year, y = n, color = new_cluster)) +
  geom_line() +
  theme_minimal() +
  labs(title = "Document Distribution by Year and Cluster",
       x = "Publication Year", y = "Number of Documents", color = "Cluster") +
  scale_color_see()
plotly::ggplotly(distribution_by_year)

yearly_cluster_dist <- documents_cluster %>%
  count(publication_year, new_cluster) %>%
  mutate(proportion = n / sum(n), .by = publication_year)

areas_cluster <- ggplot(documents_cluster, aes(x = publication_year, y = after_stat(count), fill = label)) +
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

# 2. Alluvial plot showing cluster persistence
all_clusters <- levels(factor(documents_cluster$label)) %>% sample()
# Preview the default 'see' palette to get the colors
palette_colors <- c(see::see_colors(), see::oi_colors(), scico::scico(n = 10, palette = "roma"))  # Example for the see_d palette
# If you use another palette, replace accordingly
# Let's say you use 8 clusters and 8 colors from the palette
cluster_colors <- palette_colors[1:length(all_clusters)]
names(cluster_colors) <- all_clusters

label_alluvial <- documents_cluster %>% 
  distinct(label, window) %>% 
  mutate(first_year = str_extract(window, "\\d{4}") %>% as.integer()) %>% 
  mutate(label_alluvial = first_year == min(first_year), .by = label) %>%
  filter(label_alluvial == TRUE) %>%
  distinct(label, window) %>%
  mutate(label_alluvial = label)

documents_cluster %>%
  left_join(label_alluvial) %>% 
  count(window, label, label_alluvial) %>% 
  mutate(percent = n / sum(n), .by = window) %>%
  mutate(label = factor(label, levels= all_clusters)) %>% 
  ggplot(aes(x = window, y = percent, stratum = label, alluvium = label,
             fill = label, label = str_wrap(label_alluvial, 25))) +
  geom_flow(alpha = 0.9) +
  geom_stratum() +
  geom_text(stat = "stratum", size = 3) +
  labs(title = "Cluster Persistence Across Time Windows",
       x = "Time Period",
       y = "Percentage of Documents",
       fill = "Intertemporal Cluster") +
  theme_light() +
  theme(legend.position = "none") +
  scale_fill_manual(values = cluster_colors)  # HARD color lock

ggsave(file.path("pictures", "intertemporal_clusters_alluvial.png"),
       units = "cm",
       width = 40,
       height = 30,
       dpi = 300)

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
