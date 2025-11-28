source(file.path("scripts", "paths_and_packages.R"))

pacman::p_load(fs)

# load metadata
metadata <- read_feather(file.path(data_path, "metadata_maintext.feather")) %>%
  distinct(id, year)

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
ids_in_embeddings_folders <- lapply(FILES, function(f) {
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

ids_in_embeddings_folders <- bind_rows(ids_in_embeddings_folders) %>%
  distinct(id, year, source)

# load fulltexts_cosine_sim_with_rv.feather
fulltexts_cosine_sim <- read_feather(
  file.path(data_path, "fulltexts_cosine_sim_with_rv.feather")
) %>%
  distinct(id, year)


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

n_sentences_per_id <- ids_not_deleted %>%
  group_by(id) %>%
  summarise(n_sentences = n())

# save
write_feather(
  n_sentences_per_id,
  file.path(data_path, "n_sentences_per_id_after_cleaning.feather")
)

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
