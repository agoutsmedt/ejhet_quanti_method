source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(fs)

# this list of documents is used to filter the metadata df, to keep only the documents for which we have the full text and the embedding vector.
documents_vectorised <- read_feather(file.path(
  data_path,
  "metadata_maintext.feather"
))

# load row metadata from DuckDB

# JSTOR
con_jstor <- dbConnect(
  duckdb(),
  file.path(jstor_raw_data, "jstor.duckdb"),
  read_only = TRUE
)

metadata_jstor_clean <- tbl(con_jstor, "metadata") %>%
  filter(to_keep == TRUE) %>%
  select(
    url,
    is_part_of,
    title,
    creators_string,
    publication_year,
    refined_sub_type,
    doi,
    id_wos_matched,
    languages,
    full_text
  ) %>%
  collect() %>%
  rename(
    year = publication_year,
    id = url,
    journal = is_part_of,
    authors = creators_string,
    type = refined_sub_type
  )
dbDisconnect(con_jstor)

# Scopus + istex
con_scopus <- dbConnect(
  duckdb(),
  file.path(elsevier_data, "scopus.duckdb"),
  read_only = TRUE
)

metadata_scopus_clean <- tbl(con_scopus, "articles") %>%
  select(
    scopus_id,
    dc_title,
    dc_creator,
    prism_publication_name,
    prism_cover_date,
    subtype_description,
    elsevier_full_text,
    id_wos_matched,
    prism_doi
  ) %>%
  collect() %>%
  rename(
    id = scopus_id,
    title = dc_title,
    authors = dc_creator,
    journal = prism_publication_name,
    year = prism_cover_date,
    type = subtype_description,
    full_text = elsevier_full_text,
    doi = prism_doi
  ) %>%
  mutate(
    year = as.integer(str_sub(year, 1, 4)),
    languages = "eng"
  )
dbDisconnect(con_scopus)

# load id from fulltexts_embeddings folders
# ISTEX <- dir_ls(
#   file.path(embeddings_data, "istex_vectors"),
#   recurse = TRUE,
#   glob = "*.feather"
# )
# JSTOR <- dir_ls(
#   file.path(embeddings_data, "jstor_vectors"),
#   recurse = TRUE,
#   glob = "*.feather"
# )
# ELSEVIER <- dir_ls(
#   file.path(embeddings_data, "elsevier_vectors"),
#   recurse = TRUE,
#   glob = "*.feather"
# )

# FILES <- c(ISTEX, JSTOR, ELSEVIER)

# # extraction légère des IDs
# ids_in_embeddings_folders <- lapply(FILES, function(f) {
#   # détecter la source à partir du chemin
#   source <- case_when(
#     grepl("istex_vectors", f) ~ "ISTEX",
#     grepl("jstor_vectors", f) ~ "JSTOR",
#     grepl("elsevier_vectors", f) ~ "ELSEVIER",
#     TRUE ~ "UNKNOWN"
#   )

#   read_feather(f, col_select = c("id")) %>%
#     mutate(source = source)
# })

metadata_all_texts <- bind_rows(
  metadata_jstor_clean,
  metadata_scopus_clean
) %>%
  filter(year %in% c(1900:2009))

metadata_maintext <- metadata_all_texts %>%
  filter(
    id %in% documents_vectorised$id
  )


# save 2 databases in feather

write_feather(
  metadata_all_texts,
  file.path(
    data_path,
    "metadata_all_texts.feather"
  )
)

write_feather(
  metadata_maintext,
  file.path(
    data_path,
    "metadata_maintext.feather"
  )
)
