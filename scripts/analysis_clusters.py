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
cols_to_keep = ['id', 'cluster', "windows", 'distance_to_centroid', 'target_word']  # Ajouter 'paragraph_text' si besoin
top_per_cluster = top_per_cluster[cols_to_keep]

# name 20 clusters 
cluster_names = pd.DataFrame({
    'cluster': list(range(10)),
    'name': [
        "Cluster 0: Calculation", 
        "Cluster 1: Expectations", 
        "Cluster 2: References",
        "Cluster 3: Sense",
        "Cluster 4: Deviations",
        "Cluster 5: Game",
        "Cluster 6: Agents",
        "Cluster 7: Bounded",
        "Cluster 8: Bounded 2",
        "Cluster 9: Expectations 2"
    ]
})

# Merge (équivalent de merge avec `by = "cluster", all.x = TRUE`)
df = df.merge(cluster_names, on='cluster', how = 'left')


# ------------------------- PLOT AREA --------------------------- #

# Assurer que l'année est bien en int
df['year'] = df['publicationYear'].astype(int)

# Compter les clusters par année
cluster_freq = (
    df.groupby(['year', 'name'])
      .size()
      .reset_index(name='count')
)

# Fréquence normalisée par année
cluster_freq['freq'] = cluster_freq.groupby('year')['count'].transform(lambda x: x / x.sum())
cluster_freq['name'] = cluster_freq['name'].astype(str)  # Pour couleurs plotly

# filter before 1920
cluster_freq = cluster_freq[cluster_freq['year'] >= 1920]

# Plot interactif area empilé
fig_area = px.area(
    cluster_freq,
    x='year',
    y='freq',
    color='name',
    line_group='name',
    title='Évolution temporelle des clusters',
    labels={'freq': 'Fréquence', 'year': 'Année'},
    line_shape="spline"
)

fig_area.update_layout(legend_title_text='Cluster')
fig_area.show()


# ------------------------- PCA --------------------------- #

# Appliquer la PCA sur les embeddings concaténés
pca = PCA(n_components=2)
pca_result = pca.fit_transform(matrix_vectors)

# Ajouter les deux composantes principales au DataFrame
df['pca_1'] = pca_result[:, 0]
df['pca_2'] = pca_result[:, 1]

# Scatter plot
fig_pca = px.scatter(
    df, x='pca_1', y='pca_2', color='name',
    title='Projection PCA des paragraphes par cluster',
    labels={'name': 'Cluster'},
    hover_data=['id', 'cluster', 'distance_to_centroid'],
    opacity=0.4  # <- ici l'équivalent de alpha
)

# Enlever axes et grilles (équivalent theme_void)
fig_pca.update_layout(
    legend_title_text='Cluster',
    plot_bgcolor='white',
    xaxis=dict(
        showgrid=False,
        zeroline=False,
        showticklabels=False
    ),
    yaxis=dict(
        showgrid=False,
        zeroline=False,
        showticklabels=False
    )
)

fig_pca.show()
