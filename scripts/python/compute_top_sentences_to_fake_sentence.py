import gc
import numpy as np
import pandas as pd
import pyarrow.feather as feather
from sklearn.metrics.pairwise import cosine_similarity
from sentence_transformers import SentenceTransformer

# ======================================================
# CONFIG
# ======================================================

FAKE_SENTENCE = "Economic agents are rational."
TARGET_YEARS = [1950, 1975, 2000]
TOP_N = 5
MODEL_NAME = "sentence-transformers/all-mpnet-base-v2"

INPUT_FILE  = r"C:\cloud\data\ejhet_project\closest_sentences_0.01_rationality_score_filtered_with_embeddings.feather"
OUTPUT_FILE = r"C:\cloud\data\ejhet_project\top_sentences_to_fake_sentence.feather"

# ======================================================
# 1) LOAD SENTENCES WITH EMBEDDINGS
# ======================================================

print("Loading sentences with embeddings...")
df = feather.read_feather(INPUT_FILE)
df = df[df["year"].isin(TARGET_YEARS)].reset_index(drop=True)
print(f"  {len(df):,} sentences for years {TARGET_YEARS}")

# ======================================================
# 2) ENCODE ONLY THE FAKE SENTENCE
# ======================================================

print(f"\nEncoding fake sentence: «{FAKE_SENTENCE}»")
model = SentenceTransformer(MODEL_NAME)
fake_vec = model.encode([FAKE_SENTENCE], normalize_embeddings=False)[0].astype(np.float32)
del model
gc.collect()

# ======================================================
# 3) COSINE SIMILARITY + TOP N PER YEAR
# ======================================================

sentence_vecs = np.vstack(df["embedding"].apply(np.array).values)
scores = cosine_similarity(sentence_vecs, fake_vec.reshape(1, -1)).flatten()
df["similarity_fake"] = scores

records = []
for year in TARGET_YEARS:
    df_year = df[df["year"] == year]
    df_top = df_year.nlargest(TOP_N, "similarity_fake").copy()
    df_top["rank"] = range(1, len(df_top) + 1)
    records.append(df_top)
    print(f"\nYear {year} — top {TOP_N} (sim: {df_top['similarity_fake'].min():.4f} – {df_top['similarity_fake'].max():.4f})")
    print(df_top[["rank", "similarity_fake", "sentence"]].to_string(index=False))

# ======================================================
# 4) ADD METADATA
# ======================================================

metadata = feather.read_feather(r"C:\cloud\data\ejhet_project\metadata_maintext.feather")
metadata = metadata[["id", "title", "authors", "journal"]].drop_duplicates("id")
metadata["first_author"] = metadata["authors"].str.split(r"[;,]").str[0].str.strip()

df_all = pd.concat(records, ignore_index=True)
df_all = df_all.merge(metadata[["id", "first_author", "title", "journal"]], on="id", how="left")
df_all = df_all[["year", "rank", "sentence", "similarity_fake","first_author", "title", "journal"]]

# ======================================================
# 5) SAVE
# ======================================================

df_all.to_feather(OUTPUT_FILE)
print(f"\nSaved to: {OUTPUT_FILE}")
