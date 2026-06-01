# plot_noisy_vs_clean_distributions_balanced.py

import os
import gc
import numpy as np
import pandas as pd
from tqdm import tqdm
from sklearn.metrics.pairwise import cosine_similarity
from plotnine import ggplot, aes, geom_histogram, facet_wrap, labs, theme_minimal

import scripts.paths as paths
from scripts.functions.function import regex_guess


# ======================================================
# LOAD CENTROIDS
# ======================================================

centroid_path = os.path.join(paths.ejhet_project_data_path, "noisy_centroids.parquet")
centroids_df = pd.read_parquet(centroid_path)

centroids = {
    row["cat"]: row[[c for c in row.index if c.startswith("dim_")]].values.astype(
        np.float32
    )
    for _, row in centroids_df.iterrows()
}

CATS = list(centroids.keys())


# ======================================================
# PARAMETERS
# ======================================================

N_CLEAN_PER_FILE = 500  # phrases propres par fichier
rows = []

VECTORS_PATH = paths.econ_embeddings_data_path
ISTEX = os.path.join(VECTORS_PATH, "istex_vectors")
JSTOR = os.path.join(VECTORS_PATH, "jstor_vectors")

files = [
    os.path.join(ISTEX, f) for f in os.listdir(ISTEX) if f.endswith(".feather")
] + [os.path.join(JSTOR, f) for f in os.listdir(JSTOR) if f.endswith(".feather")]


for fname in tqdm(files, desc="Balanced sampling"):
    df = pd.read_feather(fname)

    sentences = df["sentence"].astype(str)
    embs = np.vstack(df["embedding"].values)

    df = None
    gc.collect()

    # detect categories
    cats = [regex_guess(s) for s in sentences]

    # ========== noisy (take all) ==========
    for cat in CATS:
        idx = [i for i, c in enumerate(cats) if c == cat]
        if len(idx) == 0:
            continue

        vecs = embs[idx]
        scores = cosine_similarity(vecs, centroids[cat].reshape(1, -1)).flatten()

        for sc in scores:
            rows.append({"cat": cat, "score": sc, "type": "noisy"})

    # ========== clean sample, balanced ==========
    clean_idx = [i for i, c in enumerate(cats) if c is None]

    if len(clean_idx) > 0:
        take = min(len(clean_idx), N_CLEAN_PER_FILE)
        sampled = np.random.choice(clean_idx, size=take, replace=False)

        vecs = embs[sampled]

        for cat in CATS:
            scores = cosine_similarity(vecs, centroids[cat].reshape(1, -1)).flatten()
            for sc in scores:
                rows.append({"cat": cat, "score": sc, "type": "clean"})


df = pd.DataFrame(rows)

# save dataframe
out_path = os.path.join(paths.ejhet_project_data_path, "noisy_vs_clean_balanced_scores.parquet")
df.to_parquet(out_path, index=False)


# ======================================================
# PLOT
# ======================================================

# load if needed
# df = pd.read_parquet(out_path)


p = (
    ggplot(df, aes(x="score", fill="type"))
    + geom_histogram(alpha=0.55, bins=50, position="identity")
    + facet_wrap("~cat", scales="free_y", drop=True)
    + theme_minimal()
    + labs(
        title="Similarity to noise centroids (balanced per year/file)",
        x="Cosine similarity",
        y="Count",
    )
)


# save plot
plot_path = os.path.join("paper", "images", "noisy_vs_clean_sentences_distributions.png")

p.save(plot_path)

# ======================================================
# Youden J statistic computation
# ======================================================

thresholds = []

for cat in tqdm(CATS, desc="Youden J computation"):
    subdf = df[df["cat"] == cat]

    noisy_scores = subdf[subdf["type"] == "noisy"]["score"].values
    clean_scores = subdf[subdf["type"] == "clean"]["score"].values

    all_scores = np.sort(np.unique(np.concatenate([noisy_scores, clean_scores])))

    best_j = -1
    best_thresh = None

    for thresh in all_scores:
        tpr = np.sum(noisy_scores >= thresh) / len(noisy_scores)
        fpr = np.sum(clean_scores >= thresh) / len(clean_scores)

        j = tpr - fpr

        if j > best_j:
            best_j = j
            best_thresh = thresh

    thresholds.append(
        {
            "cat": cat,
            "best_threshold": float(best_thresh),
            "youden_j": float(best_j),
            "n_noisy": len(noisy_scores),
            "n_clean": len(clean_scores),
        }
    )

thresh_df = pd.DataFrame(thresholds)


# save thresholds
thresh_out_path = os.path.join(paths.ejhet_project_data_path, "youden_j_thresholds.parquet")
thresh_df.to_parquet(thresh_out_path, index=False)