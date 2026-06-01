# Load libraries and data ---------------------------

source(file.path("scripts", "paths_and_packages.R"))
# --------------------------------------------
# 1) Load the existing top-1% file and metadata
# --------------------------------------------
sentences <- read_feather(file.path(
  data_path,
  "top1pct_sentences_by_year.feather"
))

documents <- read_feather(file.path(
  data_path,
  "fulltexts_cosine_sim_with_rv.feather"
))

# load metadata

metadata <- read_feather(file.path(
  data_path,
  "metadata_maintext.feather"
))


# --------------------------------------------
# 2) For each decade, find the sentence closest to the reference vector
# --------------------------------------------
df_top_specific <- sentences %>%
  # filter sentence that start with upper case and end with period
  filter(grepl("^[A-Z].*\\.$", sentence)) %>%
  # mutate(decade = (year %/% 10) * 10) %>%
  # group_by(decade) %>%
  group_by(year) %>%
  slice_max(similarity_rv, n = 5) %>%
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


# save
write_feather(
  df_top_specific,
  file.path(data_path, "illustrative_table_closest_sentences_to_rv.feather")
)


# --------------------------------------------
# 2) For each decade, find the document closest to the reference vector
# --------------------------------------------

df_top_docs <- documents %>%
  group_by(year) %>%
  slice_max(cosine_doc_with_rv, n = 5) %>%
  ungroup()

# add metadata
df_top_docs <- df_top_docs %>%
  left_join(metadata %>% select(-year), by = "id") %>%
  select(
    id,
    title,
    authors,
    journal,
    year,
    cosine_doc_with_rv
  )

# save
write_feather(
  df_top_docs,
  file.path(data_path, "illustrative_table_closest_documents_to_rv.feather")
)
