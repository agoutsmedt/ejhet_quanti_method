import os
import re
import glob
import gc
import numpy as np
import pandas as pd
import pyarrow.feather as feather
from tqdm import tqdm
from sklearn.metrics.pairwise import cosine_similarity

import paths


# ======================================================
# 1) LOAD RV (representative vectors)
# ======================================================

RV_FILE = os.path.join(paths.ejhet_project_data_path, "rv_moving_average_by_year.feather")
df_rv = feather.read_feather(RV_FILE)

# ensure embeddings are np.arrays
df_rv["rv_embedding"] = df_rv["embedding_by_year_centered"].apply(lambda x: np.array(x))

METADATA = os.path.join(paths.ejhet_project_data_path, "metadata_maintext.feather")
metadata = feather.read_feather(METADATA)
valid_ids = set(metadata["id"].unique())
print(f"Metadata contains {len(valid_ids)} valid ids.")
del metadata
gc.collect()

# ======================================================
# 2) LOAD SENTENCES TO DELETE
# ======================================================

DELETE_FILE = os.path.join(paths.ejhet_project_data_path, "sentences_to_delete.feather")
df_delete = feather.read_feather(DELETE_FILE)

delete_keys = set(zip(df_delete["id"], df_delete["sentence_id"]))

del df_delete
gc.collect()

# ======================================================
# 3) DEFINE SENTENCE FILES PATHS
# ======================================================

VECTORS_PATH = paths.econ_embeddings_data_path

ISTEX = glob.glob(os.path.join(VECTORS_PATH, "istex_vectors", "**", "*.feather"), recursive=True)
JSTOR = glob.glob(os.path.join(VECTORS_PATH, "jstor_vectors", "**", "*.feather"), recursive=True)
ELSEVIER = glob.glob(os.path.join(VECTORS_PATH, "elsevier_vectors", "**", "*.feather"), recursive=True)

FILES = ISTEX + JSTOR + ELSEVIER


def extract_year(path):
    m = re.search(r"(\d{4})", os.path.basename(path))
    return int(m.group(1)) if m else None


# ======================================================
# 4) PROCESS YEAR BY YEAR — TOP 1%
# ======================================================

records = []

years = sorted(df_rv["year"].unique())

for year in tqdm(years, desc="Processing years"):
    
    # filter rv vector for that year
    rv_vec = df_rv.loc[df_rv["year"] == year, "rv_embedding"].iloc[0]

    # files for that year (could be from 1 to 3 sources)
    year_files = [fp for fp in FILES if extract_year(fp) == year]

    sentence_rows = []

    # for each file of that year, filter noisy sentences and compute similarity to RV
    for fp in year_files:
        
        # load file 
        df = feather.read_feather(fp)
        
        # sécurité, on garde seulement les ids dans metadata car certains fichiers sbert contiennent des ids hors scope
        df = df[df["id"].isin(valid_ids)]
        
        # ensure embeddings are np.arrays
        df["embedding"] = df["embedding"].apply(np.array)

        # -------- REMOVE FLAGGED SENTENCES 
        source = ("istex" if "istex_vectors" in fp else
                  "jstor" if "jstor_vectors" in fp else
                  "elsevier")
        
        if source in ["istex", "jstor"]:
            df["key"] = list(zip(df["id"], df["sentence_id"])) 
            df = df[~df["key"].isin(delete_keys)].drop(columns="key")

        # -------- SIMILARITY sentence ↔ RV
        X = np.vstack(df["embedding"].values)
        scores = cosine_similarity(X, rv_vec.reshape(1, -1)).flatten()

        df["similarity_rv"] = scores

        # store relevant columns
        sentence_rows.append(df[["id", "sentence_id", "sentence", "year", "similarity_rv"]])

        del df, X, scores
        gc.collect()

    if not sentence_rows:
        continue

    df_year = pd.concat(sentence_rows, ignore_index=True)

    # -------- COMPUTE TOP 1%
    N = len(df_year)
    k = max(1, int(0.01 * N))  # at least 1 sentence

    df_top = df_year.nlargest(k, "similarity_rv")

    records.append(df_top)
    del df_year, df_top
    gc.collect()


# ======================================================
# 5) SAVE OUTPUT
# ======================================================

df_all = pd.concat(records, ignore_index=True)

print(f"Total top 1% sentences across years: {len(df_all)}")
print(f"Total number of documents in top 1% sentences: {df_all['id'].nunique()}")


OUTPUT_FILE = os.path.join(paths.ejhet_project_data_path, "top1pct_sentences_by_year.feather")
df_all.to_feather(OUTPUT_FILE)

