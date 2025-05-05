# ------------------------- load libraries --------------------------- #

source(file.path("scripts", "paths_and_packages.R"))

# ------------------------ load data --------------------------------- #

# Connect to the SQLite database and reference the "text" table
con <- dbConnect(SQLite(), file.path(jstor_raw_data, "jstor_journals.sqlite"))
text_db <- tbl(con, "text_cleaned")

# load relevant metadata
metadata <- read_rds(file.path(data_path, "full_metadata_journals.rds")) %>% 
  # Only keep research articles, other are messy 
  .[docSubType == "research-article" & language == "eng", .(id, isPartOf, title, publicationYear)] %>% 
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

temp_data_path <- here::here(jstor_raw_data, "paragraphs")

# test

for (year in seq(2016, 2020, by = 1)) {
  
  cli::cli_alert_info("Processing year {year}")

    # get the text for the year
  ids <- metadata[publicationYear == year]$id
  
  df_text <- text_db %>%
    filter(id %in% ids) %>%
    collect() %>%
    as.data.table()
  
  # delete pages for target word close to start/end pages 
  df_text <- df_text %>% 
    group_by(id) %>%
    summarise(text = paste(text, collapse = " "), .groups = "drop") %>% 
    as.data.table()
  
  # df_text[, text := paste(text, collapse = " "), by = .(id)] # create a fatal error 
  # df_text <- unique(df_text)
  
  # detect target word 
  df_text <- df_text[stri_detect_regex(text, regex(target_word, ignore_case = TRUE))]
  
  # extract windows
  df_text[, windows := map(text, extract_window, target_word = target_word)]
  df_text[, text := NULL]
  df_text <- df_text[!is.na(windows)]
  df_text <- df_text[, .(windows = unlist(windows, recursive = FALSE)), by = id]
  df_text[, `:=`(
    windows = sapply(windows, `[[`, "window"),
    target_word = sapply(windows, `[[`, "target")
  )]
  
  # add an id and the year 
  df_text[, paragraph_id := seq_len(.N), by = id]
  df_text <- merge(df_text, metadata[, .(id, publicationYear)], by = "id", all.x = TRUE)
  
  # Save immediately
  saveRDS(df_text, file = here::here(temp_data_path, paste0("paragraphs_year_", year, ".rds")))
  
  rm(df_text)  # remove to free memory
  gc()         # force garbage collection
}

# then after the loop load and bind 
file_list <- list.files(here::here(temp_data_path), pattern = "^paragraphs_year_\\d+\\.rds$", full.names = TRUE)
paragraphs <- rbindlist(lapply(file_list, readRDS), use.names = TRUE, fill = TRUE)

# ----------------------------- clean paragraphs  -------------------------------- #

# keep only rational and rationality 

paragraphs <- paragraphs %>% 
  filter(target_word %in% c("rational", "rationality")) 

# remove duplicate paragraphs, if the same, keep only the first row

paragraphs <- paragraphs %>% 
  group_by(windows) %>% 
  slice(1) %>% 
  ungroup()

# Save full
saveRDS(paragraphs, file = here::here(jstor_raw_data, "paragraphs_with_target_word.rds"))

# plot distribution
ggplot(paragraphs, aes(x = publicationYear)) +
  geom_histogram(binwidth = 1) +
  labs(title = "Distribution of Paragraphs with Target Word by Year",
       x = "Publication Year",
       y = "Count") +
  theme_minimal()

