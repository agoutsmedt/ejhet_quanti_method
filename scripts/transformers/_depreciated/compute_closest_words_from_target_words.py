import os
import pandas as pd
import numpy as np
import tqdm
import gc
import re
import paths

from nltk.corpus import stopwords
from sklearn.metrics.pairwise import cosine_similarity

from transformers import BertTokenizer, RobertaTokenizer


# --------------------------- CONFIG --------------------------- #

# nltk.download('stopwords')
stop_words = set(stopwords.words('english'))

def normalize_token(tok):
    return re.sub(r'\W+', '', tok.lower())

SELECTED_MODEL = "bert"  # "bert" or "econbert"

if SELECTED_MODEL == "econbert":
    model_type = "roberta"
    model_name = "econbert"
    tokenizer_path = "econbert/EconBERT_Model/econbert_tokenizer"
    tokenizer = RobertaTokenizer.from_pretrained(tokenizer_path)
elif SELECTED_MODEL == "bert":
    model_type = "bert"
    model_name = "bert-base-uncased"
    tokenizer = BertTokenizer.from_pretrained(model_name)
else:
    raise ValueError("Unsupported model")


# --------------------------- PATHS --------------------------- #

JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
EMBEDDINGS_FOLDER = os.path.join(JSTOR_RAW_DATA_PATH, "paragraphs_embeddings")
OUTPUT_FILE = os.path.join(JSTOR_RAW_DATA_PATH, f"nearest_neighbors_{model_name.replace('/', '_')}.feather")
INPUT_PARAGRAPH_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "paragraphs_with_target_word.parquet")

# --------------------------- LOAD METADATA --------------------------- #

df_meta = pd.read_parquet(INPUT_PARAGRAPH_FILE)
df_meta['id'] = df_meta['id'].astype(str)
df_meta.rename(columns={'publication_year': 'year'}, inplace=True)
df_meta = df_meta[['id', 'year', 'target_word']]

# --------------------------- UTILS --------------------------- #

# The merge_tokens_and_embeddings function merges subword tokens and their embeddings. In this case, it averages "rational" and "##ity" to get a single embedding for "rationality".
def merge_tokens_and_embeddings(tokens, embeddings):
    merged_tokens = []
    merged_embeddings = []

    current_token = ""
    current_vectors = []

    for tok, vec in zip(tokens, embeddings):
        if tok.startswith("##"):
            current_token += tok[2:]
            current_vectors.append(vec)
        else:
            if current_token:
                merged_tokens.append(current_token)
                merged_embeddings.append(np.mean(current_vectors, axis=0))
            current_token = tok
            current_vectors = [vec]

    if current_token:
        merged_tokens.append(current_token)
        merged_embeddings.append(np.mean(current_vectors, axis=0))

    return merged_tokens, merged_embeddings

# --------------------------- MAIN LOOP --------------------------- #

all_results = []

embedding_files = sorted([f for f in os.listdir(EMBEDDINGS_FOLDER) if f.endswith(".npz")])

for fname in tqdm.tqdm(embedding_files, desc="Processing yearly embeddings"):
    
    year = fname.split("_")[-1].replace(".npz", "")
    path = os.path.join(EMBEDDINGS_FOLDER, fname)

    data = np.load(path, allow_pickle=True)
    embeddings = data["embeddings"]
    tokens = data["tokens"]
    ids = data["ids"]

    for emb, toks, pid in zip(embeddings, tokens, ids):
        pid = str(pid)
        row = df_meta[df_meta['id'] == pid]

        if row.empty:
            all_results.append({"id": pid, "year": year, "target_word": None, "nearest_neighbors": None})
            continue

        target_word = row.iloc[0]['target_word']
        target_tokenized = tokenizer.tokenize(target_word.lower())

        match_indices = [
            i for i in range(len(toks) - len(target_tokenized) + 1)
            if list(toks[i:i + len(target_tokenized)]) == target_tokenized
        ]

        if not match_indices:
            all_results.append({"id": pid, "year": year, "target_word": target_word, "nearest_neighbors": None})
            continue

        start_idx = match_indices[len(match_indices) // 2]
        indices = list(range(start_idx, start_idx + len(target_tokenized)))

        try:
            target_vec = np.mean([emb[i] for i in indices], axis=0)
        except Exception:
            all_results.append({"id": pid, "year": year, "target_word": target_word, "nearest_neighbors": None})
            continue
        
        # Supprimer les tokens spéciaux
        special_tokens = {'[CLS]', '[SEP]', '[PAD]'}
        filtered = [(tok, vec) for tok, vec in zip(toks, emb) if tok not in special_tokens]
        if not filtered:
            all_results.append({"id": pid, "year": year, "target_word": target_word, "nearest_neighbors": None})
            continue
          
        # Fusionner tokens + embeddings
        toks, emb = zip(*filtered)
        merged_tokens, merged_embeddings = merge_tokens_and_embeddings(toks, emb)

        vectors = np.stack(merged_embeddings)
        sims = cosine_similarity([target_vec], vectors)[0]

        # Construire set de mots à exclure : base word, toutes ses variantes, stopwords
        base_form = re.sub(r'(ity|ies|al|s)$', '', target_word.lower())
        excluded_words = {normalize_token(target_word), base_form} | set(map(normalize_token, stop_words))

        top_indices = sims.argsort()[::-1]  # du plus similaire au moins
        
        neighbors = []

        for idx in top_indices:
            neighbor = merged_tokens[idx]
            norm_neighbor = normalize_token(neighbor)

            if norm_neighbor in excluded_words:
                continue
            if norm_neighbor.startswith(base_form):  # éviter "rationalism", "rationalized"...
                continue

            neighbors.append(neighbor)

        all_results.append({
            "id": pid,
            "year": year,
            "target_word": target_word,
            "neighbors": neighbors,
            "cosine_similarities": sims[top_indices].tolist()

        })

    # Clean up
    del data, embeddings, tokens, ids
    gc.collect()

# --------------------------- SAVE --------------------------- #

df_out = pd.DataFrame(all_results)
df_out.to_feather(OUTPUT_FILE)


