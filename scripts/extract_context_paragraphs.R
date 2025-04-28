# ------------------------- load libraries --------------------------- #

source(file.path("scripts", "paths_and_packages.R"))

# ------------------------ load data --------------------------------- #

# Connect to the SQLite database and reference the "text" table
con <- dbConnect(SQLite(), file.path(jstor_raw_data, "jstor_journals.sqlite"))
text_db <- tbl(con, "text")

# load relevant metadata
metadata <- read_rds(file.path(data_path, "full_metadata_journals.rds")) %>% 
  .[docSubType == "research-article" & language == "eng", .(id, isPartOf, title, publicationYear)] %>% # Only keep research articles for now because other types are quite messy and avoid overloading the memory
  .[order(publicationYear)]


# ------------------------ extract vectors ------------------------ #

# Function use in loop to extract 128-token window around target_word

extract_window <- function(text, target_word, window_size = 128) {
  
  tokens <- unlist(tokenizers::tokenize_words(text, lowercase = TRUE))
  positions <- which(str_detect(tokens, target_word))
  
  if (length(positions) == 0) return(NULL) 
  
  windows <- lapply(positions, function(pos) {
    start <- max(1, pos - window_size %/% 2)
    end <- min(length(tokens), pos + window_size %/% 2)
    list(
      window = paste(tokens[start:end], collapse = " "),
      target = tokens[pos]
    )
  })
  
  return(windows)
}

# ----------------------------- get paragraphs with target words -------------------------------- #

target_word <- "\\b(irrational|rational)\\w*\\b"
paragraphs_list <- list()

# test

for (year in seq(1900, 2020, by = 1)) {
  
  cli::cli_alert_info("Processing year {year}")
  
  # get the text for the year
  
  ids <- metadata[publicationYear == year]$id
  
  # get the text for the selected ids
  df_text <- text_db %>%
    filter(id %in% ids) %>%
    collect() %>%
    as.data.table()
  
  # group text by id 
  df_text[, text := paste(text, collapse = " "), by = .(id)]
  # remove pages
  df_text[, page := NULL]
  # unique
  df_text <- unique(df_text)
  
  # filter texts using the  target world
  df_text <- df_text[stri_detect_regex(text, regex(target_word, ignore_case = TRUE))]
  
  # Apply the function
  df_text[, windows := map(text, extract_window, target_word = target_word)]
  
  # remove text column
  df_text[, text := NULL]
  
  # remove empty windows
  df_text <- df_text[!is.na(windows)] # remove na

  # unlist window paragraphs
  df_text <- df_text[, .(windows = unlist(windows, recursive = FALSE)), by = id]
  
  # Extract window text and target word into separate columns
  df_text[, `:=`(
    paragraph_text = sapply(windows, `[[`, "window"),
    target_word = sapply(windows, `[[`, "target")
  )]
  
  
  # add a paragraph id by id 
  df_text[, paragraph_id := seq_len(.N), by = id]
  
  # append to paragraphs
  paragraphs_list[[as.character(year)]] <- df_text
  
  # remove text to save memory
  rm(df_text) 
}

# create a data.table 

paragraphs <- rbindlist(paragraphs_list, use.names = TRUE, fill = TRUE)

# add year from metadata table to paragraphs by id 

paragraphs <- merge(paragraphs, metadata[, .(id, publicationYear)], by = "id", all.x = TRUE)

# plot distribution
ggplot(paragraphs, aes(x = publicationYear)) +
  geom_histogram(binwidth = 1) +
  labs(title = "Distribution of Paragraphs with Target Word by Year",
       x = "Publication Year",
       y = "Count") +
  theme_minimal()

# remove windows and save 
paragraphs[, windows := NULL]

saveRDS(paragraphs, here::here(jstor_raw_data, "bert_vectors", "paragraphs_with_target_word.rds"))
