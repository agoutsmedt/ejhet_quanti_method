source(file.path("scripts", "paths_and_packages.R"))

pacman::p_load(fs)

# load metadata

# load metadata
metadata_jstor <- read_rds(file.path(
  jstor_raw_data,
  "jstor_constellate_merged_metadata.rds"
))

# keep only relevant lines, columns and rename them for consistency
metadata_jstor <- metadata_jstor %>%
  filter(refined_sub_type == "research-article" & languages == "eng") %>%
  select(url, is_part_of, title, creators_string, publication_year) %>%
  rename(
    year = publication_year,
    id = url,
    journal = is_part_of,
    authors = creators_string
  ) %>%
  arrange(year)

# same for scopus metadata
metadata_scopus <- read_rds(file.path(
  elsevier_data,
  "scopus_economics_articles.rds"
))

metadata_scopus <- metadata_scopus %>%
  filter(full_text == TRUE & subtype_description == "Article") %>%
  select(
    scopus_id,
    dc_title,
    dc_creator,
    prism_publication_name,
    prism_cover_date
  ) %>%
  rename(
    id = scopus_id,
    title = dc_title,
    authors = dc_creator,
    journal = prism_publication_name,
    year = prism_cover_date
  ) %>%
  mutate(year = as.integer(str_sub(year, 1, 4)))

metadata <- bind_rows(metadata_jstor, metadata_scopus)

rm(metadata_jstor, metadata_scopus)


# fichiers
ISTEX <- dir_ls(
  file.path(embeddings_data, "istex_vectors"),
  recurse = TRUE,
  glob = "*.feather"
)
JSTOR <- dir_ls(
  file.path(embeddings_data, "jstor_vectors"),
  recurse = TRUE,
  glob = "*.feather"
)
ELSEVIER <- dir_ls(
  file.path(embeddings_data, "elsevier_vectors"),
  recurse = TRUE,
  glob = "*.feather"
)

FILES <- c(ISTEX, JSTOR, ELSEVIER)

# extraction légère des IDs
ids <- lapply(FILES, function(f) {
  # détecter la source à partir du chemin
  source <- case_when(
    grepl("istex_vectors", f) ~ "ISTEX",
    grepl("jstor_vectors", f) ~ "JSTOR",
    grepl("elsevier_vectors", f) ~ "ELSEVIER",
    TRUE ~ "UNKNOWN"
  )

  read_feather(f, col_select = c("id", "sentence_id")) %>%
    mutate(source = source)
})

df_ids <- bind_rows(ids)

# keep only year of interest

df_ids <- df_ids %>%
  left_join(metadata %>% select(id, year), by = "id") %>%
  filter(year %in% c(1900:2009)) %>%
  select(-year)

# store distinct id source mapping
id_source <- df_ids %>% distinct(id, source)


# load sentences_to_delete.feather

ids_deleted <- read_feather(
  file.path(
    data_path,
    "sentences_to_delete.feather"
  ),
  col_select = c("id", "sentence_id")
) %>%
  left_join(
    metadata %>% select(id, year),
    by = "id"
  ) %>%
  filter(year %in% c(1900:2009)) %>%
  select(-year) %>%
  # add source
  left_join(id_source, by = "id")

ids_not_deleted <- df_ids %>%
  anti_join(ids_deleted, by = c("id", "sentence_id"))


# load # top1pct_sentences_by_year.feather
top1pct <- read_feather(
  file.path(
    data_path,
    "top1pct_sentences_by_year.feather"
  ),
  col_select = c("id", "sentence_id")
) %>%
  left_join(
    metadata %>% select(id, year),
    by = "id"
  ) %>%
  filter(year %in% c(1900:2009)) %>%
  select(-year) %>%
  # add source
  left_join(id_source, by = "id")


nrow(df_ids)
nrow(ids_not_deleted)
nrow(ids_deleted)
nrow(top1pct)


total_sentence_distribution <- df_ids %>%
  count(source) %>%
  mutate("%" = n / sum(n) * 100) %>%
  rename("Total Sentences" = n)

cleaned_sentence_distribution <- ids_not_deleted %>%
  count(source) %>%
  mutate("%" = n / sum(n) * 100) %>%
  rename("Cleaned Sentences" = n)

deleted_sentence_distribution <- ids_deleted %>%
  count(source) %>%
  mutate("%" = n / sum(n) * 100) %>%
  rename("Deleted Sentences" = n)

top1pct_sentence_distribution <- top1pct %>%
  count(source) %>%
  mutate("%" = n / sum(n) * 100) %>%
  rename("Top 1% Sentences" = n)

message("Evaluation des distributions terminée.")
message("Distribution ensemble des phrases par sources :")
print(total_sentence_distribution)
message("Distribution des phrases conservées par sources :")
print(cleaned_sentence_distribution)
message("Distribution des phrases supprimées après nettoyage :")
print(deleted_sentence_distribution)
message("Distribution des phrases du top 1% par sources :")
print(top1pct_sentence_distribution)
