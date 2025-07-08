import os
import re
import glob
import pandas as pd
import numpy as np
import pyarrow.feather as feather
import paths
import gc

from tqdm import tqdm

from sklearn.metrics.pairwise import cosine_similarity

# --------------------------- LOAD DATA  --------------------------- #

JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
EMBEDDINGS_FOLDER = os.path.join(JSTOR_RAW_DATA_PATH, "sentences_embeddings")
pattern = os.path.join(EMBEDDINGS_FOLDER, "sentence_embeddings_*.feather")
all_files = glob.glob(pattern)

# Extract available years
all_years = sorted([
    int(re.search(r"(\d{4})", os.path.basename(f)).group(1))
    for f in all_files
])

# --- nouveau paramètre : fenêtre réduite à ±2 ans
WINDOW_SIZE = 2  # donc année -2 à année +2



# Remove noisy decades
decades = sorted(set(y - y % 10 for y in all_years))

records = []

for year in tqdm(all_years, desc="Processing years"):
    file_path = os.path.join(EMBEDDINGS_FOLDER, f"sentence_embeddings_{year}.feather")
    df = feather.read_feather(file_path)
    df["embedding"] = df["embedding"].apply(np.array)

    matched_vectors = df.loc[
        df["sentence"].str.contains(r"\brational(?:ity)?\b", case=False, regex=True),
        "embedding"
    ].tolist()

    del df
    gc.collect()

    if not matched_vectors:
        continue

    avg_year = np.mean(matched_vectors, axis=0)
    decade = year - (year % 10)
    
    # -- fenêtre centrée réduite
    window_years = [y for y in range(year - WINDOW_SIZE, year + WINDOW_SIZE + 1) if y in all_years]
    window_vectors = []

    for wy in window_years:
        wy_path = os.path.join(EMBEDDINGS_FOLDER, f"sentence_embeddings_{wy}.feather")
        df_wy = feather.read_feather(wy_path)
        df_wy["embedding"] = df_wy["embedding"].apply(np.array)

        window_vectors.extend(df_wy.loc[
            df_wy["sentence"].str.contains(r"\brational(?:ity)?\b", case=False, regex=True),
            "embedding"
        ])

        del df_wy
        gc.collect()

    avg_centered = np.mean(window_vectors, axis=0) if window_vectors else np.nan

    records.append({
        "year": year,
        "decade": decade,
        "embedding_by_year": avg_year,
        "embedding_by_decade": None,  # rempli plus tard
        "embedding_by_year_centered": avg_centered
    })

    del matched_vectors, window_vectors, avg_year, avg_centered
    gc.collect()
    
    

# Convertir en DataFrame
df_all = pd.DataFrame(records)

# Calculer les vecteurs moyens par décennie
decade_groups = df_all.groupby("decade")["embedding_by_year"].apply(lambda x: np.mean(np.stack(x), axis=0))

# Injecter dans la colonne `embedding_by_decade`
df_all["embedding_by_decade"] = df_all["decade"].map(decade_groups)

# Sauvegarde
output_file = os.path.join(JSTOR_RAW_DATA_PATH, "representative_embeddings.feather")
df_all.to_feather(output_file)


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














