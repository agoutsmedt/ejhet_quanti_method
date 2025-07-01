import os
import paths
import pandas as pd
import numpy as np
import pyarrow.feather as feather

import 


# ------------------------- KMEAN --------------------------- #

# Define the number of clusters
BEST_K = 7

# Initialize KMeans with the best number of clusters
basic_bert_kmean = KMeans(n_clusters=BEST_K, n_init=25, random_state=42)
econbert_kmean = KMeans(n_clusters=BEST_K, n_init=25, random_state=42)

# Fit KMeans 
final_kmeans = basic_bert_kmean.fit(basic_bert_vectors_matrix_vectors)

# ------------------- distance to centroid  ---------------- #

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

# filter cluster in cluster 0 and select text col 


# name  clusters 
cluster_names = {
    'cluster': [0, 1, 2, 3, 4, 5, 6],
    'name': [
        'Theoretical Models',
        'Applied Rationality',
        'Market Dynamics',
        'Rational Expectations',
        'Rational Process',
        'Bounded Rationality',
        'Formal Rationality'
    ]
}

# Create the DataFrame
df_cluster_names = pd.DataFrame(cluster_names)


# Merge (équivalent de merge avec `by = "cluster", all.x = TRUE`)
df = df.merge(df_cluster_names, on= 'cluster', how = 'left')


# ------------------------- PLOT AREA --------------------------- #

# Compter le nombre de paragraphes par cluster et par année
cluster_year_counts = df.groupby(['publicationYear', 'name']).size().reset_index(name='count')

# Calculer la fréquence relative pour chaque année
cluster_year_counts['total_per_year'] = cluster_year_counts.groupby('publicationYear')['count'].transform('sum')
cluster_year_counts['relative_freq'] = cluster_year_counts['count'] / cluster_year_counts['total_per_year']

# Supprimer les clusters non nommés (optionnel)
cluster_year_counts = cluster_year_counts[cluster_year_counts['name'].notna()]


# cluster_year_counts = cluster_year_counts[cluster_year_counts['publicationYear'] > 1920]

# Plot: Area chart des fréquences relatives
fig_area = px.area(
    cluster_year_counts,
    x='publicationYear',
    y='relative_freq',
    color='name',
    title='Distribution temporelle des clusters (fréquences relatives)',
    labels={
        'relative_freq': 'Fréquence relative',
        'publicationYear': 'Année',
        'name': 'Cluster'
    }
)

fig_area.update_layout(
    plot_bgcolor='white',
    xaxis=dict(showgrid=False),
    yaxis=dict(showgrid=True, gridcolor='lightgray')
)

fig_area.show()

