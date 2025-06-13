############### Script to calculate embeddings per documents ######################

# Loading Libraries and data
source(file.path("scripts", "paths_and_packages.R"))
tokens <- readRDS(file.path(path.expand("~"), "data", "jstor", "tokens_count_jstor.rds"))
tokens <- tokens[!is.na(tfidf), .(doc_id, term, tfidf)]

# Connect to the SQLite database and reference the "text" table
con <- dbConnect(SQLite(), file.path(jstor_raw_data, "jstor_journals.sqlite"))

# Create an empty table for doc embeddings
dims <- paste0("V", 1:300)
empty_doc_embeds <- data.table(doc_id = character())
empty_doc_embeds[, (dims) := lapply(seq_along(dims), function(i) numeric())]

dbWriteTable(con, "doc_embeddings", empty_doc_embeds, overwrite = TRUE)

# load the embeddings
glove <- read_rds(file.path(data_path, glue("glove_model_jstor.rds")))
wv_main <- read_rds(file.path(data_path, glue("word_vectors_300d.rds")))

wv_context <- glove$components
word_vectors <- wv_main + t(wv_context)

# Convert to data.table
word_vectors_dt <- as.data.table(word_vectors)
word_vectors_dt[, term := rownames(word_vectors)]

# Prepare for merging
setkey(tokens, doc_id, term)
setkey(word_vectors_dt, term)
rm(glove,
   wv_main,
   wv_context,
   word_vectors)
gc()

# Merging and Calculating doc embeddings----------

# --- Define batching ---
batch_size <- 10000
unique_docs <- unique(tokens$doc_id)
n_batches <- ceiling(length(unique_docs) / batch_size)

p_load(progress)
pb <- progress_bar$new(total = n_batches, format = "[:bar] :percent ETA: :eta")

for (i in seq(1, length(unique_docs), by = batch_size)) {
  pb$tick()
  
  # Step 1: Get doc_ids in this batch
  doc_batch <- unique_docs[i:min(i + batch_size - 1, length(unique_docs))]
  
  # Step 2: Subset tokens by doc_ids
  tokens_batch <- tokens[doc_id %in% doc_batch]
  if (nrow(tokens_batch) == 0) next
  
  # Step 3: Join with word vectors
  merged <- merge(tokens_batch, word_vectors_dt, by = "term", all = FALSE, allow.cartesian = TRUE)
  
  # Step 4: Multiply TF-IDF with each dimension
  for (d in seq_len(300)) {
    dim_col <- paste0("V", d)
    merged[, (dim_col) := get(dim_col) * tfidf]
  }
  
  # Step 5: Average per doc_id
  doc_embed <- merged[, lapply(.SD, mean, na.rm = TRUE), by = doc_id, .SDcols = dims]
  setorder(doc_embed, doc_id)
  
  # Step 6: Save to SQLite
  dbWriteTable(con, "doc_embeddings", doc_embed, append = TRUE)
  
  # Cleanup
  rm(tokens_batch, merged, doc_embed)
  gc()
}

