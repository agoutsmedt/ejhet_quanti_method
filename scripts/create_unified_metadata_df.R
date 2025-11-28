source(file.path("scripts", "paths_and_packages.R"))

pacman::p_load(fs)

# load metadata

# load metadata
metadata_jstor <- read_rds(file.path(
  jstor_raw_data,
  "jstor_constellate_merged_metadata.rds"
)) %>%
  filter(to_keep == TRUE)

# keep only relevant lines, columns and rename them for consistency
metadata_jstor_clean <- metadata_jstor %>%
  select(
    url,
    is_part_of,
    title,
    creators_string,
    publication_year,
    refined_sub_type,
    doi,
    id_wos_matched,
    languages
  ) %>%
  rename(
    year = publication_year,
    id = url,
    journal = is_part_of,
    authors = creators_string,
    type = refined_sub_type
  ) %>%
  mutate(full_text = TRUE)

# same for scopus metadata
metadata_scopus <- read_rds(file.path(
  elsevier_data,
  "scopus_economics_articles.rds"
))

metadata_scopus_clean <- metadata_scopus %>%
  select(
    scopus_id,
    dc_title,
    dc_creator,
    prism_publication_name,
    prism_cover_date,
    subtype_description,
    full_text,
    id_wos_matched,
    prism_doi
  ) %>%
  rename(
    id = scopus_id,
    title = dc_title,
    authors = dc_creator,
    journal = prism_publication_name,
    year = prism_cover_date,
    type = subtype_description,
    doi = prism_doi
  ) %>%
  mutate(year = as.integer(str_sub(year, 1, 4))) %>%
  mutate(languages = "eng") # all articles in scopus metadata are in english

metadata_all_texts <- bind_rows(
  metadata_jstor_clean,
  metadata_scopus_clean
) %>%
  filter(year %in% c(1900:2009))

metadata_maintext <- metadata_all_texts %>%
  filter(
    full_text == TRUE &
      type %in% c("Article", "research-article"),
    languages == "eng"
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


# retrieve id in embedding but not in metadata_maintext

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


# retrieve id in embedding but not in metadata_maintext

ids_in_embeddings_folders <- bind_rows(ids_in_embeddings_folders) %>%
  distinct(id, source)

ids_that_should_not_be_vectorized <- ids_in_embeddings_folders %>%
  anti_join(metadata_maintext, by = "id") %>%
  left_join(metadata_all_texts, by = "id") %>%
  unique

# for jstor, text is none, for scopus it is mainly not cleaned text from istex that are not include in vectorization
ids_that_should_be_vectorized_but_are_not <- metadata_maintext %>%
  anti_join(ids_in_embeddings_folders, by = "id")
