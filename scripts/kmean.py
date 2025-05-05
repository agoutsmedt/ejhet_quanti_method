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

# machine learning 
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score

# for saving model object
import joblib

# plotting 
import plotly.express as px

# --------------------------- DATA --------------------------- #

file_path = os.path.join(paths.jstor_raw_data, "paragraphs_with_concat_embeddings.feather")
df = feather.read_feather(file_path)

# convert to numpy array for efficient processing
matrix_vectors = np.vstack(df['bert_embedding_concat'])


# ------------------- Compute silhouette scores --------------------------- #

# k_range = range(2, 16)
# silhouette_scores = []
# 
# for k in tqdm.tqdm(k_range):
#     kmeans = KMeans(n_clusters=k, n_init=10, random_state=42)
#     cluster_labels = kmeans.fit_predict(matrix_vectors)
#     score = silhouette_score(matrix_vectors, cluster_labels)
#     silhouette_scores.append(score)
#     print(f"Silhouette score for k={k}: {score:.4f}")
# 
# 
# # Trouver le K avec la meilleure silhouette
# best_k_index = np.argmax(silhouette_scores)
# best_k = k_range[best_k_index]
# best_score = silhouette_scores[best_k_index]
# 
# # --------------------------- AFFICHER LE PLOT --------------------------- #
# 
# silhouette_df = pd.DataFrame({
#     'K': list(k_range),
#     'Silhouette Score': silhouette_scores
# })
# 
# fig = px.line(
#     silhouette_df,
#     x='K', y='Silhouette Score',
#     title='Choix optimal de K via Silhouette Score',
#     markers=True
# )
# fig.update_layout(xaxis_title='Nombre de clusters (K)',
#                   yaxis_title='Score de silhouette',
#                   template='plotly_white')
# fig.show()

# --------------------------- CLUSTER FINAL --------------------------- #

best_k = 10

# Entraîner le KMeans final avec le meilleur K
final_kmeans = KMeans(n_clusters=best_k, n_init=25, random_state=42)

# Fit the model
df['cluster'] = final_kmeans.fit_predict(matrix_vectors)

# save data and model kmean 
df.to_feather(os.path.join(paths.jstor_raw_data, "paragraphs_with_concat_embeddings_kmeans.feather"))

# save model
joblib.dump(final_kmeans, os.path.join(paths.jstor_raw_data, "kmeans_model.pkl"))
