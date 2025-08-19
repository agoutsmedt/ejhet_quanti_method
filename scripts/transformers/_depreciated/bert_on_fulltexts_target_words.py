# --------------------------- IMPORTS --------------------------- #

import os
import pandas as pd
import numpy as np
import torch
import tqdm

from transformers import BertTokenizer, BertModel, RobertaTokenizer, RobertaModel

# --------------------------- MODEL SELECTION --------------------------- #

# Path to local econBERT model
ECONBERT_PATH = "econbert/EconBERT_Model"

# Choose between: "econbert" (local) or "bert" (Hugging Face)
SELECTED_MODEL = "econbert"

# Define tokenizer/model loading logic
if SELECTED_MODEL == "econbert": 
    model_type = "roberta"
    model_name = "econbert"
    tokenizer_path = os.path.join(ECONBERT_PATH, "econbert_tokenizer")
    weights_path = os.path.join(ECONBERT_PATH, "econbert_weights")
elif SELECTED_MODEL == "bert":
    model_type = "bert"
    model_name = "bert-base-uncased"
else:
    raise ValueError("Unsupported model: choose either 'econbert' or 'bert'.")

LAYERS_TO_USE = [-4, -3, -2, -1]
BATCH_SIZE = 32

# --------------------------- PATHS --------------------------- #

try:
    import paths
    JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
except ImportError:
    JSTOR_RAW_DATA_PATH = "your/path/to/data"

INPUT_FILE = os.path.join(JSTOR_RAW_DATA_PATH, "paragraphs_with_target_word.parquet")
OUTPUT_FILE = os.path.join(JSTOR_RAW_DATA_PATH, f"embeddings_{model_name.replace('/', '_')}.feather")

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# --------------------------- LOAD DATA --------------------------- #

paragraphs = pd.read_parquet(INPUT_FILE)
print(f"✅ Loaded {len(paragraphs)} paragraphs.")

# --------------------------- LOAD MODEL --------------------------- #

if model_type == "bert":
    tokenizer = BertTokenizer.from_pretrained(model_name)
    model = BertModel.from_pretrained(model_name)
elif model_type == "roberta":
    tokenizer = RobertaTokenizer.from_pretrained(tokenizer_path)
    model = RobertaModel.from_pretrained(weights_path)
else:
    raise ValueError("Unsupported model type.")

model.to(device)
# model.eval()
print(f"✅ Model loaded on {device}")

# --------------------------- BATCH VECTORIZATION --------------------------- #

print(f"\n3️⃣  Vectorizing in batches (batch size = {BATCH_SIZE})...")

texts = paragraphs['window'].tolist()
targets = paragraphs['target_word'].tolist()
all_target_embeddings = []

range(0, 30, 5)


# Loop over paragraphs in batches
for i in tqdm.tqdm(range(0, len(paragraphs), BATCH_SIZE), desc="Vectorization"):
    # Get a batch of texts and target words
    batch_texts = texts[i:i + BATCH_SIZE]
    batch_targets = targets[i:i + BATCH_SIZE]

    # Tokenize the batch of texts into input IDs, attention masks, etc.
    inputs = tokenizer(batch_texts, padding=True, truncation=True, max_length=512, return_tensors="pt")
    inputs = {k: v.to(device) for k, v in inputs.items()}

    # Run the model to get hidden states from all layers (no gradients needed)
    with torch.no_grad():
        outputs = model(**inputs, output_hidden_states=True)

    # Hidden states is a tuple: one tensor per layer
    # Each tensor shape: (batch_size, text_length, hidden_size) = (B, L, 768)
    hidden_states = outputs.hidden_states

    # Process each text in the current batch
    for batch_idx, (text, target) in enumerate(zip(batch_texts, batch_targets)):
        
        # Get the input IDs for this text and convert to readable tokens
        input_ids = inputs['input_ids'][batch_idx]
        tokens = tokenizer.convert_ids_to_tokens(input_ids)

        # Tokenize the target word to see how it was split by the tokenizer
        target_tokenized = tokenizer.tokenize(target.lower())

        # Find the position(s) in the token list where the full target word appears
        matching_starts = [
            j for j in range(len(tokens) - len(target_tokenized) + 1)
            if tokens[j:j + len(target_tokenized)] == target_tokenized
        ]

        if matching_starts:
            # If multiple matches, use the one in the middle
            start_idx = matching_starts[len(matching_starts) // 2]
            token_indices = list(range(start_idx, start_idx + len(target_tokenized)))

            token_embeddings = []

            # Loop over each layer to extract embeddings
            for layer in LAYERS_TO_USE:
                layer_token_vectors = []

                # Extract the (768,) vector for each sub-token in the target word
                for idx in token_indices:
                    vec = hidden_states[layer][batch_idx, idx, :]  # → shape: (768,)
                    layer_token_vectors.append(vec)

                # Stack into a 2D tensor: shape = (num_tokens, 768)
                stacked = torch.stack(layer_token_vectors, dim=0)

                # Average across sub-tokens → gives one (768,) vector per layer
                avg_vector = stacked.mean(dim=0)

                # Save the averaged vector for this layer
                token_embeddings.append(avg_vector)

            # After processing all layers:
            # token_embeddings is a list of 4 vectors, each of shape (768,)
            # Concatenate them → shape becomes (768 × 4 = 3072,)
            concat_embedding = torch.cat(token_embeddings, dim=-1)

            # Convert to NumPy and detach from GPU for later storage
            all_target_embeddings.append(concat_embedding.detach().cpu().numpy())

        else:
            # If the target word couldn't be matched in the tokenized sentence
            print(f"❌ Target word '{target}' not found in tokens: {tokens}")
            all_target_embeddings.append(None)
            


# --------------------------- SAVE OUTPUT --------------------------- #

paragraphs = paragraphs.reset_index(drop=True)
paragraphs['bert_embedding_concat'] = all_target_embeddings

valid_embeddings = paragraphs['bert_embedding_concat'].notna().sum()
print(f"✅ Done. {valid_embeddings}/{len(paragraphs)} embeddings successfully generated.")

paragraphs.to_feather(OUTPUT_FILE)

print(f"✅ Saved to: {OUTPUT_FILE}")
