import os
import re
import glob
import pandas as pd
import numpy as np
import pyarrow.feather as feather
import paths
import gc

from sklearn.metrics.pairwise import cosine_similarity


# --------------------------- LOAD DATA  --------------------------- #

JSTOR_RAW_DATA_PATH = paths.jstor_raw_data


EMBEDDINGS_FOLDER = os.path.join(JSTOR_RAW_DATA_PATH, "sentences_embeddings")

# Where your feather files are stored
pattern = os.path.join(EMBEDDINGS_FOLDER, "sentence_embeddings_*.feather")
all_files = glob.glob(pattern)

# Extract available years
all_years = sorted([
    int(re.search(r"(\d{4})", os.path.basename(f)).group(1))
    for f in all_files
])


decades = sorted(set(y - y % 10 for y in all_years))

# delete 1890, the first decade
decades = [d for d in decades if d >= 1900]

records = []

# select two decades to test

for decade in decades:
    
    decade_years = list(range(decade, decade + 10))
    matched_vectors = []
    
    print(f"Processing {decade}s...")
    
    # Filter files for the current decade
    decade_files = [f for f in all_files if any(str(year) in f for year in decade_years)]
    
    for file in decade_files:
       
        df = feather.read_feather(file)

        # Ensure embedding is numpy array 
        df["embedding"] = df["embedding"].apply(np.array)

        # Filter by keyword
        matched_vectors.extend(df.loc[df["sentence"].str.contains(r"\brational(?:ity)?\b", case=False, regex=True), "embedding"])

    if matched_vectors:
        avg_vector = np.mean(matched_vectors, axis=0)
        
        records.append({
            "decade": decade,
            "embedding": avg_vector
        })
        
        print(f"✅ {decade}s — {len(matched_vectors)} matches")
    else:
        print(f"⚠️ {decade}s — no matches")


# Create result DataFrame
df_decade_embeddings = pd.DataFrame(records)

# Save 
OUTPUT_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "representative_embeddings_by_decade.feather")
df_decade_embeddings.to_feather(OUTPUT_FILE)

# --------------------------- COMPUTE REPRESENTATIVE VECTORS --------------------------- #

# load

df_decade_embeddings = pd.read_feather(OUTPUT_FILE)

# Evaluate representative vector by computing cosine similarity 

# --------------------------- PHRASES LES PLUS PROCHES --------------------------- #

# param

FILTER_TARGET_WORDS = True  # Active/désactive le filtrage
TARGET_REGEX = r"\brational(?:ity)?\b"
compiled_target_regex = re.compile(TARGET_REGEX, flags=re.IGNORECASE)

# loop

df_decade_embeddings = pd.read_feather(OUTPUT_FILE)
top_sentences_by_decade = []

for _, row in df_decade_embeddings.iterrows():
    
    decade = row["decade"]
    print("Compute for decade:", decade)
    
    ref_vector = row["embedding"].reshape(1, -1)
    decade_years = list(range(decade, decade + (5 if decade == 2020 else 10)))
    
    matched_sentences = []

    for year in decade_years:
        file_path = os.path.join(EMBEDDINGS_FOLDER, f"sentence_embeddings_{year}.feather")
        df_year = feather.read_feather(file_path, columns=["sentence", "embedding", "id"])
        df_year["embedding"] = df_year["embedding"].apply(np.array)

        if FILTER_TARGET_WORDS:
            df_year = df_year[~df_year["sentence"].str.contains(compiled_target_regex)]

        matched_sentences.append(df_year)

    df_decade_sentences = pd.concat(matched_sentences, ignore_index=True)
    del matched_sentences, df_year
    gc.collect()
    
    embeddings_matrix = np.stack(df_decade_sentences["embedding"].values)
    similarities = cosine_similarity(embeddings_matrix, ref_vector).flatten()
    
    df_decade_sentences["similarity"] = similarities
    top_10 = df_decade_sentences.sort_values(by="similarity", ascending=False).head(10).copy()
    top_10["decade"] = decade

    top_sentences_by_decade.append(top_10)
    del df_decade_sentences, similarities, top_10, embeddings_matrix
    gc.collect()

df_top10_by_decade = pd.concat(top_sentences_by_decade, ignore_index=True)

suffix = "_no_target_words" if FILTER_TARGET_WORDS else ""
OUTPUT_FILE = os.path.join(JSTOR_RAW_DATA_PATH, f"top_sentences_by_decade{suffix}.feather")
df_top10_by_decade.to_feather(OUTPUT_FILE)














