# --------------------------- INIT --------------------------- #

import os
import pandas as pd
import sqlite3
import pyreadr
import plotly.express as px

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
RDS_PATH = os.path.join(JSTOR_RAW_DATA_PATH, "year_metadata_journals.rds")

UNIGRAMS_PARQUET = "unigrams_merged_by_year.parquet"
REL_FREQ_PARQUET = "relative_freq_merged_by_year.parquet"

# --------------------------- LOAD DATA --------------------------- #

# DB
con = sqlite3.connect(DB_PATH)
df = pd.read_sql_query("SELECT id, page, text FROM text_cleaned", con)

# Metadata
metadata = pyreadr.read_r(RDS_PATH)[None]
df = df.merge(metadata, on="id", how="left")
df = df.dropna(subset=["datePublished"]).rename(columns={"datePublished": "year"})
df["year"] = df["year"].astype(str).str[:4].astype(int)

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

# --------------------------- TOKENIZE + COUNT --------------------------- #

year_token_counts = defaultdict(Counter)

batch_size = 1000

# tqdm sur les indices de batch
for i in tqdm(range(0, len(df), batch_size), desc="Tokenizing & counting"):
    batch = df.iloc[i:i+batch_size]
    texts = batch["text"].tolist()
    years = batch["year"].tolist()

    encodings = tokenizer.encode_batch(texts)

    for encoding, year in zip(encodings, years):
        tokens = encoding.tokens
        merged = merge_subwords(tokens)
        year_token_counts[year].update(merged)



# --------------------------- BUILD FINAL DF --------------------------- #

rows = []
for year, counter in year_token_counts.items():
    total = sum(counter.values())
    for token, count in counter.items():
        rows.append((year, token, count, count / total))

df_final = pd.DataFrame(rows, columns=["year", "token", "count", "relative_freq"])

# --------------------------- SAVE --------------------------- #

df_final.to_parquet(REL_FREQ_PARQUET, index=False)

