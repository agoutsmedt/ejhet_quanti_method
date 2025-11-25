import os
import re
import glob
import pandas as pd
import numpy as np
import pyarrow.feather as feather
from collections import defaultdict, Counter
from tqdm import tqdm
import gc

import paths

# --------- FILES ----------
ISTEX = glob.glob(
    os.path.join(paths.econ_embeddings_data_path, "istex_vectors", "*.feather")
)
JSTOR = glob.glob(
    os.path.join(paths.econ_embeddings_data_path, "jstor_vectors", "*.feather")
)
ELSEVIER = glob.glob(
    os.path.join(paths.econ_embeddings_data_path, "elsevier_vectors", "*.feather")
)
files = ISTEX + JSTOR + ELSEVIER

TARGETS = ["rational", "rationality"]

# Counters by year
word_before = defaultdict(Counter)
word_after = defaultdict(Counter)

token_pat = re.compile(r"[A-Za-z]+")


def extract_neighbors(sentence, year):
    tokens = token_pat.findall(sentence.lower())

    for i, tok in enumerate(tokens):
        if tok in TARGETS:
            # mot avant
            if i > 0:
                word_before[year][tokens[i - 1]] += 1

            # mot après
            if i < len(tokens) - 1:
                word_after[year][tokens[i + 1]] += 1


for fp in tqdm(files, desc="Scanning files"):
    df = feather.read_feather(fp)

    # restrict to phrases containing rational / rationality
    mask = df["sentence"].str.contains(
        r"\brational(?:ity)?\b", case=False, regex=True, na=False
    )
    df = df[mask]

    if df.empty:
        continue

    years = df["year"].tolist()
    sentences = df["sentence"].tolist()

    for sent, y in zip(sentences, years):
        extract_neighbors(sent, y)

    del df
    gc.collect()


# --------- BUILD FINAL DF ---------

rows = []

for year, counter in word_before.items():
    for word, count in counter.items():
        rows.append((year, word, count, "before"))

for year, counter in word_after.items():
    for word, count in counter.items():
        rows.append((year, word, count, "after"))

result_df = pd.DataFrame(rows, columns=["year", "word", "count", "position"])
result_df = result_df.sort_values(
    by=["year", "position", "count"], ascending=[True, True, False]
)

# save
output_file = os.path.join(paths.ejhet_project_data_path, "rationality_neighbors_by_year.feather")
feather.write_feather(result_df, output_file)

