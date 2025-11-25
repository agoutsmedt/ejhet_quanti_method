# Load libraries and data ---------------------------

source(file.path("scripts", "paths_and_packages.R"))
# --------------------------------------------
# 1) Load the existing top-1% file and metadata
# --------------------------------------------
df <- read_feather(
  file.path(data_path, "top1pct_sentences_by_year.feather")
)


# keep only relevant lines, columns and rename them for consistency

metadata_jstor <- read_rds(file.path(
  jstor_raw_data,
  "jstor_constellate_merged_metadata.rds"
)) %>%
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
)) %>%
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


# --------------------------------------------
# 2) For each decade, find the sentence closest to the reference vector
# --------------------------------------------
df_top_specific <- df %>%
  # filter sentence that start with upper case and end with period
  filter(grepl("^[A-Z].*\\.$", sentence)) %>%
  # mutate(decade = (year %/% 10) * 10) %>%
  # group_by(decade) %>%
  filter(year %in% c(1925, 1950, 1975, 2000)) %>%
  group_by(year) %>%
  arrange(desc(similarity_rv)) %>%
  slice_head(n = 5) %>%
  ungroup()

# add metadata
df_top_specific <- df_top_specific %>%
  left_join(metadata %>% select(-year), by = "id") %>%
  select(
    id,
    title,
    authors,
    journal,
    year,
    sentence,
    similarity_rv
  )


# --------------------------------------------
# 3) Save the resulting table
# --------------------------------------------
write_feather(
  df_top_specific,
  file.path(data_path, "illustrative_table_closest_sentences_to_rv.feather")
)
