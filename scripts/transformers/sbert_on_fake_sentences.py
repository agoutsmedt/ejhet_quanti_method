import os
import pandas as pd
import numpy as np
import torch
from sentence_transformers import SentenceTransformer
from sklearn.metrics.pairwise import cosine_similarity

# ---------------- PARAMETERS ---------------- #
JSTOR_RAW_DATA_PATH = paths.jstor_raw_data
OUTPUT_DIR = os.path.join(JSTOR_RAW_DATA_PATH, "sentences_embeddings")
SENTENCE_BERT_MODEL = "all-mpnet-base-v2"
YEARS = [1925, 1950, 1975, 2000]
TOP_K = 5

# ---------------- LOAD MODEL ---------------- #
model = SentenceTransformer(SENTENCE_BERT_MODEL)
device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device)

# ---------------- SINGLE QUERY RATIONALITY ---------------- #

query = "Economic agents are supposed to be rational."

query_emb = model.encode([query], convert_to_numpy=True)[0]

def topk_for_year(year, top_k=5):
    """Retourne une liste de dicts (rank, similarity, sentence, year) pour l'année donnée."""
    feather_path = os.path.join(OUTPUT_DIR, f"sentence_embeddings_{year}.feather")
    if not os.path.exists(feather_path):
        print(f"⚠️ Fichier introuvable pour {year}: {feather_path}")
        return []

    df = pd.read_feather(feather_path)

    # Empile tous les embeddings dans une matrice (n_phrases x dim)
    X = np.vstack(df["embedding"].values)

    # Similarités cosinus entre la query et toutes les phrases de l'année
    sims = cosine_similarity([query_emb], X)[0]

    # Indices des top_k plus grandes similarités
    top_idx = np.argpartition(sims, -top_k)[-top_k:]

    # Trie décroissant
    top_idx = top_idx[np.argsort(-sims[top_idx])]

    rows = []
    for rank, j in enumerate(top_idx, 1):
        rows.append({
            "year": year,
            "rank": rank,
            "similarity": float(sims[j]),
            "sentence": df.iloc[j]["sentence"]
        })
    return rows

# ---------------- RUN & AGGREGATE ---------------- #
all_rows = []
for y in YEARS:
    all_rows.extend(topk_for_year(y, TOP_K))

results_df = pd.DataFrame(all_rows, columns=["year", "rank", "similarity", "sentence"])

# ---------------- DISPLAY ---------------- #
print(results_df)

# (optionnel) Sauvegarde CSV
# results_df.to_csv(os.path.join(OUTPUT_DIR, "top5_rationality_1950_1975_2000.csv"), index=False)


# FIND REFERENCES SENTENCES 

import random, numpy as np

