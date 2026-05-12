source(file.path("scripts", "paths_and_packages.R"))

# load metadata from DuckDB

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

# Scopus
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
