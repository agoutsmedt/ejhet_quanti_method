import numpy as np
import pandas as pd
from tqdm import tqdm
from sentence_transformers import SentenceTransformer
import re
import torch
import os
import paths
import gc


# ============================================================
# REGEX — organisées par catégories
# ============================================================
AFFILIATION_REGEX = r"\b(Dept|Faculty|Institute|University) of [A-Z][a-zA-Z]+|\b[A-Z][a-zA-Z]+ University\b"

ACK_REGEX = r"(?i)we thank|the authors are grateful to|we are grateful to|we would like to thank|the authors thank|we are indebted to|the authors are indebted to"

FUNDING_REGEX = r"(?i)this research was supported by|funded by|supported by|financial support from|grant from|funding from|sponsored by"

HEADINGS_REGEX = (r"(?i)^(copyright|©|issn|all rights reserved)")

REFERENCE_REGEX = r"(?i)(quaterly of|journal of|review of economic|vol\.|No\.|doi:|doi\s|published by|in press|working paper|unpublished|manuscript submitted for publication)"

_aff_pat = re.compile(AFFILIATION_REGEX)
_ack_pat = re.compile(ACK_REGEX)
_head_pat = re.compile(HEADINGS_REGEX)
_ref_pat = re.compile(REFERENCE_REGEX)


# ============================================================
# FONCTION DE DÉTECTION DE PHRASES BRUITÉES
# ============================================================

def detect_noise_category(sentence: str):
    """
    Retourne :
    - 'affiliation'
    - 'author'
    - 'ack'
    - 'header'
    - 'reference'
    ou None si aucun match.
    """

    if not isinstance(sentence, str) or len(sentence.strip()) == 0:
        return None

    s = sentence.strip()

    # Ordre par "spécificité"

    if _aff_pat.search(s):
        return "affiliation"

    if _ack_pat.search(s):
        return "ack"

    if _head_pat.search(s):
        return "header"

    if _ref_pat.search(s):
        return "reference"

    return None

# ======================================================
# Online centroid class
# ======================================================

# the OnlineCentroid class allows us to compute the centroid of vectors in an online fashion
# instead of storing all vectors in memory and computing the centroid at the end
# we just keep track of the sum of vectors and the count of vectors seen so far
# at the end, we divide the sum by the count to get the centroid 

class OnlineCentroid:
    # initialize with dimension of vectors: 768 dim with 0 values and 0 count
    def __init__(self, dim):
        self.sum_vec = np.zeros(dim, dtype=np.float32)
        self.count = 0

    # update 
    def update(self, arr):
        
        # prevent empty arrays
        if arr is None or len(arr) == 0:
            return

        # sum along axis 0 (sum of each column)
        self.sum_vec += arr.sum(axis=0)
        # increment count by number of rows in arr
        self.count += arr.shape[0]

    def finalize(self):
        # precaution for division by zero 
        if self.count == 0:
            return None
        # compute centroid
        return self.sum_vec / self.count


# ======================================================
# INIT 
# ======================================================


# init counts (we are going to count how many sentences are detected per category)
CATS = ["affiliation", "ack", "header", "reference"]
counts = {cat: 0 for cat in CATS}

# init centroids
emb_dim = 768  # dimension des embeddings
centroids = {cat: OnlineCentroid(emb_dim) for cat in CATS}


# ======================================================
# LOOP SUR LE DOSSIER
# ======================================================

VECTORS_FOLDERS = paths.econ_embeddings_data_path
JSTOR_VECTORS_SUBFOLDER = os.path.join(VECTORS_FOLDERS, "istex_vectors") 
OUTPUT_FOLDER = os.path.join(paths.ejhet_project_data_path) 

files = [f for f in os.listdir(JSTOR_VECTORS_SUBFOLDER) if f.endswith(".feather")]

for fname in tqdm(files, desc="Processing vector files"):
    
    # read data
    path = os.path.join(JSTOR_VECTORS_SUBFOLDER, fname)
    df = pd.read_feather(path)

    # extract sentences
    sentences = df["sentence"].astype(str).tolist()
    # extract precomputed embeddings
    embs = np.vstack(df["embedding"].values)

    # delete df to save memory
    del df
    gc.collect()
    
    # init a bucket per category to store sentences
    bucket = {cat: [] for cat in CATS}

    # categorize sentences (none if no noise detected, else we store its embedding in the bucket)
    for sentence, emb in zip(sentences, embs):
        cat = detect_noise_category(sentence)
        if cat is not None:
            bucket[cat].append(emb)

    # hand inspection
    # rows = []
    # for sentence, emb in zip(sentences, embs):
    #     cat = detect_noise_category(sentence)
    #     if cat is not None:
    #         rows.append({
    #             "sentence": sentence,
    #             "category": cat,
    #             "embedding": emb
    #         })

    # inspection = pd.DataFrame(rows)


    # now update centroids using precomputed embeddings
    for cat in CATS:

        # skip empty buckets
        if len(bucket[cat]) == 0:
            continue
        
        # update centroid and count
        arr = np.vstack(bucket[cat])
        centroids[cat].update(arr)
        counts[cat] += arr.shape[0]



# ======================================================
# SAVE
# ======================================================

rows = []

for cat in CATS:
    vec = centroids[cat].finalize()
    if vec is not None:
        rows.append({"cat": cat, **{f"dim_{i}": v for i, v in enumerate(vec)}})
    else:
        print(f"No samples for category: {cat}")

# create DataFrame
df = pd.DataFrame(rows)

# save to parquet
out = os.path.join(OUTPUT_FOLDER, "noisy_centroids.parquet")
df.to_parquet(out, index=False)