import os
import pandas as pd
import tqdm
import gc

import re

from nltk.tokenize import sent_tokenize

import torch
from sentence_transformers import SentenceTransformer

# --------------------------- PARAMETERS --------------------------- #

import paths

JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
AB_DIR = os.path.join(JSTOR_RAW_DATA_PATH, "abstract_wos", "abstract_use_this_one_all_info.csv")
AB_INFO_DIR = os.path.join(JSTOR_RAW_DATA_PATH, "abstract_wos", "all_art.parquet")
OUTPUT_DIR = os.path.join(JSTOR_RAW_DATA_PATH, "abstract_wos", "sentences_embeddings")

# SENTENCE_BERT_MODEL = "all-MiniLM-L6-v2"
SENTENCE_BERT_MODEL = "all-mpnet-base-v2"

BATCH_SIZE = 32

os.makedirs(OUTPUT_DIR, exist_ok=True)

# --------------------------- LOAD AND PREP TEXTS --------------------------- #

# load texts 
abstracts = pd.read_csv(AB_DIR)

# load additional info
abstracts_info = pd.read_parquet(AB_INFO_DIR)

# add year from abstracts_info 
abstracts = abstracts.merge(abstracts_info[["ID_Art", "Annee_Bibliographique"]], on="ID_Art", how="left")
del abstracts_info 


# filter revue nan  
abstracts = abstracts[~abstracts["Revue"].isna()]
abstracts = abstracts[abstracts["Abstract"].notna()]

# filter non economic abstracts 
abstracts = abstracts[abstracts["Code_Discipline"] == 119]

# rename ID art in ID 
abstracts = abstracts.rename(columns={"ID_Art": "id",
                                     "Annee_Bibliographique": "publication_year",
                                     "Abstract": "text"})

# extract years for chunk processing
years = abstracts["publication_year"].dropna().unique()
years.sort()

# filter years not computed yet 

years = [year for year in years if not os.path.exists(os.path.join(OUTPUT_DIR, f"sentence_embeddings_{year}.feather"))]

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

    df_year = abstracts[abstracts["publication_year"] == year]

    all_embeddings = []
    all_ids = []
    all_sentences = []
    all_years = []

    for _, row in tqdm.tqdm(df_year.iterrows(), total=len(df_year), desc=f"Year {year}"):
        
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
    
    


