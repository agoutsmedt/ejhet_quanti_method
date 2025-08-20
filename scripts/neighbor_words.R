# paths and packages
source(file.path("scripts", "paths_and_packages.R"))

# load paragraphs 
paragraphs <- read_parquet(here::here(jstor_raw_data, "paragraphs_with_target_word.parquet"))

# tokenization

paragraphs <- as.data.table(paragraphs)
paragraphs <- paragraphs[, .(id, window, target_word)]

# group by id and create paragraph_id 
paragraphs[, paragraph_id := as.character(seq_len(.N)), by = id]
# add id to paragraph_id
paragraphs[, paragraph_id := paste0(id, "_", as.character(paragraph_id))]

# tokenize words in the window and unlist them
tokens <- paragraphs[, token := tokenizers::tokenize_words(window, strip_numeric = TRUE, lowercase = TRUE)]
tokens_unnest <- tokens[, .(token = unlist(token)), by = .(paragraph_id, id, target_word)]

# add position of each token in the paragraph
tokens_unnest[, pos := seq_len(.N), by = paragraph_id]

# identify the target word position
targets <- tokens_unnest[token == target_word]

# Previous positions
targets_prev <- copy(targets)
targets_prev[, pos := pos - 1]   # shift by -1
targets_prev[, side := "prev"]

# Next positions
targets_next <- copy(targets)
targets_next[, pos := pos + 1]   # shift by +1
targets_next[, side := "next"]

# Combine previous and next positions
targets_all <- rbind(targets_prev, targets_next)
# keep only necessary columns
targets_all <- targets_all[, .(paragraph_id, pos, side)]

# merge by paragraph_id and pos
tokens_unnest <- merge(tokens_unnest, targets_all, by = c("paragraph_id", "pos"), all.x = TRUE)

# filter non-NA side 
tokens_unnest <- tokens_unnest[!is.na(side)]

# estimate the total frequency of neighbor words by side 
neighbor_words_freq <- tokens_unnest[, .N, by = .(token, side, target_word)]

# filter stopwords
neighbor_words_freq <- neighbor_words_freq[!token %in% stopwords::stopwords("en")]

# save results in rds
saveRDS(neighbor_words_freq, file = here::here(data_path, "neighbor_target_words_freq.rds"))
