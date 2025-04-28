# ------------------------- load libraries --------------------------- #

source(file.path("scripts", "paths_and_packages.R"))

library(text)

# install an py env with textrpp_install()

# init python env

textrpp_initialize(save_profile = TRUE)

# ------------------------ load data --------------------------------- #

paragraphs <- readRDS(here::here(jstor_raw_data, "bert_vectors", "paragraphs_with_target_word.rds"))


# ------------------------------------- get embeddings ----------------------------------- #


for (year in seq(1953, 2020, by = 1)) {

  paragraphs_year <- paragraphs[publicationYear == year]
  
  text_with_embedding <- textEmbed(
    paragraphs_year$windows,
    model = "bert-base-uncased",
    layers = -2,
    # select target word
    aggregation_from_layers_to_tokens = "concatenate",
    aggregation_from_tokens_to_texts = NULL,
  )
  
  # add id and window paragraphs 
  
  text_with_embedding <- append(text_with_embedding, 
                                list(id = paragraphs_year$id, paragraph_id = paragraphs_year$paragraph_id))
  
  # save embeddings for the year
  
  saveRDS(text_with_embedding, here::here(jstor_raw_data, "bert_vectors", paste0("bert_embeddings_", year, ".rds")))
  
}



