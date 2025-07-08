import os
import glob
import pandas as pd
import numpy as np
import pyarrow.feather as feather
import paths
from tqdm import tqdm

from sklearn.metrics.pairwise import cosine_similarity


# --------------------------- LOAD DATA  --------------------------- #

JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
EMBEDDINGS_FOLDER = os.path.join(JSTOR_RAW_DATA_PATH, "sentences_embeddings")
REF_VECTORS_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "representative_embeddings_by_decade.feather")

# Where your feather files are stored
pattern = os.path.join(EMBEDDINGS_FOLDER, "sentence_embeddings_*.feather")
all_files = glob.glob(pattern)

# --------------------------- COMPUTE AVERAGE VECTOR FOR EACH DOCUMENT --------------------------- #


df_average_vectors_by_id = []

for file in tqdm(all_files):
  
    df = feather.read_feather(file)
    
    # Ensure embedding is numpy array 
    df["embedding"] = df["embedding"].apply(np.array)
    
    # Compute average vector for each document
    df = df.groupby(["id", "publication_year"])["embedding"].apply(lambda x: np.mean(np.vstack(x), axis=0)).reset_index()
    df.rename(columns={"embedding": "average_embedding"}, inplace=True)
    
    df_average_vectors_by_id.append(df)


# concat and save dataframe 

df_average_vectors_by_id = pd.concat(df_average_vectors_by_id, ignore_index=True)

# temp saving
# df_average_vectors_by_id.to_feather(os.path.join(JSTOR_RAW_DATA_PATH, "average_embedding_by_document.feather"))



# --------------------------- COMPUTE PROXIMITY TO REPRESENTATIVE VECTORS --------------------------- #

# Load df average vectors
df_average_vectors_by_id = pd.read_feather(os.path.join(JSTOR_RAW_DATA_PATH, "average_embedding_by_document.feather"))

REP_EMBEDDINGS_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "representative_embeddings.feather")
df_rep = feather.read_feather(REP_EMBEDDINGS_FILE)

# create columns to join 
df_average_vectors_by_id["year"] = df_average_vectors_by_id["publication_year"]
df_average_vectors_by_id["decade"] = (df_average_vectors_by_id["publication_year"] // 10) * 10

# Merge embeddings by year
df_merged = df_average_vectors_by_id.merge(
    df_rep[["year", "embedding_by_year"]],
    on="year",
    how="left"
)

# Merge embeddings by decade
df_merged = df_merged.merge(
    df_rep[["decade", "embedding_by_decade"]].drop_duplicates("decade"),
    on="decade",
    how="left"
)

# Merge moving embeddings
df_merged = df_merged.merge(
    df_rep[["year", "embedding_by_year_centered"]],
    on="year",
    how="left"
)

# Calcul des similarités cosinus
similarities_by_year = []
similarities_by_decade = []
similarities_by_centered = []

for i, row in tqdm(df_merged.iterrows(), total=len(df_merged), desc="Calcul des similarités"):

    doc_vec = np.array(row["average_embedding"])

    year_vec = np.array(row["embedding_by_year"]) 
    decade_vec = np.array(row["embedding_by_decade"]) 
    centered_vec = np.array(row["embedding_by_year_centered"])

    # Sim to year
    if year_vec is not None:
        sim_y = cosine_similarity(doc_vec.reshape(1, -1), year_vec.reshape(1, -1))[0][0]
    else:
        sim_y = np.nan
    similarities_by_year.append(sim_y)

    # Sim to decade
    if decade_vec is not None:
        sim_d = cosine_similarity(doc_vec.reshape(1, -1), decade_vec.reshape(1, -1))[0][0]
    else:
        sim_d = np.nan
    similarities_by_decade.append(sim_d)

    # Sim to centered
    if centered_vec is not None:
        sim_c = cosine_similarity(doc_vec.reshape(1, -1), centered_vec.reshape(1, -1))[0][0]
    else:
        sim_c = np.nan
    similarities_by_centered.append(sim_c)


# Ajout des résultats
df_merged["cosine_sim_year"] = similarities_by_year
df_merged["cosine_sim_decade"] = similarities_by_decade
df_merged["cosine_sim_centered"] = similarities_by_centered


# Sauvegarde
output_file = os.path.join(JSTOR_RAW_DATA_PATH, "similarities_by_document.feather")
df_merged.to_feather(output_file)
