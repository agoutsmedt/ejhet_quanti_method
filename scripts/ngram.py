# --------------------------- INIT --------------------------- #

import os
import pandas as pd
import sqlite3
import pyreadr

from tqdm import tqdm

from collections import defaultdict, Counter

from tokenizers import Tokenizer

# --------------------------- PATHS --------------------------- #

try:
    import paths
    JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
except ImportError:
    JSTOR_RAW_DATA_PATH = "jstor_data"

DB_PATH = os.path.join(JSTOR_RAW_DATA_PATH, "jstor_journals.sqlite")
RDS_PATH = os.path.join(JSTOR_RAW_DATA_PATH, "full_metadata_journals_cleaned_short.rds")

REL_FREQ_PARQUET = os.path.join(JSTOR_RAW_DATA_PATH, "relative_freq_merged_by_year.parquet")

# --------------------------- LOAD DATA --------------------------- #

# DB
con = sqlite3.connect(DB_PATH)
df = pd.read_sql_query("SELECT id, page, text FROM text_cleaned", con)

# Metadata
metadata = pyreadr.read_r(RDS_PATH)[None]

# merge 
df = df.merge(metadata, on="id", how="left")

# rename and clean year variable 
df = df.dropna(subset=["publication_year"]).rename(columns={"publication_year": "year"})
df["year"] = df["year"].astype(str).str[:4].astype(int)

# remove na from text

df = df.dropna(subset=["text"])

# --------------------------- TOKENIZER --------------------------- #

tokenizer = Tokenizer.from_pretrained("bert-base-uncased")

def merge_subwords(tokens):
    words = []
    current = ""
    for token in tokens:
        if token.startswith("##"):
            current += token[2:]
        else:
            if current:
                words.append(current)
            current = token
    if current:
        words.append(current)
    return words

# --------------------------- TOKENIZE + COUNT WITH COUNTER --------------------------- #

year_token_counts = defaultdict(Counter)

batch_size = 1000

# tqdm sur les indices de batch
for i in tqdm(range(0, len(df), batch_size), desc="Tokenizing & counting"):
    batch = df.iloc[i:i+batch_size]
    texts = batch["text"].tolist()
    years = batch["year"].tolist()

    # Tokenize the batch of texts
    encodings = tokenizer.encode_batch(texts)

    # merge subwords and count tokens by year
    for encoding, year in zip(encodings, years):
        tokens = encoding.tokens
        merged = merge_subwords(tokens)
        year_token_counts[year].update(merged)



# --------------------------- COMPUTE RELATIVE FREQUENCY AND FINALIZE DF --------------------------- #

rows = []
for year, counter in year_token_counts.items():
    total = sum(counter.values())
    for token, count in counter.items():
        rows.append((year, token, count, count / total))

df_final = pd.DataFrame(rows, columns=["year", "token", "count", "relative_freq"])

# --------------------------- SAVE --------------------------- #

df_final.to_parquet(REL_FREQ_PARQUET, index=False)


