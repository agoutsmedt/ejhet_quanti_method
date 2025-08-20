# -------------------- Load libs --------------------

source(file.path("scripts", "paths_and_packages.R"))
library(furrr)
library(data.table)
library(stringr)
library(tokenizers)
library(tictoc)
library(progress)
library(here)

# -------------------- Load metadata --------------------
metadata <- read_rds(file.path(data_path, "full_metadata_journals_cleaned.rds")) %>% 
  # Only keep research articles for now because other types are quite messy and avoid overloading the memory
  .[ refined_sub_type == "research-article" & language == "eng", .(id, is_part_of, title, creator, publication_year)] %>% 
  .[order(publication_year)] %>% 
  # remove "http://www.jstor.org/stable/" from id 
  .[, id := str_remove_all(id, "http://www.jstor.org/stable/")]
  

# -------------------- Extraction function --------------------

extract_windows_df <- function(text, target_word, window_size = 128) {
  tokens <- unlist(tokenize_words(text, lowercase = TRUE))
  positions <- which(str_detect(tokens, target_word))
  if (length(positions) == 0) return(NULL)
  
  out <- lapply(positions, function(pos) {
    start <- max(1, pos - window_size %/% 2)
    end <- min(length(tokens), pos + window_size %/% 2)
    window_text <- paste(tokens[start:end], collapse = " ")
    data.frame(window = window_text, target_word = tokens[pos], stringsAsFactors = FALSE)
  })
  
  rbindlist(out)
}

# -------------------- Setup --------------------

con <- DBI::dbConnect(RSQLite::SQLite(), file.path(jstor_raw_data, "jstor_journals.sqlite"))
text_db <- tbl(con, "text_cleaned")

target_word <- "\\b(irrational|rational)\\w*\\b"
temp_data_path <- here(jstor_raw_data, "paragraphs")

years <- as.character(1886:2020)

# Parallélisme
plan(multisession, workers = parallel::detectCores() - 1)

pb <- progress_bar$new(
  format = "[:bar] :current/:total (:percent) | ETA: :eta",
  total = length(years), clear = FALSE, width = 80
)

# -------------------- Loop --------------------

for (year in years) {
  
  pb$tick(0)
  pb$message(year)
  tic(paste("Year", year))
  
  ids <- metadata[publication_year == year, id]
  
  df_text <- text_db %>%
    filter(type == "main_text",
           id %in% ids,
           # remove na in text
           !is.na(text)) %>%
    collect() %>%
    as.data.table()
  
  if (nrow(df_text) == 0) next
  
  df_text <- df_text[, .(text = paste(text, collapse = " ")), by = id]
  df_text <- df_text[stri_detect_regex(text, regex(target_word, ignore_case = TRUE))]
  
  if (nrow(df_text) == 0) next
  
  # Future_map version: extraction des paragraphes
  df_text[, extracted := future_map(text, extract_windows_df, target_word = target_word)]
  
  # Retirer les NULL
  df_text <- df_text[!sapply(extracted, is.null)]
  
  if (nrow(df_text) == 0) next
  
  # Aplatir
  df_flat <- df_text[, .(id, extracted)] %>%.[, rbindlist(extracted, idcol = FALSE), by = id]
  
  df_flat[, paragraph_id := seq_len(.N), by = id]
  df_flat <- merge(df_flat, metadata[, .(id, publication_year)], by = "id", all.x = TRUE)
  
  saveRDS(df_flat, file = file.path(temp_data_path, paste0("paragraphs_year_", year, ".rds")))
  
  rm(df_flat, df_text); gc()
  toc(log = TRUE)
  pb$tick()
  
}


# ------------------------ Merge All Years ------------------------ #

file_list <- list.files(temp_data_path, pattern = "^paragraphs_year_\\d+\\.rds$", full.names = TRUE)
paragraphs <- rbindlist(lapply(file_list, readRDS), use.names = TRUE, fill = TRUE)

# Filter only rational / irrational core forms
paragraphs <- paragraphs %>%
  filter(target_word %in% c("rational", "rationality"))

# Remove duplicates
paragraphs <- paragraphs %>%
  group_by(window) %>%
  slice(1) %>%
  ungroup()

# Save cleaned version
arrow::write_parquet(paragraphs, sink = file.path(jstor_raw_data, "paragraphs_with_target_word.parquet"))

# Plot distribution
ggplot(paragraphs, aes(x = publication_year)) +
  geom_histogram(binwidth = 1) +
  labs(title = "Distribution of Paragraphs with Target Word by Year",
       x = "Publication Year", y = "Count") +
  theme_minimal()
