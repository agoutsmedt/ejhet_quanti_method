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
