
# ---------------------- LIBRAIRIES ---------------------- #

source(file.path("scripts", "paths_and_packages.R"))

library(arrow)      # pour lire les fichiers Feather ou Parquet
library(dplyr)
library(ggplot2)
library(patchwork)  # pour afficher deux graphes côte à côte
library(stats)      # pour prcomp (PCA)



bert_df <- read_feather(here::here(jstor_raw_data, "embeddings_bert-base-uncased.feather"))
econ_df <- read_feather(here::here(jstor_raw_data, "embeddings_econbert.feather"))

# ---------------------- PCA ---------------------- #
# Convertir les embeddings en matrice
bert_mat <- do.call(rbind, bert_df$bert_embedding_concat)
econ_mat <- do.call(rbind, econ_df$bert_embedding_concat)

# Appliquer PCA
pca_bert <- prcomp(bert_mat, center = TRUE, scale. = FALSE)
pca_econ <- prcomp(econ_mat, center = TRUE, scale. = FALSE)

# Ajouter les composantes au DataFrame
bert_df$pca_1 <- pca_bert$x[, 1]
bert_df$pca_2 <- pca_bert$x[, 2]

econ_df$pca_1 <- pca_econ$x[, 1]
econ_df$pca_2 <- pca_econ$x[, 2]

# ---------------------- PLOTS ---------------------- #
plot_bert <- ggplot(bert_df, aes(x = pca_1, y = pca_2)) +
  geom_point(alpha = 0.3, size = 0.5, color = "blue") +
  theme_minimal() +
  labs(title = "BERT base", x = "PC1", y = "PC2")

plot_econ <- ggplot(econ_df, aes(x = pca_1, y = pca_2)) +
  geom_point(alpha = 0.3, size = 0.5, color = "darkgreen") +
  theme_minimal() +
  labs(title = "EconBERT", x = "PC1", y = "PC2")

# ---------------------- AFFICHER CÔTE À CÔTE ---------------------- #
plot_bert + plot_econ
