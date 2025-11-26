# noise_regex.py
import re
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

# ============================================================
# REGEX — organisées par catégories
# ============================================================

AFFILIATION_REGEX = r"(?i)e-mail:|email:|tel:|phone:|fax:|postal address:|zip code:|corresponding author|affiliation:|The authors are professor of economics|The author is professor of economics"
ACK_REGEX = r"(?i)we thank|the authors are grateful to|we are grateful to|we would like to thank|the authors thank|we are indebted to|the authors are indebted to"
HEADINGS_REGEX = r"(?i)^(copyright|©|issn|all rights reserved)"
REFERENCE_REGEX = r"(Quaterly of|Journal of|Review of Economic|Vol\.|doi:|doi\s|In press|Working Paper|manuscript submitted for publication)"

_aff_pat = re.compile(AFFILIATION_REGEX)
_ack_pat = re.compile(ACK_REGEX)
_head_pat = re.compile(HEADINGS_REGEX)
_ref_pat = re.compile(REFERENCE_REGEX)


def regex_guess(sentence: str):
    """
    Retourne :
    - 'affiliation'
    - 'ack'
    - 'header'
    - 'reference'
    ou None si aucun match.
    """

    if not isinstance(sentence, str) or len(sentence.strip()) == 0:
        return None

    s = sentence.strip()

    # ordre par spécificité
    if _aff_pat.search(s):
        return "affiliation"
    if _ack_pat.search(s):
        return "ack"
    if _head_pat.search(s):
        return "header"
    if _ref_pat.search(s):
        return "reference"

    return None



def get_flagged_sentences(df, centroids, thresholds):
    """
    df : dataframe avec colonne 'embedding'
    centroids : dict {cat: vector}
    thresholds : dict {cat: threshold}
    """

    CATS = list(centroids.keys())

    # embeddings matrix
    X = np.vstack(df["embedding"].values)

    # matrix des centroides
    centroid_matrix = np.vstack([centroids[c] for c in CATS])

    # cosine similarity entre les embeddings et l'ensemble des centroids pour chaque cats (shape = n_sentences x n_cats)
    scores = cosine_similarity(X, centroid_matrix)

    # on garde la cat avec le score (la colonne car axis=1) le plus élevé
    best_idx = scores.argmax(axis=1)
    
    # on ajoute les infos au df (same length que df = n_sentences)
    df["best_cat"] = [CATS[i] for i in best_idx]
    df["score"] = scores.max(axis=1)

    # for each row, get the threshold corresponding to the best_cat
    df["threshold"] = df["best_cat"].map(thresholds)

    # add a flagged column==True if score >= threshold
    df["flagged"] = df["score"] >= df["threshold"]

    df_removed = df[df["flagged"]].copy()

    return df_removed