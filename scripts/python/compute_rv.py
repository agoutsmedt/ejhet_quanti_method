import os
import re
import glob
import pandas as pd
import numpy as np
import pyarrow.feather as feather
import paths
import gc
from tqdm import tqdm

# recursive allows to search in subfolders 
ISTEX = glob.glob(os.path.join(paths.econ_embeddings_data_path, "istex_vectors", "**", "*.feather"), recursive=True)
JSTOR = glob.glob(os.path.join(paths.econ_embeddings_data_path, "jstor_vectors", "**", "*.feather"), recursive=True)
ELSEVIER = glob.glob(os.path.join(paths.econ_embeddings_data_path, "elsevier_vectors", "**", "*.feather"),recursive=True)
files = ISTEX + JSTOR + ELSEVIER

# ----- PATHS -----
output_yearly = os.path.join(paths.ejhet_project_data_path, "rv_average_by_year.feather")
output_moving = os.path.join(paths.ejhet_project_data_path, "rv_moving_average_by_year.feather")

# Load sentences to delete
DELETE_FILE = os.path.join(paths.ejhet_project_data_path, "sentences_to_delete.feather")
df_delete = feather.read_feather(DELETE_FILE)

# load metadata for deletion
METADATA = os.path.join(paths.ejhet_project_data_path, "metadata_maintext.feather")
metadata = feather.read_feather(METADATA)
valid_ids = set(metadata["id"].unique())

print(f"Metadata contains {len(valid_ids)} valid ids.")

# create lookup set for deletion
delete_keys = set(zip(df_delete["id"], df_delete["sentence_id"]))
del df_delete
gc.collect()

# ----- UTILS -----

def extract_year(path):
    m = re.search(r"(\d{4})", os.path.basename(path))
    return int(m.group(1)) if m else None


def detect_source(path):
    if "istex_vectors" in path:
        return "istex"
    if "jstor_vectors" in path:
        return "jstor"
    return "elsevier"


# ----- GROUP FILES BY YEAR -----

files_by_year = {}
for f in files:
    y = extract_year(f)
    if y and 1900 <= y <= 2010:
        files_by_year.setdefault(y, []).append(f)

all_years = sorted(files_by_year.keys())

# ----- PASSAGE 1 : VECTEUR MOYEN PAR ANNÉE -----
year_records = []
removed_ids = set() # to track removed ids


for year in tqdm(all_years, desc="Yearly mean vectors"):
    vecs = []
    count_matches = 0  # <--- compteur

    for fp in files_by_year[year]:
        df = feather.read_feather(fp)

        # sécurité, on garde seulement les ids dans metadata car certains fichiers sbert contiennent des ids hors scope
        df = df[df["id"].isin(valid_ids)]

        df["embedding"] = df["embedding"].apply(np.array)
        df["source"] = detect_source(fp)

        # filtrage seulement pour istex/jstor 
        if df["source"].iloc[0] in ["istex", "jstor"]:
            
            before_ids = set(df["id"].unique()) 
            df["key"] = list(zip(df["id"], df["sentence_id"]))
            df = df[~df["key"].isin(delete_keys)]
            df = df.drop(columns="key")

            after_ids = set(df["id"].unique())
            vanished = before_ids - after_ids
            removed_ids.update(vanished)
            if vanished:
                print(f"Year {year}, file {os.path.basename(fp)}: removed {len(vanished)} ids.")
        
        matches = df.loc[
            df["sentence"].str.contains(
                r"\brational(?:ity)?\b", case=False, regex=True
            ),
            "embedding",
        ]

        count_matches += len(matches)  
        vecs.extend(matches.tolist())

        del df, matches
        gc.collect()

    # moyenne (tu garantis toujours ≥1)
    avg_vec = np.mean(vecs, axis=0).astype(np.float32)

    year_records.append(
        {
            "year": year,
            "vec": avg_vec,
            "count": count_matches,  
        }
    )

print(f"Total removed ids: {len(removed_ids)}")


# save 
df_yearly = pd.DataFrame(year_records)
df_yearly.to_feather(output_yearly)





# ----- PASSAGE 2 : MOYENNE MOBILE CENTRÉE NON PONDÉRÉE -----

WINDOW_SIZE = 5

records = []

for year in tqdm(df_yearly["year"].tolist(), desc="Centered moving average"):
    # années de la fenêtre
    window = [
        y
        for y in range(year - WINDOW_SIZE, year + WINDOW_SIZE + 1)
        if y in df_yearly["year"].tolist()
    ]

    # vecteurs et counts de la fenêtre
    window_df = df_yearly.loc[df_yearly["year"].isin(window)]

    window_vecs = window_df["vec"].tolist()
    window_count = int(window_df["count"].sum()) 

    avg_centered = np.mean(window_vecs, axis=0).astype(np.float32)

    records.append(
        {
            "year": year,
            "embedding_by_year_centered": avg_centered,
            "count_centered": window_count, 
        }
    )

df_centered = pd.DataFrame(records)
df_centered.to_feather(output_moving)
