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
output_file = os.path.join(JSTOR_RAW_DATA_PATH, "representative_vectors.feather")

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
df_all.to_feather(output_file)


# Evaluate representative vector by computing cosine similarity 

# --------------------------- PHRASES LES PLUS PROCHES --------------------------- #

# param

FILTER_TARGET_WORDS = False  # Active/désactive le filtrage
TARGET_REGEX = r"\brational(?:ity)?\b"
compiled_target_regex = re.compile(TARGET_REGEX, flags=re.IGNORECASE)

# loop
df_decade_embeddings = pd.read_feather(output_file)

# filter after 1890 
df_decade_embeddings = df_decade_embeddings[df_decade_embeddings["decade"] >= 1890] 


top_sentences_by_decade = []

for _, row in df_decade_embeddings.iterrows():
    
    decade = row["decade"]
    print("Compute for decade:", decade)
    
    # get rv 
    rv = row["embedding_by_year_centered"].reshape(1, -1)
    
    # get decade years (the unique years for this decade)
    decade_years = row["year"].unique()
    
    matched_sentences = []

    for year in decade_years:
        # load embeddings for the year
        file_path = os.path.join(EMBEDDINGS_FOLDER, f"sentence_embeddings_{year}.feather")
        df_year = feather.read_feather(file_path, columns=["sentence", "embedding", "id"])
        df_year["embedding"] = df_year["embedding"].apply(np.array)

        # if true, we remove the sentences that contain the target words 
        if FILTER_TARGET_WORDS:
            df_year = df_year[~df_year["sentence"].str.contains(compiled_target_regex)]

        matched_sentences.append(df_year)

    # once we get all sentences for the decade, we concatenate them into a single DataFrame
    df_sentences_of_decades = pd.concat(matched_sentences, ignore_index=True)
    # clean up memory
    del matched_sentences, df_year
    gc.collect()
    
    # compute cosine similarity
    embeddings_matrix = np.stack(df_sentences_of_decades["embedding"].values)
    similarities = cosine_similarity(embeddings_matrix, rv).flatten()
    
    # add similarity scores to the DataFrame
    df_sentences_of_decades["similarity"] = similarities

    # get the top 100 sentences based on similarity
    top_100 = df_sentences_of_decades.sort_values(by="similarity", ascending=False).head(100).copy()
    top_100["decade"] = decade
    # add to the list 
    top_sentences_by_decade.append(top_100)

    # clean up memory before the next iteration 
    del df_sentences_of_decades, similarities, top_100, embeddings_matrix
    gc.collect()


df_top100_by_decade = pd.concat(top_sentences_by_decade, ignore_index=True)

suffix = "_no_target_words" if FILTER_TARGET_WORDS else ""
OUTPUT_FILE = os.path.join(JSTOR_RAW_DATA_PATH, f"top_sentences_by_decade{suffix}.feather")
df_top100_by_decade.to_feather(OUTPUT_FILE)














