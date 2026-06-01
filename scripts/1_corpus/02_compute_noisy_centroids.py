# compute_noisy_centroids.py

import os
import glob
import gc
import numpy as np
import pandas as pd
from tqdm import tqdm

import scripts.paths as paths
from scripts.functions.function import regex_guess

# ======================================================
# Online Centroid class
# ======================================================


class OnlineCentroid:
    def __init__(self, dim):
        self.sum_vec = np.zeros(dim, dtype=np.float32)
        self.count = 0

    def update(self, arr):
        if arr is None or len(arr) == 0:
            return
        self.sum_vec += arr.sum(axis=0)
        self.count += arr.shape[0]

    def finalize(self):
        if self.count == 0:
            return None
        return self.sum_vec / self.count


# ======================================================
# INIT
# ======================================================

CATS = ["affiliation", "ack", "header", "reference"]
EMB_DIM = 768

centroids = {cat: OnlineCentroid(EMB_DIM) for cat in CATS}
counts = {cat: 0 for cat in CATS}

VECTORS_PATH = paths.econ_embeddings_data_path
ISTEX = os.path.join(VECTORS_PATH, "istex_vectors")
JSTOR = os.path.join(VECTORS_PATH, "jstor_vectors")


files = glob.glob(os.path.join(ISTEX, "**", "*.feather"), recursive=True) + glob.glob(os.path.join(JSTOR, "**", "*.feather"), recursive=True)


# ======================================================
# LOOP ON ALL FILES
# ======================================================

for fname in tqdm(files, desc="Computing noisy centroids"):
    df = pd.read_feather(fname)

    sentences = df["sentence"].astype(str)
    embs = np.vstack(df["embedding"].values)

    df = None
    gc.collect()

    # assign regex categories
    cats = [regex_guess(s) for s in sentences]

    # collect noisy embeddings per category
    buckets = {cat: [] for cat in CATS}

    for s, v, c in zip(sentences, embs, cats):
        if c is not None:
            buckets[c].append(v)

    # update centroids
    for cat in CATS:
        if len(buckets[cat]) > 0:
            arr = np.vstack(buckets[cat])
            centroids[cat].update(arr)
            counts[cat] += arr.shape[0]


# ======================================================
# FINALIZE & SAVE
# ======================================================

rows = []

for cat in CATS:
    vec = centroids[cat].finalize()
    if vec is None:
        print(f"WARNING: no samples found for {cat}")
        continue

    row = {"cat": cat}
    for i, v in enumerate(vec):
        row[f"dim_{i}"] = float(v)
    rows.append(row)

df_out = pd.DataFrame(rows)

OUTPUT = os.path.join(paths.ejhet_project_data_path, "noisy_centroids.parquet")
df_out.to_parquet(OUTPUT, index=False)

