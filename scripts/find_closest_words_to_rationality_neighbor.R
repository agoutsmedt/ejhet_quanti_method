# This script extracts the frequency of words that appear before or next to a target word in paragraphs.

# paths and packages
source(file.path("scripts", "paths_and_packages.R"))

# load paragraphs 
raw_paragraphs <- read_parquet(here::here(jstor_raw_data, "paragraphs_with_target_word.parquet"))

# tokenization

paragraphs <- as.data.table(raw_paragraphs)
paragraphs <- paragraphs[, .(id, window, target_word, publication_year)]

# group by id and create paragraph_id 
paragraphs[, paragraph_id := as.character(seq_len(.N)), by = id]
# add id to paragraph_id
paragraphs[, paragraph_id := paste0(id, "_", as.character(paragraph_id))]

# tokenize words in the window and unlist them
tokens <- paragraphs[, token := tokenizers::tokenize_words(window, strip_numeric = TRUE, lowercase = TRUE)]
tokens_unnest <- tokens[, .(token = unlist(token)), by = .(paragraph_id, id, publication_year, target_word)]

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


# Now plot each most frequent words by decade


# first delete stopwords and target words 

tokens_unnest <- tokens_unnest[!token %in% stopwords::stopwords("en")]
tokens_unnest <- tokens_unnest[!str_detect(token, "^\\d+$")]  # remove numeric tokens

# Plot the most frequent words by decade

# Définir les target words
targets <- list(
  rationality = "rationality",
  rational    = "rational",
  both        = c("rationality", "rational")
)

# Boucle
for (name in names(targets)) {
  
  p <- tokens_unnest |> 
    filter(target_word %in% targets[[name]]) |>
    mutate(decade = floor(publication_year / 10) * 10) |>
    count(token, decade) |>
    filter(decade >= 1900) |> 
    group_by(decade) |> 
    slice_max(n, n = 10, with_ties = FALSE) |> 
    mutate(token = reorder_within(token, n, decade)) |>
    ggplot(aes(x = token, y = n)) +
    geom_col(fill = "#2C77B8") +
    facet_wrap(~ decade, scales = "free") +
    labs(
      title = paste("Most Frequent neighbor words by decade -", name),
      x = "Words",
      y = "Frequency"
    ) +
    coord_flip() +
    scale_x_reordered() +
    theme_light() 
  
  # sauvegarde
  ggsave(
    here::here(image_path_temp, paste0("Top_neighbor_words_", name, ".png")),
    plot = p,
    width = 60, height = 40, units = "cm", dpi = 300
  )
}
