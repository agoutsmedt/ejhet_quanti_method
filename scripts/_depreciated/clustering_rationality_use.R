################## Clustering of Rationality use##################

# Loading Libraries and data
source(file.path("scripts", "paths_and_packages.R"))
p_load(tokenizers,
       tidytext,
       text2vec)

# load the embeddings
glove <- read_rds(file.path(data_path, glue("glove_model_jstor.rds")))
wv_main <- read_rds(file.path(data_path, glue("word_vectors_300d.rds")))

wv_context <- glove$components
word_vectors <- wv_main + t(wv_context)
word_vectors_df <- as.data.table(word_vectors)
word_vectors_df$term <- rownames(word_vectors)
rm(wv_context,
   wv_main,
   glove,
   word_vectors)

metadata <- read_rds(file.path(data_path, "full_metadata_journals_cleaned.rds")) %>% 
    .[refined_sub_type == "research-article" & language == "eng", .(id, is_part_of, title, publication_year)] %>%
    .[order(publication_year)]

# Collecting text
con <- DBI::dbConnect(RSQLite::SQLite(), file.path(jstor_raw_data, "jstor_journals.sqlite"))
text_db <- tbl(con, "text_cleaned")

ids <- metadata[between(publication_year, 1975, 1980),]$id
df_text <- text_db %>%
  filter(!is.na(text),
         type == "main_text",
         id %in% ids) %>%
  collect() %>%
  as.data.table()
dbDisconnect(con)

# Extracting rationality texts--------------
# Function to extract context words
extract_context <- function(text, keywords, window = 10) {
  # Split text into words
  words <- unlist(str_split(text, "\\s+"))
  
  # Find positions of keywords
  matches <- which(tolower(words) %in% keywords)
  
  # If no match, return NA
  if (length(matches) == 0) return(NA)
  
  # Extract words around each match
  result <- sapply(matches, function(i) {
    start <- max(1, i - window)
    end <- min(length(words), i + window)
    paste(words[start:end], collapse = " ")
  })
  
  return(result)
}

# Define keywords
keywords <- c("rational", "rationality")

# Apply function to each row
df_text[, rational_text := lapply(text, extract_context, keywords = keywords, window = 20)]

rational_texts <- df_text[! is.na(rational_text), .(id, rational_text)]
# Unnest the rational texts
rational_texts <- rational_texts[, .(rational_text = unlist(rational_text)), by = id]
rational_texts[, doc_id := paste0(id, "_", seq_len(.N)), by = id]  # Create a unique doc_id for each rational text
rational_texts[, rational_text := str_replace_all(rational_text, "'s|'s", "")]

# Creating the embeddings of rational texts----------

# tokenizing and calculating tf-idf
tokens <- rational_texts[, .(doc_id, tokens = tokenize_words(rational_text, lowercase = TRUE, strip_punct = TRUE, strip_numeric = TRUE))]
tokens <- tokens[, .(position = seq_along(tokens[[1]]), term = unlist(tokens)), by = doc_id] # Unnest tokens and add positions

# Identify positions of "rational" or "rationality" in each doc
target_positions <- tokens[tolower(term) %in% c("rational", "rationality"), .(target_pos = position), by = doc_id]
# select the first target_pos
target_positions <- target_positions[, .(target_pos = min(target_pos)), by = doc_id]

# Merge target positions into tokens
tokens <- merge(tokens, target_positions, by = "doc_id", all.x = TRUE)

# Function to calculate distance to nearest target word
tokens[, distance := abs(position - target_pos)]

tokens <- tokens[! term %in% stop_words$word & term %in% word_vectors_df$term,]  # Remove stopwords or non embedded words
tokens[, term := str_remove_all(term, "[^[:alnum:] ]")]  # Remove special characters
tokens[, n := .N, by = c("doc_id", "term")]
tokens[, total_occurrence := sum(n), by = term]
tf_idf <- tokens %>% 
  filter(total_occurrence > 20) %>% 
  distinct(term, doc_id, n) %>% 
  bind_tf_idf(term, doc_id, n) %>% 
  select(term, doc_id, tf_idf)
tokens <- merge(tokens, tf_idf, by = c("term", "doc_id"), all.x = TRUE)
tokens[, distance_weight := exp(-0.5 * distance)]
tokens[is.na(tf_idf), tf_idf := 0]  # Set tf_idf to 0 for terms not present in tf_idf calculation
tokens <- tokens[! str_detect(term, "[^[A-z] ]"),] # detect special character

#tokens[term %in% keywords, tf_idf := 1]  # Set tf_idf to 0 for specific terms

#tokens[tf_idf > 1]  
# filter word vectors
word_vectors_df <- word_vectors_df[term %in% tokens$term,]

# Merge on 'term'
embeddings <- merge(tokens,
                    word_vectors_df,
                    by = "term",
                    all = FALSE,
                    allow.cartesian = TRUE)

vector_cols <- grep("^V", names(embeddings), value = TRUE)  # Select vector columns
embeddings[, (vector_cols) := lapply(.SD, function(x) x * tf_idf * distance_weight), .SDcols = vector_cols]
embeddings[, (vector_cols) := lapply(.SD, mean), by = doc_id, .SDcols = vector_cols]
embeddings <- embeddings[order(doc_id), -c("n", "term", "position", "target_pos", "distance", "distance_weight", "total_occurrence", "tf_idf")] %>% 
  unique()

# Clustering the rational texts----------

