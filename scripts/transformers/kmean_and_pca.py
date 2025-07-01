# ------------------------- IMPORTS --------------------------- #
import os
import joblib
import tqdm
import numpy as np
import pandas as pd
import pyarrow.feather as feather
import plotly.express as px

from sklearn.decomposition import PCA
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

# ------------------------- PARAMETERS --------------------------- #
try:
    import paths
    RAW_DATA_PATH = paths.jstor_raw_data
except ImportError:
    RAW_DATA_PATH = "your/path/to/data"

# User-defined model name, e.g. 'bert-base-uncased' or 'econbert'
MODEL_NAME = "bert-base-uncased"  # Change as needed
MODEL_KEY = MODEL_NAME.replace("/", "_")

EMBEDDING_FILE = f"embeddings_{MODEL_KEY}.feather"
KMEANS_OUTPUT_FILE = f"paragraphs_with_{MODEL_KEY}_kmeans.feather"
MODEL_OUTPUT_FILE = f"kmeans_model_{MODEL_KEY}.pkl"
BEST_K = 7

# ------------------------- LOAD DATA --------------------------- #
embedding_path = os.path.join(RAW_DATA_PATH, EMBEDDING_FILE)
df = feather.read_feather(embedding_path)
matrix_vectors = np.vstack(df['bert_embedding_concat'])

# ------------------------- CLUSTERING --------------------------- #
final_kmeans = KMeans(n_clusters=BEST_K, n_init=25, random_state=42)
df['cluster'] = final_kmeans.fit_predict(matrix_vectors)

# Save clustered data and model
df.to_feather(os.path.join(RAW_DATA_PATH, KMEANS_OUTPUT_FILE))
joblib.dump(final_kmeans, os.path.join(RAW_DATA_PATH, MODEL_OUTPUT_FILE))

# ------------------------- CLUSTER NAMING --------------------------- #
cluster_names = {
    0: 'Theoretical Models',
    1: 'Applied Rationality',
    2: 'Market Dynamics',
    3: 'Rational Expectations',
    4: 'Rational Process',
    5: 'Bounded Rationality',
    6: 'Formal Rationality'
}
df['name'] = df['cluster'].map(cluster_names)

# ------------------------- DISTANCE TO CENTROID --------------------------- #
assigned_centroids = final_kmeans.cluster_centers_[df['cluster'].values]
df['distance_to_centroid'] = np.linalg.norm(matrix_vectors - assigned_centroids, axis=1)

# ------------------------- TOP PARAGRAPHS --------------------------- #
top_paragraphs = (
    df.sort_values(['cluster', 'distance_to_centroid'])
      .groupby('cluster')
      .head(20)
      .reset_index(drop=True)
      [['id', 'cluster', 'window', 'distance_to_centroid', 'target_word']]
)

# ------------------------- AREA PLOT --------------------------- #
cluster_year_counts = df.groupby(['publicationYear', 'name']).size().reset_index(name='count')
cluster_year_counts['total_per_year'] = cluster_year_counts.groupby('publicationYear')['count'].transform('sum')
cluster_year_counts['relative_freq'] = cluster_year_counts['count'] / cluster_year_counts['total_per_year']
cluster_year_counts = cluster_year_counts[cluster_year_counts['name'].notna()]

fig_area = px.area(
    cluster_year_counts,
    x='publicationYear', y='relative_freq', color='name',
    title=f'Distribution temporelle des clusters ({MODEL_NAME})',
    labels={'relative_freq': 'Fréquence relative', 'publicationYear': 'Année', 'name': 'Cluster'}
)
fig_area.update_layout(plot_bgcolor='white', xaxis=dict(showgrid=False), yaxis=dict(showgrid=True, gridcolor='lightgray'))
fig_area.show()

# ------------------------- PCA PLOT --------------------------- #



pca = PCA(n_components=2)
pca_result = pca.fit_transform(matrix_vectors)

df['pca_1'] = pca_result[:, 0]
df['pca_2'] = pca_result[:, 1]

print(f"✅ PCA Explained Variance: PC1 = {pca.explained_variance_ratio_[0]:.2%}, PC2 = {pca.explained_variance_ratio_[1]:.2%}")

fig_pca = px.scatter(
    df,
    x='pca_1',
    y='pca_2',
    color='name',
    title=f'Projection PCA interactive des paragraphes ({MODEL_NAME})',
    hover_data={
        # 'id': True,
        # 'cluster': True,
        # 'distance_to_centroid': ':.4f',
        'window': True  # This is the full paragraph text
    },
    opacity=0.4,
    render_mode='webgl'
)

fig_pca.update_traces(marker=dict(size=3))
fig_pca.show()

