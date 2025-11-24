import os
import re
import gc
import random

import pandas as pd
from tqdm import tqdm
from collections import defaultdict


import paths
import scripts.python.function
from scripts.python.function import regex_guess


# ======================================================
# CONFIG
# ======================================================

N_PER_YEAR = 150  # target sentences per year
MIN_YEAR = 1900
MAX_YEAR = 2024

OUT_PATH = os.path.join(paths.ejhet_project_data_path, "sample_sentences_for_labelling.parquet")

# ======================================================
# FILE DISCOVERY + YEAR EXTRACTION
# ======================================================

VECTORS_FOLDERS = paths.econ_embeddings_data_path

subdirs = [
    "istex_vectors",
    "jstor_vectors",
    "elsevier_vectors",
]

# dictionnaire final : {year: [list_of_files]}
files_by_year = defaultdict(list)

# regex année
YEAR_RE = re.compile(r"(19\d{2}|20\d{2})")

for sd in subdirs:
    folder = os.path.join(VECTORS_FOLDERS, sd)
    if not os.path.exists(folder):
        continue

    for fname in os.listdir(folder):
        if not fname.endswith(".feather"):
            continue

        match = YEAR_RE.search(fname)
        if match:
            year = int(match.group(1))
            fullpath = os.path.join(folder, fname)
            files_by_year[year].append(fullpath)

# liste triée des années
years = sorted(files_by_year.keys())

# ======================================================
# MAIN SAMPLING LOOP
# ======================================================

rows = []
target = N_PER_YEAR

for year in tqdm(years, desc="Sampling sentences"):
    # --- 1) Charger et concaténer tous les fichiers de l'année en un seul df ---
    dfs = []
    for fname in files_by_year[year]:
        df = pd.read_feather(fname)[["sentence"]]  # on ne garde que la colonne utile
        dfs.append(df)

    df_year = pd.concat(dfs, ignore_index=True)
    sentences = df_year["sentence"].astype(str).tolist()

    # --- 2) Shuffle global ---
    random.shuffle(sentences)

    # --- 3) Head global ---
    sampled = sentences[:target]

    # --- 4) Stockage + regex guess ---
    for s in sampled:
        rows.append({"year": year, "sentence": s, "regex_guess": regex_guess(s)})
    
    del df_year, dfs, sentences, sampled
    gc.collect()

# --- Convert to df ---
sample_df = pd.DataFrame(rows)

# --- save ---
sample_df.to_parquet(OUT_PATH, index=False)
