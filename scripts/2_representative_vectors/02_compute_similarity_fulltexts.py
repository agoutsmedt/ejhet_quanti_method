# This script computes the cosine similarity between the average sentence embedding of a JSTOR fulltext and representative vectors.

import os
import re
import glob
import pandas as pd
import numpy as np
import pyarrow.feather as feather
import scripts.paths as paths

from tqdm import tqdm
from sklearn.metrics.pairwise import cosine_similarity

import gc 

# --------------------------- LOAD DATA  --------------------------- #

# load sentence embeddings of fulltexts
EJHET_DATA_PATH = paths.ejhet_project_data_path
VECTORS_PATH = paths.econ_embeddings_data_path
ISTEX = glob.glob(os.path.join(VECTORS_PATH, "istex_vectors", "**", "*.feather"), recursive=True)
JSTOR = glob.glob(os.path.join(VECTORS_PATH, "jstor_vectors", "**", "*.feather"), recursive=True)
ELSEVIER = glob.glob(os.path.join(VECTORS_PATH, "elsevier_vectors", "**", "*.feather"), recursive=True)

files = ISTEX + JSTOR + ELSEVIER

# load representative vectors
RV_FILE = os.path.join(paths.ejhet_project_data_path, "rv_moving_average_by_year.feather")
df_rv = feather.read_feather(RV_FILE)

# load metadata for deletion
METADATA = os.path.join(paths.ejhet_project_data_path, "metadata_maintext.feather")
metadata = feather.read_feather(METADATA)
valid_ids = set(metadata["id"].unique())

print(f"Metadata contains {len(valid_ids)} valid ids.")

# Load sentences to delete
DELETE_FILE = os.path.join(paths.ejhet_project_data_path, "sentences_to_delete.feather")
df_delete = feather.read_feather(DELETE_FILE)

# create lookup set
delete_keys = set(zip(df_delete["id"], df_delete["sentence_id"]))

# remove df to free memory
del df_delete
gc.collect()

# --------------------------- COMPUTE AVERAGE VECTOR FOR EACH DOCUMENT --------------------------- #

def extract_year(path):
    m = re.search(r"(\d{4})", os.path.basename(path))
    return int(m.group(1)) if m else None


def detect_source(path):
    if "istex_vectors" in path:
        return "istex"
    if "jstor_vectors" in path:
        return "jstor"
    return "elsevier"


# keep only files in range 1900-2020
files = [f for f in files if extract_year(f) and 1900 <= extract_year(f) <= 2009]

df_average_vectors_by_id = []

for file in tqdm(files):
  
    # load file
    df = feather.read_feather(file)
    # sécurité, on garde seulement les ids dans metadata car certains fichiers sbert contiennent des ids hors scope
    df = df[df["id"].isin(valid_ids)]

    # Ensure embedding is numpy array 
    df["embedding"] = df["embedding"].apply(np.array)
    
    # Add source column
    df["source"] = detect_source(file)

    if df["source"].iloc[0] in ["istex", "jstor"]:
        df["key"] = list(zip(df["id"], df["sentence_id"]))
        df = df[~df["key"].isin(delete_keys)]
        df = df.drop(columns="key")

    # Compute average vector for each document
    df = df.groupby(["id", "year", "source"])["embedding"].apply(lambda x: np.mean(np.vstack(x), axis=0)).reset_index()
    df.rename(columns={"embedding": "average_embedding"}, inplace=True)
    
    df_average_vectors_by_id.append(df)


# --------------------------- ADD REPRESENTATIVE VECTORS --------------------------- #

# Concatenate all dataframes
df_average_vectors_by_id = pd.concat(df_average_vectors_by_id, ignore_index=True)

# Merge embeddings by year
df_merged = df_average_vectors_by_id.merge(
    df_rv[["year", "embedding_by_year_centered"]],
    on="year",
    how="left")


print(f"fulltexts with average embeddings contains: {len(df_merged)} valid ids")

# --------------------------- COMPUTE COSINE SIMILARITY --------------------------- #

# Calcul des similarités cosinus
similarities_by_centered = []

for i, row in tqdm(df_merged.iterrows(), total=len(df_merged), desc="Calcul des similarités"):

    doc_vec = np.array(row["average_embedding"]) 
    centered_vec = np.array(row["embedding_by_year_centered"])

    # Sim to centered
    if centered_vec is not None:
        sim_c = cosine_similarity(doc_vec.reshape(1, -1), centered_vec.reshape(1, -1))[0][0]
    else:
        sim_c = np.nan
    similarities_by_centered.append(sim_c)


# Ajout des résultats
df_merged["cosine_sim_centered"] = similarities_by_centered


# rename columns for clarity
df_merged.rename(columns={"average_embedding": "doc_average_embedding"}, inplace=True)
df_merged.rename(columns={"embedding_by_year_centered": "rv_embedding"}, inplace=True)
df_merged.rename(columns={"cosine_sim_centered": "cosine_doc_with_rv"}, inplace=True)

# Sauvegarde
output_file = os.path.join(EJHET_DATA_PATH, f"fulltexts_cosine_sim_with_rv.feather")
df_merged.to_feather(output_file)

# load data to check
# df_check = feather.read_feather(output_file)
# print(df_check.head())