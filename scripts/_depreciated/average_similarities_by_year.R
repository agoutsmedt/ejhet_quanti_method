# This script calculates the average cosine similarity between representative vectors and sentence embeddings for each sentence in JSTOR fulltext. 
# We keep only the average similarity and standard deviation for each year.

# paths and packages
source(file.path("scripts", "paths_and_packages.R"))

# Load sentences embeddings
embeddings_folder <- here::here(data_path, "sentences_embeddings")
embeddings_files <- list.files(embeddings_folder, full.names = TRUE)

# load representive vectors
rv <- read_feather(file.path(data_path, "representative_vectors.feather")) 

# estimate average similarities by year between representative vectors and sentences embeddings 

results <- list()

for (i in seq_along(embeddings_files)) {

  file <- embeddings_files[i]
  year <- str_extract(file, "\\d{4}")

  # load sentences embeddings for the specific year
  sentences_embeddings <- read_feather(file)

  rv_for_year <- rv |> filter(year == year)

  # if no representative vector for this year
  if (rv_for_year |> nrow() == 0) {
    next
  }

  x <- matrix(unlist(rv_for_year$embedding_by_year_centered[[1]]),
              nrow = 1, byrow = TRUE)
  
  y <- do.call(rbind, sentences_embeddings$embedding)  

  # Calculate cosine similarities
  sims <- text2vec::sim2(x, y, method = "cosine", norm = "l2")
  sims <- as.numeric(sims)  # 1 x N -> vecteur
  
  # Store results
  results[[i]] <- tibble(
    year = year,
    average_similarity = mean(sims, na.rm = TRUE),
    std_similarity = sd(sims, na.rm = TRUE),
    n = length(sims)
  )
}

# temp save results
average_similarities_by_year <- bind_rows(results)
saveRDS(average_similarities_by_year, file = file.path(data_path, "average_similarities_by_year_between_all_sentences_and_rv.rds"))

# plot results
average_similarities_by_year <- readRDS(file = file.path(data_path, "average_similarities_by_year_between_all_sentences_and_rv.rds"))

average_similarities_by_year |> 
  ggplot(aes(x = as.integer(year), y = average_similarity)) +
  geom_line(color = "#260C3F") +
  # add sd 
  geom_line(aes(y = average_similarity + std_similarity), linetype = "dashed", color = "#260C3F") +
  geom_line(aes(y = average_similarity - std_similarity), linetype = "dashed", color = "#260C3F") +
  labs(title = "Average and standard deviation of similarity to representative vectors",
       x = "Year",
       y = "Similarity") +
  theme_light()
# save plot 
ggsave(file.path(image_path, "average_similarities_by_year.png"), width = 10, height = 6)



