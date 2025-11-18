import os
import random
import numpy as np
import pandas as pd
from tqdm import tqdm
from sklearn.metrics.pairwise import cosine_similarity


from plotnine import ggplot, aes, geom_histogram, facet_wrap, theme_minimal, labs



# ======================================================
# PARAMÈTRES
# ======================================================

import paths 

EJHET_PATH = paths.ejhet_project_data_path  # dossier avec les fichiers feather de phrases + embeddings
CATS = ["author", "affiliation", "ack", "header", "reference"]
SAMPLE_PER_FILE = 5000

VECTORS_PATHS = paths.econ_embeddings_data_path
FOLDER = os.path.join(VECTORS_PATHS, "istex_vectors")  # dossier avec les fichiers feather de phrases + embeddings

# ======================================================
# 1. CHARGER LES CENTROÏDES
# ======================================================

# load centroids 
centroid_path = os.path.join(EJHET_PATH, "noisy_centroids.parquet")
noisy_centroids = pd.read_parquet(centroid_path)


# ======================================================
# 2. SAMPLING GLOBAL (phrases + embeddings)
# ======================================================

files = [f for f in os.listdir(FOLDER) if f.endswith(".feather")]

sample_embeddings = []
sample_sentences = []

for fname in tqdm(files, desc="Sampling sentences"):
    path = os.path.join(FOLDER, fname)

    df = pd.read_feather(path)

    # either take all or sample
    n = len(df)
    k = min(SAMPLE_PER_FILE, n)
    idx = random.sample(range(n), k)

    # retrieve embeddings and sentences
    embs = np.vstack(df["embedding"].iloc[idx].values)
    sents = df["sentence"].iloc[idx].tolist()

    sample_embeddings.append(embs)
    sample_sentences.extend(sents)

# concat
sample_embeddings = np.vstack(sample_embeddings)


# ======================================================
# 3. CONSTRUIRE LA MATRICE DES CENTROÏDES + SIMILARITÉS
# ======================================================

# réordonne par CATS
noisy_centroids = noisy_centroids.set_index("cat").loc[CATS]

# extrait la matrice (shape: n_cats × emb_dim)
centroid_matrix = noisy_centroids.filter(regex=r"^dim_").values

# calcule similarité cosinus (shape: n_samples × n_cats)
sims = cosine_similarity(sample_embeddings, centroid_matrix)

# DataFrame tidy wide format
dist_cat = pd.DataFrame(sims, columns=CATS)
dist_cat["sentence"] = sample_sentences

# tidy long format
dist_long = dist_cat.melt(
    id_vars="sentence", value_vars=CATS, var_name="category", value_name="similarity"
)

# ======================================================
# 4. PLOT PAR CATÉGORIE AVEC PLOTNINE
# ======================================================

p = (
    ggplot(dist_long, aes("similarity"))
    + geom_histogram(bins=50, fill="grey", color="black")
    + facet_wrap("~ category", scales="free_y")
    + theme_minimal()
    + labs(
        title="Distribution des similarités par centroïde de bruit",
        x="Similarité cosinus",
        y="Nombre de phrases",
    )
)

