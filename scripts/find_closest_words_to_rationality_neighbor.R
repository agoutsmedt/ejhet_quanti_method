# This script extracts the frequency of words that appear before or next to a target word in paragraphs.

# paths and packages
source(file.path("scripts", "paths_and_packages.R"))

# load paragraphs
raw_paragraphs <- read_parquet(here::here(
  jstor_raw_data,
  "paragraphs_with_target_word.parquet"
))

# tokenization

paragraphs <- as.data.table(raw_paragraphs)
paragraphs <- paragraphs[, .(id, window, target_word, publication_year)]

# group by id and create paragraph_id
paragraphs[, paragraph_id := as.character(seq_len(.N)), by = id]
# add id to paragraph_id
paragraphs[, paragraph_id := paste0(id, "_", as.character(paragraph_id))]

# tokenize words in the window and unlist them
tokens <- paragraphs[,
  token := tokenizers::tokenize_words(
    window,
    strip_numeric = TRUE,
    lowercase = TRUE
  )
]
tokens_unnest <- tokens[,
  .(token = unlist(token)),
  by = .(paragraph_id, id, publication_year, target_word)
]

# add position of each token in the paragraph
tokens_unnest[, pos := seq_len(.N), by = paragraph_id]

# identify the target word position
targets <- tokens_unnest[token == target_word]

# Previous positions
targets_prev <- copy(targets)
targets_prev[, pos := pos - 1] # shift by -1
targets_prev[, side := "prev"]

# Next positions
targets_next <- copy(targets)
targets_next[, pos := pos + 1] # shift by +1
targets_next[, side := "next"]

# Combine previous and next positions
targets_all <- rbind(targets_prev, targets_next)
# keep only necessary columns
targets_all <- targets_all[, .(paragraph_id, pos, side)]

# merge by paragraph_id and pos
tokens_unnest <- merge(
  tokens_unnest,
  targets_all,
  by = c("paragraph_id", "pos"),
  all.x = TRUE
)

# filter non-NA side
tokens_unnest <- tokens_unnest[!is.na(side)]

# filter out target words
tokens_unnest <- tokens_unnest[!token %in% stopwords::stopwords("en")]
tokens_unnest <- tokens_unnest[!str_detect(token, "^\\d+$")] # remove numeric tokens

# estimate token frequency by decade

# create a decade variable
tokens_unnest[, decade := floor(publication_year / 10) * 10]
tokens_unnest <- tokens_unnest[decade >= 1900]

freq <- tokens_unnest[, N := .N, by = .(decade, token, target_word)]
freq <- freq[, .(decade, token, target_word, N)]
freq <- unique(freq)

# keep 5 most frequent tokens by decade and target word

saveRDS(
  freq,
  here::here(data_path, "neighbor_words_to_rationality.rds")
)

# Plot the most frequent words by decade

# Définir les target words
targets <- list(
  rationality = "rationality",
  rational = "rational",
  both = c("rationality", "rational")
)

# Boucle
for (name in names(targets)) {
  p <- freq |>
    filter(target_word %in% targets[[name]]) |>
    group_by(decade) |>
    slice_max(N, n = 5, with_ties = FALSE) |>
    mutate(token = reorder_within(token, N, decade)) |>
    ggplot(aes(x = token, y = N)) +
    geom_col() +
    facet_wrap(~decade, scales = "free") +
    labs(
      x = "Words",
      y = "Frequency"
    ) +
    coord_flip() +
    scale_x_reordered() +
    theme_light(base_size = 30)

  # sauvegarde
  ggsave(
    here::here(image_path, paste0("top_neighbor_words_", name, ".png")),
    plot = p,
    width = 60,
    height = 60,
    units = "cm",
    dpi = 300
  )
}
