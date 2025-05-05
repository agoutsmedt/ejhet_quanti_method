# --------------------------- IMPORTS --------------------------- #
import paths 
import pyarrow.feather as feather

import pyreadr
import os
import pandas as pd
import tqdm
import numpy

import transformers
from transformers import AutoTokenizer, AutoModel
import torch

# --------------------------- PARAMÈTRES --------------------------- #

# Chemin d'accès
file_path = os.path.join(paths.jstor_raw_data, "paragraphs_with_target_word.rds")

# Modèle BERT
bert_model_name = 'bert-base-uncased'
layers_to_use = [-4, -3, -2, -1]  # Dernières 4 couches

# Liste des variations du mot cible
target_words = ["rational", "irrational", "rationality", "irrationality"]


# --------------------------- DATA  --------------------------- #

# Lire le .rds
result = pyreadr.read_r(file_path)
paragraphs = result[None]

# ---------------------- BERT MODEL --------------------------- #

# Détecter GPU (cuda) ou fallback sur CPU
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"✅ Modèle BERT chargé sur : {device}")

# Charger modèle et tokenizer
tokenizer = AutoTokenizer.from_pretrained(bert_model_name)
model = AutoModel.from_pretrained(bert_model_name)
model.to(device)  # send to gpu/cpu 
model.eval()


# ----------------------- VECTORISATION ----------------------- #

# init loop
target_embeddings = []
texts = paragraphs['windows'].tolist()
target_tokens = paragraphs['target_word'].tolist()

for text, target in tqdm.tqdm(zip(texts, target_tokens), total=len(texts)):
    with torch.no_grad():
        # Tokenisation avec offsets
        inputs = tokenizer(text, return_tensors="pt", truncation=True, max_length=512, return_offsets_mapping=True)
        
        # On enlève les offsets pour passer dans BERT "[CLS] [SEP]"
        offsets = inputs.pop("offset_mapping")

        # Passage dans BERT
        outputs = model(**inputs, output_hidden_states=True)
        
        # On récupère les hidden states et on sélectionne les 4 dernières couches 
        hidden_states = outputs.hidden_states
        selected_layers = [hidden_states[i] for i in layers_to_use]  # shape (4, 1, seq_len, hidden_dim)

        # Thomas: la suite est un peu tricky. 
        # Bert sépare certains mots en sous-tokens
        # Par exemple, "rational" en "rational" et "ity"
        # Il faut donc trouver la séquence de tokens qui correspond au mot cible
        
        # On récupère les tokens du paragraphe en question
        tokens = tokenizer.convert_ids_to_tokens(inputs['input_ids'][0])

        # On tokenise à la main le mot cible 
        target_tokenized = tokenizer.tokenize(target.lower())

        # Chercher la séquence de tokens correspondante
        matching_starts = []
        # si le mot cible a X tokens, on cherche la même séquence de X tokens ["rational", "ity"] == ["rational", "ity"]
        for i in range(len(tokens) - len(target_tokenized) + 1):
            if tokens[i:i+len(target_tokenized)] == target_tokenized:
                matching_starts.append(i)
        
        # Si on a trouvé des occurrences du mot cible
        if matching_starts:
            # Prendre l'occurrence du milieu 
            # Le paragraphe peut contenir plusieurs fois le mot cible 
            # Mais celui du milieu est toujours le bon 
            start_idx = matching_starts[len(matching_starts) // 2]

            # Indices de tous les sous-tokens du mot cible
            token_indices = list(range(start_idx, start_idx + len(target_tokenized)))

            # Extraire les embeddings pour tous les sous-tokens et toutes les couches
            token_embeddings = [torch.cat([layer[0, idx, :] for idx in token_indices], dim=0) for layer in selected_layers]

            # Moyenne sur tous les sous-tokens pour chaque couche
            token_embeddings = [embedding.view(len(token_indices), -1).mean(dim=0) for embedding in token_embeddings]

            # Puis concaténer entre les couches
            concat_embedding = torch.cat(token_embeddings, dim=-1)  # shape (hidden_dim * 4)

            # Convertir en numpy
            target_embeddings.append(concat_embedding.detach().cpu().numpy())

        else:
            target_embeddings.append(None)

# --------------------------- SAUVEGARDE --------------------------- #

paragraphs['bert_embedding_concat'] = target_embeddings

# save 
feather.write_feather(paragraphs, os.path.join(paths.jstor_raw_data, "paragraphs_with_concat_embeddings.feather"))
