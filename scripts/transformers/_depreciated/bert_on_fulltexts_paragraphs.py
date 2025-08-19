import os
import pandas as pd
import torch
import tqdm
import numpy as np
import gc  # pour libérer la RAM
from transformers import BertTokenizer, BertModel, RobertaTokenizer, RobertaModel

# --------------------------- MODEL CONFIG --------------------------- #

ECONBERT_PATH = "econbert/EconBERT_Model"
SELECTED_MODEL = "bert"  # "bert" or "econbert"

if SELECTED_MODEL == "econbert":
    model_type = "roberta"
    model_name = "econbert"
    tokenizer_path = os.path.join(ECONBERT_PATH, "econbert_tokenizer")
    weights_path = os.path.join(ECONBERT_PATH, "econbert_weights")
elif SELECTED_MODEL == "bert":
    model_type = "bert"
    model_name = "bert-base-uncased"
else:
    raise ValueError("Unsupported model")

LAYERS_TO_USE = [-4, -3, -2, -1]
BATCH_SIZE = 8
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# --------------------------- PATHS --------------------------- #

import paths
JSTOR_RAW_DATA_PATH = paths.jstor_raw_data

INPUT_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "paragraphs_with_target_word.parquet")
OUTPUT_FOLDER = os.path.join(JSTOR_RAW_DATA_PATH, "paragraphs_embeddings")
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

# --------------------------- LOAD MODEL --------------------------- #

if model_type == "bert":
    tokenizer = BertTokenizer.from_pretrained(model_name)
    model = BertModel.from_pretrained(model_name)
elif model_type == "roberta":
    tokenizer = RobertaTokenizer.from_pretrained(tokenizer_path)
    model = RobertaModel.from_pretrained(weights_path)

model.to(device)
model.eval()
print(f"✅ Model loaded on {device}")

# --------------------------- LOAD DATA --------------------------- #

df = pd.read_parquet(INPUT_FILE)
df['id'] = df['id'].astype(str)
df.rename(columns={'publication_year': 'year'}, inplace=True)
df['year'] = df['year'].astype(str)
years = df['year'].dropna().unique()
years.sort()

# --------------------------- CHECK EXISTING EMBEDDINGS --------------------------- #

existing_files = set(
    fname for fname in os.listdir(OUTPUT_FOLDER)
    if fname.startswith("embeddings_") and fname.endswith(".npz")
)

existing_years = set(
    fname.replace("embeddings_", "").replace(".npz", "") for fname in existing_files
)

years_to_process = [str(y) for y in years if str(y) not in existing_years]

# --------------------------- PROCESS YEAR BY YEAR --------------------------- #

for year in tqdm.tqdm(years_to_process, desc="Processing years"):

    df_year = df[df['year'] == year]
    if df_year.empty:
        continue

    texts = df_year['window'].tolist()
    ids = df_year['id'].tolist()

    all_embeddings = []
    all_tokens = []
    all_ids = []

    for i in tqdm.tqdm(range(0, len(texts), BATCH_SIZE), desc=f"Encoding {year}", leave=False):
        batch_texts = texts[i:i + BATCH_SIZE]
        batch_ids = ids[i:i + BATCH_SIZE]

        inputs = tokenizer(batch_texts, padding=True, truncation=True, max_length=512, return_tensors="pt")
        inputs = {k: v.to(device) for k, v in inputs.items()}

        with torch.no_grad():
            outputs = model(**inputs, output_hidden_states=True)
            hidden_states = outputs.hidden_states

        for batch_idx, pid in enumerate(batch_ids):
            input_ids = inputs['input_ids'][batch_idx]
            tokens = tokenizer.convert_ids_to_tokens(input_ids)

            token_embeddings = []
            for token_idx in range(len(tokens)):
                layers = [hidden_states[layer][batch_idx, token_idx, :] for layer in LAYERS_TO_USE]
                avg = torch.stack(layers).mean(dim=0).detach().cpu().numpy().astype(np.float32)
                token_embeddings.append(avg)

            all_embeddings.append(np.stack(token_embeddings))  # (T, 768)
            all_tokens.append(tokens)
            all_ids.append(pid)

    # --------------------------- SAVE --------------------------- #

    output_path = os.path.join(OUTPUT_FOLDER, f"embeddings_{year}.npz")
    np.savez_compressed(
        output_path,
        embeddings=np.array(all_embeddings, dtype=object),
        tokens=np.array(all_tokens, dtype=object),
        ids=np.array(all_ids, dtype=object)
    )
    print(f"✅ Saved embeddings for year {year} to {output_path}")

    # --------------------------- CLEANUP --------------------------- #

    del all_embeddings, all_tokens, all_ids, df_year
    gc.collect()
