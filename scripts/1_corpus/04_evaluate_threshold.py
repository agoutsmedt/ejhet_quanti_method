import os
import glob
import numpy as np
import pandas as pd
from sklearn.metrics.pairwise import cosine_similarity

import scripts.paths as paths
from scripts.functions.function import regex_guess

# ======================================================
# PARAMETERS
# ======================================================

N_FILES_PER_SOURCE = 3   # take a small sample for evaluation
AMBIGUITY_MARGIN = 0.02  # +/- range around threshold
MAX_SHOW = 200  # number of lines in each evaluation table

# ======================================================
# 1. LOAD THRESHOLDS
# ======================================================

thresh_path = os.path.join(paths.ejhet_project_data_path, "youden_j_thresholds.parquet")
thresh_df = pd.read_parquet(thresh_path)

thresholds = {row["cat"]: float(row["best_threshold"]) for _, row in thresh_df.iterrows()}


# ======================================================
# 2. LOAD CENTROIDS
# ======================================================

centroids_path = os.path.join(paths.ejhet_project_data_path, "noisy_centroids.parquet")
centroids_df = pd.read_parquet(centroids_path)

centroids = {
    row["cat"]: row[[c for c in row.index if c.startswith("dim_")]].values.astype(np.float32)
    for _, row in centroids_df.iterrows()
}


# ======================================================
# 3. LIST ALL FEATHER FILES (no sampling of files)
# ======================================================

VECTORS_PATH = paths.econ_embeddings_data_path
ISTEX = os.path.join(VECTORS_PATH, "istex_vectors")
JSTOR = os.path.join(VECTORS_PATH, "jstor_vectors")

istex_files = glob.glob(os.path.join(ISTEX, "**", "*.feather"), recursive=True)
jstor_files = glob.glob(os.path.join(JSTOR, "**", "*.feather"), recursive=True)

# On prend TOUS LES FICHIERS
all_files = istex_files + jstor_files

# ======================================================
# 4. EVALUATION LOOP — SAMPLE 500 SENTENCES PER FILE
# ======================================================

N_PER_FILE = 500

rows = []

for fname in all_files:
    print(f"\nProcessing {fname}...")

    df = pd.read_feather(fname)

    # on prend un échantillon de 500 lignes max
    if len(df) > N_PER_FILE:
        df = df.sample(N_PER_FILE, random_state=42)

    sentences = df["sentence"].astype(str).tolist()
    embs = np.vstack(df["embedding"].values)

    for sent, emb in zip(sentences, embs):
        # regex category
        regex_cat = regex_guess(sent)

        # similarity to each centroid
        scores = {
            cat: float(
                cosine_similarity(emb.reshape(1, -1), centroids[cat].reshape(1, -1))[
                    0, 0
                ]
            )
            for cat in centroids
        }

        # closest category by similarity
        best_cat = max(scores, key=scores.get)
        best_score = scores[best_cat]

        # threshold decision
        threshold = thresholds[best_cat]
        flagged = best_score >= threshold

        rows.append(
            {
                "sentence": sent,
                "regex_cat": regex_cat,
                "best_cat": best_cat,
                "score": best_score,
                "threshold": threshold,
                "flagged_as_noise": flagged,
                "source_file": fname,
            }
        )

eval_df = pd.DataFrame(rows)


# ================================
# LOOP BY CATEGORY
# ================================

top_flagged_list = []
ambiguous_list = []

for best_cat, dfc in eval_df.groupby("best_cat"):
    # ----------------------------
    # TOP FLAGGED (haute confiance)
    # ----------------------------
    top_flagged = (
        dfc[dfc["flagged_as_noise"]]
        .sort_values("score", ascending=False)
        .head(MAX_SHOW)
        .assign(cat=best_cat)
    )
    top_flagged_list.append(top_flagged)

    # ----------------------------
    # AMBIGUOUS (autour du seuil)
    # ----------------------------
    ambiguous = (
        dfc[
            (dfc["score"] >= dfc["threshold"] - AMBIGUITY_MARGIN)
            & (dfc["score"] <= dfc["threshold"] + AMBIGUITY_MARGIN)
        ]
        .sort_values("score", ascending=False)
        .head(MAX_SHOW)
        .assign(cat=best_cat)
    )
    ambiguous_list.append(ambiguous)

# ================================
# FINAL DATAFRAMES
# ================================
df_top_flagged = pd.concat(top_flagged_list, ignore_index=True)
df_ambiguous = pd.concat(ambiguous_list, ignore_index=True)