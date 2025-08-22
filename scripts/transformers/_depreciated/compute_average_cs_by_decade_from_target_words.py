# Compute average cosine similarity (mean/var) of tokens in paragraphs to the target word

import os
import re
import gc
import numpy as np
import pandas as pd
import tqdm 
from transformers import BertTokenizer
from sklearn.preprocessing import normalize
from nltk.corpus import stopwords

# ---------------- CONFIG ---------------- #
SPECIAL_TOKENS = {'[CLS]', '[SEP]', '[PAD]', '[MASK]', '[UNK]'}
TARGET_SET = {'rational', 'rationality'}

def normalize_token(tok: str) -> str:
    """Lowercase + remove non-alphanumerics."""
    return re.sub(r'\W+', '', tok.lower())

# stopwords (assume NLTK data is already available)
stop_words = set(map(normalize_token, stopwords.words('english')))
tokenizer = BertTokenizer.from_pretrained("bert-base-uncased")

# paths 
import paths  # doit définir paths.jstor_raw_data
JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
EMBEDDINGS_FOLDER = os.path.join(JSTOR_RAW_DATA_PATH, "paragraphs_embeddings")
OUTPUT_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "yearly_token_similarity_bert_mean_var.parquet")
INPUT_PARAGRAPH_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "paragraphs_with_target_word.parquet")

# ---------------- UTILS ---------------- #

def merge_wp_tokens(tokens, embeddings):
    merged_tokens, merged_vecs = [], []
    cur_tok, cur_vecs = "", []
    for tok, vec in zip(tokens, embeddings):
        if tok in SPECIAL_TOKENS:  # skip special
            continue
        if tok.startswith("##"):   # continuation
            cur_tok += tok[2:]; cur_vecs.append(vec)
        else:                      # new word: flush previous
            if cur_tok:
                merged_tokens.append(cur_tok)
                merged_vecs.append(np.mean(cur_vecs, axis=0))
            cur_tok, cur_vecs = tok, [vec]
    if cur_tok:
        merged_tokens.append(cur_tok)
        merged_vecs.append(np.mean(cur_vecs, axis=0))
    return merged_tokens, np.array(merged_vecs, dtype=np.float32)


def welford_update(state, x):
    """Online update for sample variance. state=(n, mean, m2)."""
    n, mean, m2 = state
    n += 1
    delta = x - mean
    mean += delta / n
    m2 += delta * (x - mean)
    return n, mean, m2


# ---------- META : construire para_id puis garder uniquement ce qui sert ----------
df_meta = pd.read_parquet(INPUT_PARAGRAPH_FILE)
df_meta["id"] = df_meta["id"].astype(str)           # <— colonne doc-id s'appelle 'ids' chez toi
df_meta["para_index"] = df_meta.groupby("id").cumcount()
df_meta["para_id"] = df_meta["id"] + "_" + df_meta["para_index"].astype(str)
df_meta.rename(columns={"publication_year":"year"}, inplace=True)

# ne garder que les colonnes utiles à l’alignement/traitement
df_meta = df_meta[["para_id","year","target_word"]].reset_index(drop=True)

# --------------------------- MAIN --------------------------- #

# dict: (target_word, token, year) -> (n, mean, m2)
agg = {}

# pointeur d’alignement global dans df_meta
offset = 0  

# get the list of embeddings files
embedding_files = [f for f in os.listdir(EMBEDDINGS_FOLDER) if f.endswith(".npz")]

# stats optionnels pour sanity-check (nous ciblons les tokens centrés)
seen_total, seen_center_match = 0, 0

for fname in tqdm.tqdm(embedding_files, desc="Processing yearly embeddings"):
    
    # extract year from filename
    year = int(fname.split("_")[-1].replace(".npz", ""))

    # load embeddings for the year 
    path = os.path.join(EMBEDDINGS_FOLDER, fname)
    data = np.load(path, allow_pickle=True)
    embeddings = data["embeddings"]   
    tokens = data["tokens"]  

    # number of paragraphs in the file  
    n_file = len(embeddings)
    # we take the next n_file rows from df_meta 
    meta_slice = df_meta.iloc[offset : offset + n_file]
    # sécurité : tailles alignées
    assert len(meta_slice) == n_file, "Meta slice and embeddings count mismatch."

    for emb, toks, row in zip(embeddings, tokens, meta_slice.itertuples(index=False)):
        target_word = str(row.target_word)
        year = int(row.year)

        # tokeniser target word et localiser sa séquence dans toks
        target_toks = tokenizer.tokenize(target_word.lower())

        matches = [
            i for i in range(len(toks) - len(target_toks) + 1)
            if list(toks[i:i+len(target_toks)]) == target_toks
        ]

        # sanity-check: si on n’a pas trouvé de match, on continue mais on incrémente le compteur
        seen_total += 1
        if not matches:
            continue

        # sanity-check: si le target word est au centre du paragraphe, on incrémente le compteur
        seen_center_match += 1

        # if matches found, take the middle one
        start_idx = matches[len(matches)//2]
        idxs = range(start_idx, start_idx + len(target_toks))

        target_vec = np.mean([emb[i] for i in idxs], axis=0).astype(np.float32, copy=False)

        # merge wordpiece tokens and their embeddings
        merged_tokens, merged_vecs = merge_wp_tokens(toks, emb)

        # cosinus via normalisation rapide (on normalise l'ensemble et ensuite on calcule les similarités)
        merged_vecs = normalize(merged_vecs, norm="l2", axis=1)
        t = target_vec / (np.linalg.norm(target_vec, ord=2) + 1e-12) # the last term avoids division by zero 
        sims = merged_vecs.dot(t).astype(np.float32, copy=False)

        # set d’exclusion (sans base_form)
        excluded = { "rational", "rationality" } | { normalize_token(w) for w in stop_words }

        # agregate stats by key (target_word, token_norm, year)
        for tok, sim in zip(merged_tokens, sims):
            tok_norm = normalize_token(tok)
            if not tok_norm or tok_norm in excluded:
                continue
            key = (target_word, tok_norm, year)
            agg[key] = welford_update(agg.get(key, (0, 0.0, 0.0)), float(sim))

    # avancer le pointeur global pour le fichier suivant
    offset += n_file

    del data, embeddings, tokens
    gc.collect()


# sanity-check
print(f"Total paragraphs processed: {seen_total}")
print(f"Paragraphs with target word in center: {seen_center_match}")

# build dataframe
rows = []
for (target_word, token, year), (n, mean, m2) in agg.items():
    var = m2 / (n - 1) if n > 1 else 0.0
    rows.append({
        "target_word": target_word,
        "token": token,
        "year": int(year),
        "mean_cosine": float(mean),
        "var_cosine": float(var),
        "count": int(n),
    })

df_out = pd.DataFrame(rows)
df_out.to_parquet(OUTPUT_FILE, index=False)

