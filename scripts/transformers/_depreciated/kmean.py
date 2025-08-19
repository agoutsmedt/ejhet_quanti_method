import os
import paths
import pandas as pd
import numpy as np
import pyarrow.feather as feather

from sklearn.cluster import KMeans

from plotly import express as px

# ------------------------- KMEAN --------------------------- #

# Data 
df = feather.read_feather(os.path.join(paths.jstor_raw_data, "embeddings_econbert.feather"))
matrix_vectors = np.vstack(df['bert_embedding_concat'].values)

#  Load the model 
BEST_K = 20

kmean = KMeans(n_clusters=BEST_K, n_init=25, random_state=42)

# Extract the matrix of vectors
matrix_vectors = np.vstack(df['bert_embedding_concat'].values)

# Fit KMeans 
final_kmeans = kmean.fit(matrix_vectors)

# add clusters to the DataFrame

df['cluster'] = final_kmeans.predict(matrix_vectors)

# ------------------- distance to centroid  ---------------- #

# Create a DataFrame with the original data

# get centroids for each value of clusters
clusters = df['cluster'].values
assigned_centroids = final_kmeans.cluster_centers_[clusters]

# get vectors matrix again and compute distance 
df['distance_to_centroid'] = np.linalg.norm(matrix_vectors - assigned_centroids, axis=1)

# ------------------------- Top 5 par cluster --------------------------- #

# Trouver top 5 paragraphes les plus proches par cluster
top_per_cluster = (
    df.sort_values(['cluster', 'distance_to_centroid'])
      .groupby('cluster')
      .head(20)
      .reset_index(drop=True)
)

# Colonnes utiles à garder
cols_to_keep = ['id', 'cluster', "window", 'distance_to_centroid', 'target_word']  # Ajouter 'paragraph_text' si besoin
top_per_cluster = top_per_cluster[cols_to_keep]


# name  clusters using gemini 

cluster_names = {
    0: "Rational Economic Planning",
    1: "Rational Expectations Macroeconomics",
    2: "Critiques of Rationality",
    3: "Information and Rationality",
    4: "Rationality in Practice",
    5: "Bounded Rationality",
    6: "Equilibrium and Stability",
    7: "Individual Rational Choice",
    8: "Paradigms of Rationality",
    9: "Rationality and Policy",
    10: "Financial Market Rationality",
    11: "Heterogeneous Agents",
    12: "Political Economy",
    13: "Consumer Rationality",
    14: "Equilibrium Properties",
    15: "Policy and Credibility",
    16: "Foundations of Rationality",
    17: "Learning and Rationality",
    18: "Limits to Arbitrage",
    19: "Rationality and Institutions"
}

df_clusters = pd.DataFrame(list(cluster_names.items()), columns=['cluster', 'name'])
# Create the DataFrame


# Merge (équivalent de merge avec `by = "cluster", all.x = TRUE`)
df = df.merge(df_clusters, on= 'cluster', how = 'left')


# ------------------------- PLOT AREA --------------------------- #

# Compter le nombre de paragraphes par cluster et par année
cluster_year_counts = df.groupby(['publication_year', 'name']).size().reset_index(name='count')

# Calculer la fréquence relative pour chaque année
cluster_year_counts['total_per_year'] = cluster_year_counts.groupby('publication_year')['count'].transform('sum')
cluster_year_counts['relative_freq'] = cluster_year_counts['count'] / cluster_year_counts['total_per_year']

# Supprimer les clusters non nommés (optionnel)
cluster_year_counts = cluster_year_counts[cluster_year_counts['name'].notna()]



cluster_year_counts = cluster_year_counts[cluster_year_counts['publication_year'] > 1920]

# Plot: Area chart des fréquences relatives
fig_area = px.area(
    cluster_year_counts,
    x='publication_year',
    y='relative_freq',
    color='name',
    title='Distribution temporelle des clusters (fréquences relatives)',
    labels={
        'relative_freq': 'Fréquence relative',
        'publication_year': 'Année',
        'name': 'Cluster'
    }
)

fig_area.update_layout(
    plot_bgcolor='white',
    xaxis=dict(showgrid=False),
    yaxis=dict(showgrid=True, gridcolor='lightgray')
)

fig_area.show()

