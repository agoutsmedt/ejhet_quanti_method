import os
import paths
import pandas as pd
import numpy as np
import pyarrow.feather as feather
from sklearn.decomposition import PCA
import plotly.graph_objects as go
from plotly.subplots import make_subplots

# ------------------------- LOAD DATA --------------------------- #

basic_bert_vectors = feather.read_feather(os.path.join(paths.jstor_raw_data, "embeddings_bert-base-uncased.feather"))
econbert_vectors = feather.read_feather(os.path.join(paths.jstor_raw_data, "embeddings_econbert.feather"))

# Convert embeddings to matrices
basic_matrix = np.vstack(basic_bert_vectors['bert_embedding_concat'])
econ_matrix = np.vstack(econbert_vectors['bert_embedding_concat'])

# ------------------------- PCA --------------------------- #

# Fit PCA on each model separately
pca_basic = PCA(n_components=2)
basic_pca_result = pca_basic.fit_transform(basic_matrix)

pca_econ = PCA(n_components=2)
econ_pca_result = pca_econ.fit_transform(econ_matrix)

# Attach to dataframes
basic_bert_vectors['pca_1'] = basic_pca_result[:, 0]
basic_bert_vectors['pca_2'] = basic_pca_result[:, 1]

econbert_vectors['pca_1'] = econ_pca_result[:, 0]
econbert_vectors['pca_2'] = econ_pca_result[:, 1]

# ------------------------- PLOT --------------------------- #

fig = make_subplots(rows=1, cols=2, subplot_titles=("BERT base", "EconBERT"))

# BERT base plot
fig.add_trace(
    go.Scattergl(
        x=basic_bert_vectors['pca_1'],
        y=basic_bert_vectors['pca_2'],
        mode='markers',
        marker=dict(size=2, color='blue', opacity=0.3),
        text=basic_bert_vectors['window'],
        name='BERT base'
    ),
    row=1, col=1
)

# EconBERT plot
fig.add_trace(
    go.Scattergl(
        x=econbert_vectors['pca_1'],
        y=econbert_vectors['pca_2'],
        mode='markers',
        marker=dict(size=2, color='green', opacity=0.3),
        text=econbert_vectors['window'],
        name='EconBERT'
    ),
    row=1, col=2
)

fig.update_layout(
    title_text="PCA des paragraphes : BERT vs EconBERT",
    showlegend=False,
    height=500,
    width=1000
)

fig.show()



