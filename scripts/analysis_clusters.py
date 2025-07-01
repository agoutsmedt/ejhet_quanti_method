# ------------------------- IMPORT --------------------------- #

# path management 
import paths 
import os

# data management 
import pyarrow.feather as feather
import pandas as pd
import numpy as np

# loop management 
import tqdm

# for saving model object
import joblib

# machine learning
from sklearn.decomposition import PCA


# plotting 
import plotly.express as px

# load data and model 
df = feather.read_feather(os.path.join(paths.jstor_raw_data, "paragraphs_with_concat_embeddings_kmeans.feather"))

final_kmeans = joblib.load(os.path.join(paths.jstor_raw_data, "kmeans_model.pkl"))


# ------------------- distance to centroid  ---------------- #

# get centroids for each value of clusters
clusters = df['cluster'].values
assigned_centroids = final_kmeans.cluster_centers_[clusters]

# get vectors matrix again and compute distance 
matrix_vectors = np.vstack(df['bert_embedding_concat'])
df['distance_to_centroid'] = np.linalg.norm(matrix_vectors - assigned_centroids, axis=1)

# ------------------------- Top 5 par cluster --------------------------- #

# Trouver top 5 paragraphes les plus proches par cluster
top_per_cluster = (
    df.sort_values(['cluster', 'distance_to_centroid'])
      .groupby('cluster')
      .head(10)
      .reset_index(drop=True)
)

# Colonnes utiles à garder
cols_to_keep = ['id', 'cluster', "window", 'distance_to_centroid', 'target_word']  # Ajouter 'paragraph_text' si besoin
top_per_cluster = top_per_cluster[cols_to_keep]

# filter cluster in cluster 0 and select text col 


# name  clusters 
cluster_names = pd.DataFrame({
    'cluster': list(range(10)),
    'name': [
        'Rational Expectations', # Cluster 0
        'Bounded Rationality',   # Cluster 1
        'Game Theory',           # Cluster 2
        'Macroeconomic Models',  # Cluster 3
        'Rational Actor',        # Cluster 4
        None,                    # Cluster 5 
        None,                    # Cluster 6
        None,                    # Cluster 7
        None,                    # Cluster 8
        None                     # Cluster 9
    ]
})

# Merge (équivalent de merge avec `by = "cluster", all.x = TRUE`)
df = df.merge(cluster_names, on='cluster', how = 'left')


# ------------------------- PLOT AREA --------------------------- #

# Compter le nombre de paragraphes par cluster et par année
cluster_year_counts = df.groupby(['publicationYear', 'name']).size().reset_index(name='count')

# Calculer la fréquence relative pour chaque année
cluster_year_counts['total_per_year'] = cluster_year_counts.groupby('publicationYear')['count'].transform('sum')
cluster_year_counts['relative_freq'] = cluster_year_counts['count'] / cluster_year_counts['total_per_year']

# Supprimer les clusters non nommés (optionnel)
cluster_year_counts = cluster_year_counts[cluster_year_counts['name'].notna()]


cluster_year_counts = cluster_year_counts[cluster_year_counts['publicationYear'] > 1920]

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

# ------------------------- PCA --------------------------- #

# Appliquer la PCA sur les embeddings concaténés
pca = PCA(n_components=2)
pca_result = pca.fit_transform(matrix_vectors)

# Ajouter les deux composantes principales au DataFrame
df['pca_1'] = pca_result[:, 0]
df['pca_2'] = pca_result[:, 1]

fig_pca = px.scatter(
    df, x='pca_1', y='pca_2', color='name',
    title='Projection PCA des paragraphes par cluster',
    labels={'name': 'Cluster'},
    hover_data=['id', 'cluster', 'distance_to_centroid'],
    opacity=0.3,
    render_mode='webgl'  # indispensable si beaucoup de points
)

# Modifier la taille des marqueurs (tous pareils)
fig_pca.update_traces(marker=dict(size=3))

# Enlever axes et grilles (équivalent theme_void)
fig_pca.update_layout(
    legend_title_text='Cluster',
    plot_bgcolor='white',
    margin=dict(l=60, r=60, t=60, b=60),  # marges autour du graphique
    xaxis=dict(
        showgrid=False,
        zeroline=False,
        showticklabels=False,
        range=[df['pca_1'].min() - 5, df['pca_1'].max() + 5]  # un peu d’espace autour
    ),
    yaxis=dict(
        showgrid=False,
        zeroline=False,
        showticklabels=False,
        range=[df['pca_2'].min() - 5, df['pca_2'].max() + 5]
    ),
    height=800,  # taille plus grande
    width=1400
)

fig_pca.show()
