import os
import pandas as pd
import numpy as np
import torch
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity
import paths

# ---------------- PARAMETERS ---------------- #
JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
OUTPUT_DIR = os.path.join(JSTOR_RAW_DATA_PATH, "sentences_embeddings")
SENTENCE_BERT_MODEL = "all-mpnet-base-v2"
YEARS = [1925, 1950, 1975, 2000]
TOP_K = 5

# ---------------- LOAD MODEL ---------------- #
model = SentenceTransformer(SENTENCE_BERT_MODEL)
device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device)

# ---------------- SINGLE QUERY RATIONALITY ---------------- #

query = "Economic agents are supposed to be rational."

query_emb = model.encode([query], convert_to_numpy=True)[0]

def topk_for_year(year, top_k=5):
    """Retourne une liste de dicts (rank, similarity, sentence, year) pour l'année donnée."""
    feather_path = os.path.join(OUTPUT_DIR, f"sentence_embeddings_{year}.feather")
    if not os.path.exists(feather_path):
        print(f"⚠️ Fichier introuvable pour {year}: {feather_path}")
        return []

    df = pd.read_feather(feather_path)

    # Empile tous les embeddings dans une matrice (n_phrases x dim)
    X = np.vstack(df["embedding"].values)

    # Similarités cosinus entre la query et toutes les phrases de l'année
    sims = cosine_similarity([query_emb], X)[0]

    # Indices des top_k plus grandes similarités
    top_idx = np.argpartition(sims, -top_k)[-top_k:]

    # Trie décroissant
    top_idx = top_idx[np.argsort(-sims[top_idx])]

    rows = []
    for rank, j in enumerate(top_idx, 1):
        rows.append({
            "year": year,
            "rank": rank,
            "similarity": float(sims[j]),
            "sentence": df.iloc[j]["sentence"]
        })
    return rows

# ---------------- RUN & AGGREGATE ---------------- #
all_rows = []
for y in YEARS:
    all_rows.extend(topk_for_year(y, TOP_K))

results_df = pd.DataFrame(all_rows, columns=["year", "rank", "similarity", "sentence"])

# ---------------- DISPLAY ---------------- #
print(results_df)

# save in feather 
output_path = os.path.join(OUTPUT_DIR, "top_5_sentences_to_fake_sentence.feather")
results_df.to_feather(output_path)