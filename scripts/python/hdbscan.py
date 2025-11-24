import pandas as pd
import numpy as np
import pyarrow.feather as feather
import gc

import paths
import os


import umap.umap_ as umap
import hdbscan

from tqdm import tqdm

import plotnine 

# ---------------------------------------------------------
# 1. LOAD DATA
# ---------------------------------------------------------

input_path = os.path.join(paths.ejhet_project_data_path, "closest_sentences_0.01_rationality_score_filtered_with_embeddings.feather")
df = feather.read_feather(input_path)


# df must contain: year, sentence_id, embedding (list or vector)
df = df.dropna(subset=["embedding"])
df["embedding"] = df["embedding"].apply(lambda x: np.array(x))

# filter anything in 1980s and 1990 
# remove digit in year 
df["year"] = df["year"].astype(int)

# ---------------------------------------------------------
# 2. GLOBAL UMAP
# ---------------------------------------------------------

vectors = np.vstack(df["embedding"].values)

um = umap.UMAP(
    n_neighbors=15, # smaller to capture more local structure, bigger to capture more global structure
    min_dist=0.0,
    n_components=100, 
    metric="euclidean",  
    low_memory=True,  
    random_state=42,
)

vectors_umap = um.fit_transform(vectors)
df["umap"] = list(vectors_umap)

# temp save
feather.write_feather(df, os.path.join(paths.ejhet_project_data_path, "closest_sentences_0.01_rationality_score_filtered_with_umap.feather"))

# ---------------------------------------------------------
# 3. TIME WINDOWS
# ---------------------------------------------------------

# load if needed
# df = feather.read_feather(os.path.join(paths.ejhet_project_data_path, "closest_sentences_0.01_rationality_score_filtered_with_umap.feather"))

windows = [
    (1900, 1919),
    (1920, 1939),
    (1940, 1949),
    *[(y, y + 9) for y in range(1950, 2020, 10)],
]

# Format: list of dict windows
windows = [{"start": s, "end": e, "label": f"{s}-{e}"} for s, e in windows]


# ---------------------------------------------------------
# 4. FUNCTION: RUN HDBSCAN ON A WINDOW
# ---------------------------------------------------------
def run_hdbscan_window(dfw):
    um = np.vstack(dfw["umap"].values)
    emb = np.vstack(dfw["embedding"].values)  # <-- SBERT embeddings (768d)

    n = len(dfw)
    min_cluster_size = max(20, int(0.01 * n))
    min_samples = max(10, int(0.005 * n))

    clusterer = hdbscan.HDBSCAN(
        min_cluster_size=min_cluster_size,
        min_samples=min_samples,
        metric="euclidean",
        cluster_selection_method="eom",
    )

    labels = clusterer.fit_predict(um)

    dfw = dfw.copy()
    dfw["cluster"] = labels
    dfw["prob"] = clusterer.probabilities_
    dfw["is_noise"] = dfw["cluster"] == -1

    # compute centroids IN SBERT SPACE
    centroids = {}
    for c in sorted(set(labels)):
        if c == -1:
            continue

        mask = (labels == c) & (dfw["prob"] >= 0.5)

        # SBERT-based centroid
        centroids[c] = emb[mask].mean(axis=0)

    dfw["centroid"] = dfw["cluster"].apply(lambda c: None if c == -1 else centroids[c])

    return dfw


# ---------------------------------------------------------
# 5. APPLY WINDOW BY WINDOW
# ---------------------------------------------------------
dfs = []

for window in tqdm(windows, desc="Processing windows"):
    dfw = df[(df["year"] >= window["start"]) & (df["year"] <= window["end"])]

    if len(dfw) < 100:
        continue

    df_clusters = run_hdbscan_window(dfw)

    # add window label
    df_clusters["window"] = window["label"]

    dfs.append(
        {
            "window": window["label"],
            "df": df_clusters.reset_index(drop=True),
        }
    )

# bind all results if needed and add centroid 

all_clusters_df = pd.concat([df["df"] for df in dfs]).reset_index(drop=True)

# save 
save_path = os.path.join(paths.ejhet_project_data_path, "hdbscan_all_sentences_with_clusters.feather")
feather.write_feather(all_clusters_df, save_path)

# ---------------------------------------------------------
# 6. BUILD A SINGLE DATAFRAME OF TOP SENTENCES
# ---------------------------------------------------------

top_sentences = (
    all_clusters_df[all_clusters_df["cluster"] != -1]
    .sort_values("prob", ascending=False)
    .groupby(["window", "cluster"], as_index=False)
    .head(5) 
)

# arrange and relocate columns
col_order = ["window", "year", "sentence_id", "sentence", "cluster", "prob", "is_noise", "centroid", "umap"]
top_sentences = top_sentences[col_order]

top_sentences = top_sentences.sort_values(
    ["window", "cluster", "prob"], ascending=[True, True, False]
).reset_index(drop=True) 


# final concatenated dataframe

save_path = os.path.join(paths.ejhet_project_data_path, "hdbscan_top_sentences_per_window.feather")
feather.write_feather(top_sentences, save_path)

# ---------------------------------------------------------
# 7 DISTRIBUTION OF EACH CLUSTER OVER TIME (including noise)
# ---------------------------------------------------------

cluster_time_distribution = (
    all_clusters_df.groupby(["window", "cluster"], as_index=False)
    .size()
    .rename(columns={"size": "count"})
)

# rename cluster -1 to "noise" and other as "cluster" 
cluster_time_distribution["cluster"] = cluster_time_distribution["cluster"].apply(
    lambda x: "noise" if x == -1 else "cluster"
)


# plot 

p = (
    plotnine.ggplot(cluster_time_distribution)
    + plotnine.aes(x="window", y="count", fill="factor(cluster)")
    + plotnine.geom_bar(stat="identity", position="dodge")
    + plotnine.theme_light(base_size=14) 
    + plotnine.theme(axis_text_x=plotnine.element_text(rotation=45, hjust=1))
    + plotnine.labs(
        title="Distribution of Clusters Over Time Windows",
        x="Time Window",
        y="Number of Sentences",
        fill="Cluster",
    )
)
