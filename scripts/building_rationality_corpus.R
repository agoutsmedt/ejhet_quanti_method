############ Build the rationality Corpus #########################

# # Loading Libraries and data
source(file.path("scripts", "paths_and_packages.R"))
p_load(lsa,
       furrr)

# Plan for parallel execution — adjust as needed
plan(multisession, workers = 10)

# Connect to the SQLite database and reference the "text" table
con <- dbConnect(SQLite(), file.path(jstor_raw_data, "jstor_journals.sqlite"))
doc_embeddings <- tbl(con, "doc_embeddings") %>% 
  collect() %>% 
  as.data.table()

# load the embeddings
glove <- read_rds(file.path(data_path, glue("glove_model_jstor.rds")))
wv_main <- read_rds(file.path(data_path, glue("word_vectors_300d.rds")))

wv_context <- glove$components
word_vectors <- wv_main + t(wv_context)

# Calculating similarity with rationality----------------
rational_vector <- map2_dbl(word_vectors["rationality",], word_vectors["rational",], ~mean(c(.x, .y)))

# Calculating the similarity for each page
similarity_scores <- map_dbl(seq_len(nrow(doc_embeddings)),
                             ~cosine(rational_vector, doc_embeddings[., -"doc_id"] %>% as.vector(mode = "double")))
similarity_scores <- data.table(doc_id = doc_embeddings$doc_id,
                                similarity = similarity_scores)

# Adding the mean per article
similarity_scores[, jstor_id := str_remove(doc_id, "_\\d{1,3}$")]
similarity_scores[, mean_similarity := mean(similarity), by = jstor_id]

saveRDS(similarity_scores, file = file.path(path.expand("~"), "data", "rationality_similarity_scores.rds"))
          
