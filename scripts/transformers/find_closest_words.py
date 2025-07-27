import os
import pandas as pd
import numpy as np
import tqdm
import gc
import re
import paths

import nltk
from nltk.corpus import stopwords
from sklearn.metrics.pairwise import cosine_similarity

from transformers import BertTokenizer, RobertaTokenizer



import matplotlib.pyplot as plt
from collections import Counter
from wordcloud import WordCloud


# --------------------------- CONFIG --------------------------- #

nltk.download('stopwords')
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

TOP_N = 10

# --------------------------- PATHS --------------------------- #

import paths
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
        top_neighbors = []

        for idx in top_indices:
            neighbor = merged_tokens[idx]
            norm_neighbor = normalize_token(neighbor)

            if len(top_neighbors) >= TOP_N:
                break
            if norm_neighbor in excluded_words:
                continue
            if norm_neighbor.startswith(base_form):  # éviter "rationalism", "rationalized"...
                continue

            top_neighbors.append(neighbor)

        all_results.append({
            "id": pid,
            "year": year,
            "target_word": target_word,
            "nearest_neighbors": top_neighbors
        })

    # Clean up
    del data, embeddings, tokens, ids
    gc.collect()

# --------------------------- SAVE --------------------------- #

df_out = pd.DataFrame(all_results)
df_out.to_feather(OUTPUT_FILE)
print(f"✅ Saved full neighbors dataset to: {OUTPUT_FILE}")


# ---------------------- CONFIG ---------------------- #

JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
MODEL_NAME = "bert-base-uncased"  # ou "econbert"
INPUT_FEATHER = os.path.join(JSTOR_RAW_DATA_PATH, f"nearest_neighbors_{MODEL_NAME.replace('/', '_')}.feather")

# ---------------------- LOAD DATA ---------------------- #

df = pd.read_feather(INPUT_FEATHER)
df['year'] = pd.to_numeric(df['year'], errors='coerce')
df = df.dropna(subset=['year'])
df['decade'] = (df['year'] // 10 * 10).astype(int)

# filter null neighbors

df = df[df['nearest_neighbors'].notna() & (df['nearest_neighbors'].str.len() > 0)]

# group by decade

decade_to_counter = {}

for decade, group in df.groupby('decade'):
    all_neighbors = [neighbor for neighbors in group['nearest_neighbors'] for neighbor in neighbors]
    decade_to_counter[decade] = Counter(all_neighbors)




# ---------------------- PLOT WORD CLOUDS ---------------------- #

n_decades = len(decade_to_counter)
n_cols = 3
n_rows = (n_decades + n_cols - 1) // n_cols

fig, axs = plt.subplots(n_rows, n_cols, figsize=(15, 5 * n_rows))

# flatten axes array
axs = axs.flatten()

for i, (decade, counter) in enumerate(sorted(decade_to_counter.items())):
    wc = WordCloud(width=900, height=600, background_color='white', colormap='tab10')
    wc.generate_from_frequencies(counter)

    axs[i].imshow(wc, interpolation='bilinear')
    axs[i].set_title(f"{decade}s", fontsize=16)
    axs[i].axis("off")

# Hide unused subplots
for j in range(i + 1, len(axs)):
    axs[j].axis("off")

plt.tight_layout(pad=2)  # espace entre les subplots
plt.suptitle("Top semantic neighbors per decade", fontsize=20)
plt.subplots_adjust(top=0.92)
plt.show()



# -------------------------- PLOT TOP 10 BAR CHARTS ---------------------- #

# remove 1880s decade if it exists
    
fig, axs = plt.subplots(n_rows, n_cols, figsize=(15, 4 * n_rows))
axs = axs.flatten()

for i, (decade, counter) in enumerate(sorted(decade_to_counter.items())):
    top10 = counter.most_common(10)
    words, counts = zip(*top10)

    axs[i].barh(words, counts)
    axs[i].invert_yaxis()  # pour que le mot le plus fréquent soit en haut
    axs[i].set_title(f"{decade}s", fontsize=14)
    axs[i].set_xlabel("Frequency")

# Hide unused subplots
for j in range(i + 1, len(axs)):
    axs[j].axis("off")

plt.tight_layout(pad=2)
plt.suptitle("Top 10 semantic neighbors per decade", fontsize=10)
plt.subplots_adjust(top=0.92)
plt.show()













