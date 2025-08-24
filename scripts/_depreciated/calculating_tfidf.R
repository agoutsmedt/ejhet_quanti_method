# Load libraries and data ---------------------------

source(file.path("scripts", "paths_and_packages.R"))

# Connect to the SQLite database and reference the "text" table
con <- dbConnect(SQLite(), file.path(jstor_raw_data, "jstor_journals.sqlite"))
text_db <- tbl(con, "text_cleaned")

# load relevant metadata
# metadata <- read_rds(file.path(data_path, "full_metadata_journals.rds")) %>% 
#   # Only keep research articles, other are messy 
#   .[docSubType == "research-article" & language == "eng", .(id, isPartOf, title, publicationYear)] %>% 
#   .[order(publicationYear)]

# Tokenizing text -----------------------
p_load(tokenizers)
texts <- text_db %>% 
  collect() %>% 
  as.data.table()
setorder(texts, id, page,)

texts[, doc_id := paste0(id, "_", page)]
texts[, tokens := tokenize_words(text, lowercase = TRUE, strip_punct = TRUE)]
texts <- texts[, .(doc_id, tokens)]

# Unnest tokens into a long format table
tokens_long <- texts[, .(term = unlist(tokens)), by = doc_id]
saveRDS(tokens_long, file = file.path(path.expand("~"), "data", "jstor", "tokens_jstor.rds"))

# Counting terms --------------------
# if necessary `tokens_long <- readRDS(file.path(path.expand("~"), "data", "jstor", "tokens_jstor.rds"))`

D <- uniqueN(tokens_long$doc_id) # Total number of documents
tokens_long[, general_tf := .N, by = term] # number of occurrence of a term
tokens_long[, nb_word_document := .N, by = doc_id] # number of tokens in a document
tokens_long[, tf := .N/nb_word_document, by = .(doc_id, term)] # weighted frequency of a term in a document
tokens_long <- unique(tokens_long)
tokens_long[, df := .N, by = term] # number of documents in which we find a term
tokens_long[general_tf > 10, tfidf := tf*log(D/df)]
saveRDS(tokens_long, file = file.path(path.expand("~"), "data", "jstor", "tokens_count_jstor.rds"))

