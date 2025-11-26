import os
import re
import glob
import pandas as pd
import numpy as np
import pyarrow.feather as feather
import paths
import gc
from tqdm import tqdm
from scripts.python.function import get_flagged_sentences

# ---------------------------
# PATHS
# ---------------------------

VECTORS_PATH = paths.econ_embeddings_data_path
OUTPUT_FILE = os.path.join(paths.ejhet_project_data_path, "sentences_to_delete.feather")

# ---------------------------
# DETECT FILE SOURCES
# ---------------------------

ISTEX = glob.glob(os.path.join(VECTORS_PATH, "istex_vectors", "**", "*.feather"), recursive=True)
JSTOR = glob.glob(os.path.join(VECTORS_PATH, "jstor_vectors", "**", "*.feather"), recursive=True)

files = ISTEX + JSTOR 

# ---------------------------
# HELPERS
# ---------------------------


def extract_year(path):
    m = re.search(r"(\d{4})", os.path.basename(path))
    return int(m.group(1)) if m else None


def detect_source(path):
    if "istex_vectors" in path:
        return "istex"
    if "jstor_vectors" in path:
        return "jstor"
    return "elsevier"


# ---------------------------
# LOAD CENTROIDS / THRESHOLDS
# ---------------------------

centroids_df = pd.read_parquet(os.path.join(paths.ejhet_project_data_path, "noisy_centroids.parquet"))

centroids = {
    row["cat"]: row[[c for c in row.index if c.startswith("dim_")]].values.astype(
        np.float32
    )
    for _, row in centroids_df.iterrows()
}

thresholds_df = pd.read_parquet(os.path.join(paths.ejhet_project_data_path, "youden_j_thresholds.parquet"))

thresholds = {row["cat"]: float(row["best_threshold"]) for _, row in thresholds_df.iterrows()}

# ---------------------------
# COLLECT NOISY SENTENCES
# ---------------------------

records = []

for fname in tqdm(files, desc="Detecting noisy sentences"):
    source = detect_source(fname)

    df = feather.read_feather(fname)

    # Ensure embedding is numpy array for filtering
    df["embedding"] = df["embedding"].apply(np.array)

    df_removed = get_flagged_sentences(df, centroids, thresholds)
    # Remove embedding column to save memory
    df_removed = df_removed.drop(columns=["embedding"])

    del df
    gc.collect()

    
    # Add source 
    df_removed["source"] = source 

    records.append(df_removed)

# ---------------------------
# SAVE
# ---------------------------

df_deleted_all = pd.concat(records, ignore_index=True)

# rename columns for clarity
df_deleted_all = df_deleted_all.rename(
    columns={
        "best_cat": "noise_category_detected",
        "score" : "similarity_to_noise_centroid"
    }
)

# save to feather
df_deleted_all.to_feather(OUTPUT_FILE)


