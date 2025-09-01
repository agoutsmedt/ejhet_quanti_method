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

# Parameters
WINDOW_SIZE = 5  

# output file based on window size
output_file = os.path.join(JSTOR_RAW_DATA_PATH, f"representative_vectors_window_{WINDOW_SIZE}.feather")

# Extract available years
all_years = sorted([
    int(re.search(r"(\d{4})", os.path.basename(f)).group(1))
    for f in all_files
])


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
df_all.to_feather(output_file)


# Evaluate representative vector by computing cosine similarity 









