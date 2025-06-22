# --------------------------- IMPORTS --------------------------- #

import os
import pandas as pd
import pyreadr
import torch
import tqdm

from transformers import AutoTokenizer, AutoModel

# --------------------------- PARAMETERS --------------------------- #

# ---- paths ----
try:
    import paths
    JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
except ImportError:
    print("⚠️ The 'paths' module was not found.")
    JSTOR_RAW_DATA_PATH = "your/path/to/data"  # fallback to be manually updated

INPUT_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "paragraphs_with_target_word.rds")
OUTPUT_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "paragraphs_with_concat_embeddings_batch.feather")

# ---- model ----
# BERT_MODEL_NAME = "bert-base-uncased"  
BERT_MODEL_NAME = "climatebert/econbert"

LAYERS_TO_USE = [-4, -3, -2, -1]  # last 4 layers

# ---- batch size ----
BATCH_SIZE = 16

# --------------------------- LOAD DATA --------------------------- #

print("1️⃣  Loading data...")

result = pyreadr.read_r(INPUT_FILE)
paragraphs = result[None]

print(f"✅ Data loaded: {len(paragraphs)} paragraphs.")

# --------------------------- LOAD MODEL --------------------------- #

print("\n2️⃣  Loading BERT model...")

# download them locally first 
from huggingface_hub import snapshot_download
snapshot_download(repo_id="climatebert/econbert", local_dir="econbert", local_dir_use_symlinks=False)

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
tokenizer = AutoTokenizer.from_pretrained(BERT_MODEL_NAME)
model = AutoModel.from_pretrained(BERT_MODEL_NAME)
model.to(device)
model.eval()

print(f"✅ Model '{BERT_MODEL_NAME}' loaded on: {device}")

# --------------------------- VECTORIZATION --------------------------- #

print(f"\n3️⃣  Starting batch vectorization with batch size = {BATCH_SIZE}...")

all_target_embeddings = []

# To test on a small sample, uncomment below

texts = paragraphs['windows'].tolist()
targets = paragraphs['target_word'].tolist()

for i in tqdm.tqdm(range(0, len(paragraphs), BATCH_SIZE), desc="Vectorization"):
    batch_texts = texts [i:i + BATCH_SIZE]
    batch_targets = targets[i:i + BATCH_SIZE]

    # Tokenization with offset mappings
    inputs = tokenizer(
        batch_texts,
        padding=True,
        truncation=True,
        max_length=512,
        return_tensors="pt",
        return_offsets_mapping=True
    )

    # Offset mappings are not needed here
    offsets = inputs.pop("offset_mapping")
    inputs = {k: v.to(device) for k, v in inputs.items()}

    with torch.no_grad():
        outputs = model(**inputs, output_hidden_states=True)

    hidden_states = outputs.hidden_states  # tuple: (layer, batch, seq_len, hidden_dim)

    for batch_idx, (text, target) in enumerate(zip(batch_texts, batch_targets)):
        input_ids = inputs['input_ids'][batch_idx]
        tokens = tokenizer.convert_ids_to_tokens(input_ids)

        # Tokenize the target word manually to get subword components
        target_tokenized = tokenizer.tokenize(target.lower())
        matching_starts = []

        # Find all positions where the target subword sequence appears
        for j in range(len(tokens) - len(target_tokenized) + 1):
            if tokens[j:j + len(target_tokenized)] == target_tokenized:
                matching_starts.append(j)

        if matching_starts:
          
            # Use the middle occurrence (assumes it's the one intended)
            start_idx = matching_starts[len(matching_starts) // 2]
            token_indices = list(range(start_idx, start_idx + len(target_tokenized)))

            # Extract and average hidden states for each layer and token
            token_embeddings = [
                torch.cat([hidden_states[layer][batch_idx, idx, :] for idx in token_indices], dim=0)
                for layer in LAYERS_TO_USE
            ]
            
            token_embeddings = [emb.view(len(token_indices), -1).mean(dim=0) for emb in token_embeddings]

            # Concatenate representations across the selected layers
            concat_embedding = torch.cat(token_embeddings, dim=-1)

            # Move to CPU and convert to numpy
            all_target_embeddings.append(concat_embedding.detach().cpu().numpy())
        else:
            # If the target word wasn't found in tokenized form, append None
            print(f"❌ Target word '{target}' not found in: {tokens}")
            all_target_embeddings.append(None)

# --------------------------- SAVE OUTPUT --------------------------- #

print("\n4️⃣  Saving results...")

paragraphs = paragraphs.reset_index(drop=True)
paragraphs['bert_embedding_concat'] = all_target_embeddings
valid_embeddings = paragraphs['bert_embedding_concat'].notna().sum()

print(f"✅ Extraction complete. {valid_embeddings}/{len(paragraphs)} embeddings were successfully generated.")

paragraphs.to_feather(OUTPUT_FILE)
print(f" ✅  Results saved to: {OUTPUT_FILE}")
