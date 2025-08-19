import os
import pandas as pd
import tqdm
import gc

import re

import pyreadr
import sqlite3
import numpy as np

from nltk.tokenize import sent_tokenize

import torch
from sentence_transformers import SentenceTransformer

# --------------------------- PARAMETERS --------------------------- #

import paths

JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
RDS_META_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "full_metadata_journals_cleaned_short.rds")
SQLITE_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "jstor_journals.sqlite")
OUTPUT_DIR = os.path.join(JSTOR_RAW_DATA_PATH, "sentences_embeddings")

# SENTENCE_BERT_MODEL = "all-MiniLM-L6-v2"
SENTENCE_BERT_MODEL = "all-mpnet-base-v2"
BATCH_SIZE = 32

os.makedirs(OUTPUT_DIR, exist_ok=True)

# --------------------------- LOAD AND PREP METADATA --------------------------- #

result = pyreadr.read_r(RDS_META_FILE)
metadata = result[None]

# Garde uniquement les articles de recherche en anglais et ajoute l'année
metadata = metadata[
    (metadata["refined_sub_type"] == "research-article") &
    (metadata["language"] == "eng")
][["id", "publication_year"]].drop_duplicates().reset_index(drop=True)

# Liste des années uniques
years = sorted(metadata["publication_year"].dropna().unique().astype(int).tolist())

# --------------------------- LOAD TEXT FROM SQLITE --------------------------- #

conn = sqlite3.connect(SQLITE_FILE)
df_text_cleaned = pd.read_sql_query("SELECT * FROM text_cleaned;", conn)
conn.close()

# Garde uniquement les IDs qui sont dans la métadonnée
df_text_cleaned = df_text_cleaned[df_text_cleaned["id"].isin(metadata["id"])]

# Add publication year to text DataFrame
df_text_cleaned = pd.merge(df_text_cleaned, metadata, on="id", how="inner")

# Filtrage du type de texte + texte non nul
df_text_cleaned = df_text_cleaned[(df_text_cleaned["type"] == "main_text") & (~df_text_cleaned["text"].isna())]

# --------------------------- LOAD MODEL --------------------------- #

model = SentenceTransformer(SENTENCE_BERT_MODEL)

if torch.cuda.is_available():
    print("✅ CUDA is available. Using GPU.")
else:
    print("⚠️ CUDA is NOT available. Will run on CPU.")

model.to("cuda" if torch.cuda.is_available() else "cpu")

# --------------------------- VALIDATION FUNCTION --------------------------- #


def is_valid_sentence(s):
    s = s.strip()

    # Longueur minimale
    if len(s) < 20:
        return False

    # Moins de 3 mots
    if len(s.split()) < 3:
        return False

    # Exclut les équations symboliques
    if any(char in s for char in "=()[]{}<>"):
        return False

    # Exclut les figures/tableaux ou citations type APA
    if re.search(r"(figure|table|chart|eq\.|equation|see also|ibid\.|pp?\.?\s*\d+([-–]\d+)?|op\.|cit\.)", s, re.IGNORECASE):
        return False

    # Beaucoup de chiffres (souvent tableaux de données)
    
    digit_ratio = sum(c.isdigit() for c in s) / max(len(s), 1)
    if digit_ratio > 0.3:
        return False

    # Beaucoup de majuscules (souvent titre ou citation bibliographique)
    upper_ratio = sum(c.isupper() for c in s) / max(len(s), 1)
    if upper_ratio > 0.6:
        return False

    return True


# --------------------------- PROCESS TEXTS BY YEAR --------------------------- #

for year in tqdm.tqdm(years, desc="Processing: "):

    df_year = df_text_cleaned[df_text_cleaned["publication_year"] == year]

    # Regrouper les pages par article
    df_grouped = df_year.groupby(["id", "publication_year"])["text"].apply(lambda pages: " ".join(pages)).reset_index()

    all_embeddings = []
    all_ids = []
    all_sentences = []
    all_years = []

    for _, row in tqdm.tqdm(df_grouped.iterrows(), total=len(df_grouped), desc=f"Year {year}"):
        
        
        doc_id = row["id"]
        pub_year = row["publication_year"]
        text = row["text"]

        sentences = [s for s in sent_tokenize(text) if is_valid_sentence(s)]
        
        if not sentences: 
          continue 
        
        try:
            embeddings = model.encode(
                sentences,
                batch_size=BATCH_SIZE,
                show_progress_bar=False,
                convert_to_numpy=True
            )
        except Exception as e:
            print(f"❌ Error on doc {doc_id}: {e}")
            continue

        all_ids.extend([doc_id] * len(sentences))
        all_years.extend([pub_year] * len(sentences))
        all_sentences.extend(sentences)
        all_embeddings.extend(embeddings)

    # Convert to DataFrame
    if all_embeddings:
        embedding_df = pd.DataFrame({
            "id": all_ids,
            "publication_year": all_years,
            "sentence": all_sentences,
            "embedding": all_embeddings  # Liste de floats (384-dim, etc.)
        })


        embedding_df.reset_index(drop=True, inplace=True)

        output_file = os.path.join(OUTPUT_DIR, f"sentence_embeddings_{year}.feather")
        embedding_df.to_feather(output_file)
        print(f"✅ Saved {len(embedding_df)} sentence embeddings for year {year} to {output_file}")

    # Libère mémoire RAM entre chaque année
    del all_embeddings, all_ids, all_sentences, all_years, embedding_df
    gc.collect()
    
    