pca_result <- prcomp(as.matrix(embeddings[, -c("doc_id")]), center = TRUE, scale. = TRUE)
# # Choose number of components (e.g., keep 50)
# n_components <- 2
# reduced_embeddings <- as.data.frame(pca_result$x[, 1:n_components])
# documents <- bind_cols(embeddings[, .(doc_id)], reduced_embeddings)    

p_load(dbscan)
# Find nearest neighbor distances
# Set minPts (recommended: minPts = 2 * number of PCA components)
minPts <- 2 * ncol(embeddings)  # Example
kNNdistplot(as.matrix(embeddings[, -c("doc_id")]), k = 10)  # k = minPts - 1, so here minPts = 6 is a good start
abline(h = 0.2, col = "red")  # Example, adjust based on the elbow point you see

# Choose eps based on your kNN plot
dbscan_result <- dbscan(as.matrix(embeddings[, -c("doc_id")]), eps = 0.5, minPts = 5)
# 
# # Add DBSCAN cluster labels to your table
rational_texts$dbscan_cluster <- dbscan_result$cluster

p_load(mclust)
gmm_result <- Mclust(as.matrix(embeddings[, -c("doc_id")]), G = 5)
clusters <- gmm_result$classification

# kmeans cluster
kmeans_result <- kmeans(as.matrix(embeddings[, -c("doc_id")]), centers = 5, nstart = 5, iter.max = 1000)

# embeddings$kmeans_cluster <- kmeans_result$cluster
rational_texts$kmeans_cluster <- kmeans_result$cluster
# 
# rational_texts <- rational_texts[, .(id, doc_id, rational_text)]
# rational_texts <- merge(rational_texts,
#       embeddings[, .(doc_id, kmeans_cluster)],
#       by = "doc_id")

# Use PCA to reduce to 2 dimensions for plotting
pca_df <- data.frame(pca_result$x[, 1:5])
pca_df$cluster <- as.factor(rational_texts$kmeans_cluster)
pca_df$id <- rational_texts$id

ggplot(pca_df, aes(x = PC1, y = PC2, color = cluster)) +
  geom_point(size = 0.5) +
  see::scale_color_oi() +
  theme_minimal() +
  labs(title = "Clusters of Rational Texts (PCA Projection)")

# Top words of clusters
tokens_clusters <- rational_texts %>% 
  unnest_tokens(term, rational_text, token = "ngrams", n_min = 1, n = 1) %>%
  filter(! term %in% stop_words$word) %>% 
  count(kmeans_cluster, term, sort = TRUE) %>%
  mutate(total_occurence = sum(n), .by = term) %>%
  filter(total_occurence > 15 & n > 5) %>%
  bind_tf_idf(term, kmeans_cluster, n) %>% 
  slice_max(order_by = tf_idf, n = 15, by = kmeans_cluster, with_ties = FALSE)

# closest words 
kmeans_centroids <- kmeans_result$centers

# Replace term column first in word_vectors_df
glove_matrix <- word_vectors_df[term %in% tokens$term , -"term"] %>% 
  as.matrix()
rownames(glove_matrix) <- word_vectors_df[term %in% tokens$term]$term

# Compute similarity with other words
similarities <- sim2(kmeans_centroids, glove_matrix, method = "cosine", norm = "none")
# Convert similarity matrix to data.table
similarity_dt <- as.data.table(similarities)
similarity_dt$centroid <- 1:nrow(similarities)

# Reshape to long format for easy sorting
similarity_long <- melt(similarity_dt, id.vars = "centroid", variable.name = "word", value.name = "similarity")

# 1. Precompute the total similarity per word
similarity_long[, total_similarity := sum(similarity), by = word]

# 2. Calculate other_similarity by simple subtraction (vectorized)
similarity_long[, other_similarity := total_similarity - similarity]

# Get global importance (from your token table)
# Assume you have a table: tokens_total_occurrence (word, total_occurrence)
# Merge importance into similarity table
similarity_long <- merge(similarity_long, unique(tokens[, .(word = term, total_occurrence)]), by = "word", all.x = TRUE)

# Calculate the composite score
similarity_long[, composite_score := (similarity / other_similarity) * total_occurrence]
top_composite_words <- similarity_long[, .SD[order(-composite_score)][1:25], by = centroid]

similarity_long[, total_similarity := sum(similarity), by = word]
top_n_words <- similarity_long[, .SD[order(-similarity)][1:100], by = centroid]

# Calculate relative similarity
top_n_words[, relative_similarity := similarity / total_similarity]
# For each centroid, get top N most similar words
top_n_words <- top_n_words[, .SD[order(-relative_similarity)][1:25], by = centroid]

ggplot(top_composite_words, aes(x = reorder_within(word, composite_score, centroid), y = composite_score, fill = factor(centroid))) +
  geom_bar(stat = "identity") +
  coord_flip() +
  facet_wrap(~ centroid, scales = "free") +
  theme_minimal() +
  tidytext::scale_x_reordered() +
  see::scale_fill_oi() +
  labs(title = "Top Distinctive Words per Centroid (Relative Similarity)", x = "Word", y = "Relative Similarity")

# Variance explained by PCA
variance_explained <- pca_result$sdev^2 / sum(pca_result$sdev^2)
# For axis 1 and 2
variance_explained[1:5] * 100

# Top documents
rational_texts <- rational_texts %>%
  left_join(metadata) 

rational_texts %>% 
  count(kmeans_cluster, is_part_of) %>% 
  bind_tf_idf(term = is_part_of, document = kmeans_cluster, n = n) %>% 
 # mutate(weighted_n = (n - mean(n))/n, .by = kmeans_cluster) %>%
  slice_max(order_by = tf_idf, n = 5, by = kmeans_cluster)