# ---------- config ----------
def generate_fake_references(years=range(1900, 2021), n_per_year=5, seed=42):
    random.seed(seed)

    surnames = [
        "Arrow","Debreu","Samuelson","Hicks","Edgeworth","Pareto","Marshall","Pigou","Hotelling",
        "von Neumann","Morgenstern","Nash","Kaldor","Keynes","Hayek","Lucas","Sargent","Prescott",
        "Stiglitz","Akerlof","Spence","Maskin","Tirole","Milgrom","Roberts","Myerson","Kreps",
        "Wilson","Rubinstein","Mas-Colell","Whinston","Green","Townsend","Kiyotaki","Moore",
        "Hart","Holmström","Acemoglu","Autor","Banerjee","Duflo","Phelps","Diamond","Mortensen"
    ]
    initials = [f"{c}." for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
    and_tokens = [" & ", " and "]

    # journal name + (abbr, start_year) to respect plausibility by period
    journals = [
        ("The Economic Journal", "Econ. J.", 1891),
        ("Journal of Political Economy", "J. Polit. Econ.", 1892),
        ("Quarterly Journal of Economics", "Q. J. Econ.", 1886),
        ("American Economic Review", "Am. Econ. Rev.", 1911),
        ("Review of Economics and Statistics", "Rev. Econ. Stat.", 1919),
        ("Econometrica", "Econometrica", 1933),
        ("Review of Economic Studies", "Rev. Econ. Stud.", 1933),
        ("Journal of Economic Theory", "J. Econ. Theory", 1969),
        ("Journal of Econometrics", "J. Econometrics", 1973),
        ("Journal of Monetary Economics", "J. Monet. Econ.", 1975),
        ("RAND Journal of Economics", "RAND J. Econ.", 1984),
        ("Games and Economic Behavior", "Games Econ. Behav.", 1993),
    ]

    # title fragments
    topics = [
        "rational expectations","general equilibrium","market design","matching markets",
        "dynamic programming","contract theory","mechanism design","search frictions",
        "incomplete markets","information asymmetry","moral hazard","adverse selection",
        "price dispersion","auctions","monetary policy","growth and innovation",
        "strategic complementarities","coordination failures","risk sharing","asset pricing",
        "intertemporal choice","network formation","learning in games","bounded rationality",
        "welfare theorems","Markov perfect equilibrium","Bayesian persuasion","commitment"
    ]
    verbs = [
        "A model of","Foundations of","On","Notes on","An empirical test of","A theory of",
        "Equilibrium with","Comparative statics in","Identifiability in","Efficiency of",
        "Optimal","Existence and uniqueness of","Stability of","Welfare analysis of",
        "Estimation of","Computation of","Identification under","Dynamics of","Robustness of"
    ]

    def make_authors():
        k = random.choices([1,2,3,4], weights=[0.4,0.35,0.2,0.05])[0]
        names = []
        for _ in range(k):
            s = random.choice(surnames)
            ini = random.choice(initials)
            # parfois deux initiales
            if random.random() < 0.25:
                ini = ini + " " + random.choice(initials)
            names.append(f"{s}, {ini}")
        if k == 1: 
            return names[0]
        return and_tokens[random.randrange(len(and_tokens))].join(names)

    def make_title():
        v = random.choice(verbs)
        t = random.choice(topics)
        # guillemets variables + ponctuation
        left, right = random.choice([('"','"'), ('“','”')])
        end = random.choice([".", "", ""])
        return f'{left}{v} {t}{end}{right}'

    def pick_journal(y):
        cand = [(full, abbr, start) for (full, abbr, start) in journals if start <= y]
        full, abbr, _ = random.choice(cand)
        # parfois abréviation
        use = full if random.random() < 0.65 else abbr
        return use

    def make_pages():
        a = random.randint(1, 450)
        b = a + random.randint(5, 40)
        dash = random.choice(["–", "-"])
        return f"{a}{dash}{b}"

    def make_vol_issue(y):
        # volumes grossièrement plausibles croissant avec le temps
        base = 5 + (y - 1900) // 3
        vol = base + random.randint(-3, 3)
        vol = max(1, vol)
        issue = random.randint(1, 4)
        return vol, issue

    def maybe_doi_or_jstor():
        r = random.random()
        if r < 0.15:
            return f" doi:10.{random.randint(1000,9999)}/{random.randint(100000,999999)}"
        if r < 0.30:
            return f" Stable URL: www.jstor.org/stable/{random.randint(100000,999999)}"
        return ""

    # styling templates
    def format_entry(style, authors, y, title, journal, vol, issue, pages):
        # nettoyer les guillemets éventuels du titre
        tclean = title.strip('“”"')

        if style == "apa":
            return f"{authors} ({y}). {title} {journal}, {vol}({issue}), {pages}."
        if style == "harvard":
            return f"{authors} {y}, {title} {journal} {vol}({issue}), pp. {pages}."
        if style == "mla":
            return f'{authors}. "{tclean}" {journal} {vol}.{issue} ({y}): {pages}.'
        if style == "chicago":
            return f"{authors}. {y}. {title} {journal} {vol}, no. {issue}: {pages}."
        if style == "ieee":
            return f'[{random.randint(1,999)}] {authors.split(",")[0]} et al., "{tclean}", {journal}, vol. {vol}, no. {issue}, pp. {pages}, {y}.'
        if style == "compact":
            return f"{authors} ({y}) {title} {journal} {vol}({issue}):{pages}."
        return f"{authors} ({y}). {title} {journal}, {vol}({issue}), {pages}."


    styles = ["apa","harvard","mla","chicago","ieee","compact"]

    out = []
    for y in years:
        for _ in range(n_per_year):
            authors = make_authors()
            title = make_title()
            journal = pick_journal(y)
            vol, issue = make_vol_issue(y)
            pages = make_pages()
            style = random.choice(styles)
            entry = format_entry(style, authors, y, title, journal, vol, issue, pages)
            # petites variations cosmétiques fin de chaîne
            entry += maybe_doi_or_jstor()
            out.append(entry)
    return out

# ----- génère des fausses refs -----
fake_refs = generate_fake_references(n_per_year=6, seed=123)  # ajuste n_per_year selon besoin

embs = model.encode(fake_refs, convert_to_numpy=True, normalize_embeddings=False)

query_emb = embs.mean(axis=0)

# ----- recherche les plus proches -----
all_rows = []
for y in YEARS:
    all_rows.extend(topk_for_year(y, 100))

results_df = pd.DataFrame(all_rows, columns=["year", "rank", "similarity", "sentence"])

# ---------------- DISPLAY ---------------- #
print(results_df)

