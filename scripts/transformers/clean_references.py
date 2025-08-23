import os, random
import numpy as np
import pandas as pd
import torch
from sentence_transformers import SentenceTransformer
import tqdm 

import pyarrow.feather as pf
import numpy as np

import pyarrow.feather as pf

# ---------------- PARAMS ---------------- #
JSTOR_RAW_DATA_PATH = paths.jstor_raw_data  # déjà défini chez toi
OUTPUT_DIR = os.path.join(JSTOR_RAW_DATA_PATH, "sentences_embeddings")
SENTENCE_BERT_MODEL = "all-mpnet-base-v2"

# ---------------- MODEL ---------------- #
model = SentenceTransformer(SENTENCE_BERT_MODEL)
device = "cuda" if torch.cuda.is_available() else "cpu"
model.to(device)

# ---------------- Fake references ---------------- #


# 1) TES JOURNAUX UNIQUEMENT
MY_JOURNALS = [
    "The Quarterly Journal of Economics","The Economic Journal","Journal of Political Economy",
    "The American Economic Review","Weltwirtschaftliches Archiv","The Review of Economics and Statistics",
    "Journal of Farm Economics","Economica","Economic Geography",
    "The Journal of Land & Public Utility Economics","The Economic History Review",
    "Zeitschrift für Nationalökonomie / Journal of Economics","Southern Economic Journal","Econometrica",
    "The Review of Economic Studies","The Canadian Journal of Economics and Political Science / Revue canadienne d'Economique et de Science politique",
    "Oxford Economic Papers","The Journal of Economic History","The American Journal of Economics and Sociology",
    "The Journal of Finance","Land Economics","Zeitschrift für die gesamte Staatswissenschaft / Journal of Institutional and Theoretical Economics",
    "Jahrbücher für Nationalökonomie und Statistik / Journal of Economics and Statistics",
    "FinanzArchiv / Public Finance Analysis","Economic Development and Cultural Change",
    "The Journal of Industrial Economics","Indian Economic Review","The Journal of Law & Economics",
    "National Institute Economic Review","Giornale degli Economisti e Annali di Economia",
    "International Economic Review","The American Economist","Illinois Agricultural Economics",
    "Eastern European Economics","Business Economics","The Swedish Journal of Economics","Acta Oeconomica",
    "Recherches Économiques de Louvain / Louvain Economic Review","Journal of Transport Economics and Policy",
    "Journal of Economic Issues","American Journal of Agricultural Economics",
    "The Canadian Journal of Economics / Revue canadienne d'Economique","Public Choice",
    "The Journal of Economic Education","Journal of Money, Credit and Banking","Journal of Economic Literature",
    "Brookings Papers on Economic Activity","Eastern Economic Journal","The Bangladesh Development Studies",
    "International Journal of Transport Economics / Rivista internazionale di economia dei trasporti",
    "Revue économique","The Scandinavian Journal of Economics","Cambridge Journal of Economics",
    "Revue d'économie politique","Western Journal of Agricultural Economics","Journal of Cultural Economics",
    "Annales de l'inséé","Journal of Post Keynesian Economics","North Central Journal of Agricultural Economics",
    "Fiscal Studies","The Energy Journal","Journal of Labor Economics","The RAND Journal of Economics",
    "ASEAN Economic Bulletin","Review of Industrial Organization","Economic Policy",
    "Oxford Review of Economic Policy","Econometric Theory",
    "Cahiers d'économie politique / Papers in Political Economy",
    "Journal of Law, Economics, & Organization","Annales d'Économie et de Statistique",
    "Journal of Applied Econometrics","NBER Macroeconomics Annual","The World Bank Economic Review",
    "Journal of Institutional and Theoretical Economics (JITE) / Zeitschrift für die gesamte Staatswissenschaft",
    "Journal of Economics","The Journal of Economic Perspectives","International Journal of Political Economy",
    "Journal of Forensic Economics","Journal of Population Economics","Review of Agricultural Economics",
    "Economic Theory","Journal of Economic Integration","Histoire, Économie et Société","History of Economic Ideas",
    "Review of International Political Economy","Jahrbuch für Wirtschaftswissenschaften / Review of Economics",
    "Journal of Economic Growth","Environment and Development Economics","European Review of Economic History",
    "The Econometrics Journal","Journal of Economic Geography","The European Journal of Health Economics",
    "Journal of the European Economic Association","Review of World Economics / Weltwirtschaftliches Archiv",
    "American Economic Journal: Economic Policy","American Economic Journal: Applied Economics",
    "American Economic Journal: Macroeconomics","American Economic Journal: Microeconomics",
    "Annals of Economics and Statistics","IMF Economic Review","Applied Economic Perspectives and Policy",
    "American Journal of Economics and Sociology","Journal of Southeast Asian Economies","AEA Papers and Proceedings"
]

# 2) Abréviation naïve (heuristique)
STOP = {"the","of","and","&","/","for","in","de","d'","du","la","le","et"}
ABBR = {
    "journal":"J.","journals":"J.","review":"Rev.","reviews":"Rev.","economics":"Econ.","economic":"Econ.",
    "économie":"Écon.","économique":"Écon.","economique":"Écon.","economie":"Écon.",
    "american":"Am.","european":"Eur.","quarterly":"Q.","studies":"Stud.","statistics":"Stat.",
    "history":"Hist.","historical":"Hist.","monetary":"Monet.","political":"Polit.","association":"Assoc.",
    "international":"Int.","transport":"Transp.","world":"World","bank":"Bank","applied":"Appl.","policy":"Policy",
    "annals":"Ann.","annales":"Ann.","sociology":"Sociol.","société":"Soc.","géographie":"Géogr.","geography":"Geogr."
}

def make_abbr(name: str) -> str:
    toks = re.split(r"[ \-/&]+", name.strip())
    out = []
    for w in toks:
        wl = w.lower()
        if not wl or wl in STOP:
            continue
        if wl in ABBR:
            out.append(ABBR[wl])
        else:
            # par défaut: 1–4 lettres + point (préserve diacritiques)
            core = wl[:4].capitalize()
            out.append(core + ".")
    return " ".join(out) if out else name

# 3) Génération de fausses références — UNIQUEMENT tes journaux
def generate_fake_references_from_list(
    years=range(1900, 2021),
    n_per_year=6,
    seed=123,
    journals_list=MY_JOURNALS,
    abbr_prob=0.5,
    include_headers=True):

    random.seed(seed)

    surnames = ["Arrow","Debreu","Samuelson","Hicks","Edgeworth","Pareto","Marshall","Pigou","Hotelling",
                "von Neumann","Morgenstern","Nash","Kaldor","Keynes","Hayek","Lucas","Sargent","Prescott",
                "Stiglitz","Akerlof","Spence","Maskin","Tirole","Milgrom","Roberts","Myerson","Kreps",
                "Wilson","Rubinstein","Mas-Colell","Whinston","Green","Townsend","Kiyotaki","Moore",
                "Hart","Holmström","Acemoglu","Autor","Banerjee","Duflo","Phelps","Diamond","Mortensen"]
    initials = [f"{c}." for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]
    and_tokens = [" & ", " and "]

    topics = ["rational expectations","general equilibrium","market design","matching markets",
              "dynamic programming","contract theory","mechanism design","search frictions",
              "incomplete markets","information asymmetry","moral hazard","adverse selection",
              "price dispersion","auctions","monetary policy","growth and innovation",
              "strategic complementarities","coordination failures","risk sharing","asset pricing",
              "intertemporal choice","network formation","learning in games","bounded rationality",
              "welfare theorems","Markov perfect equilibrium","Bayesian persuasion","commitment"]
    verbs = ["A model of","Foundations of","On","Notes on","An empirical test of","A theory of",
             "Equilibrium with","Comparative statics in","Identifiability in","Efficiency of","Optimal",
             "Existence and uniqueness of","Stability of","Welfare analysis of","Estimation of","Computation of",
             "Identification under","Dynamics of","Robustness of"]
    styles = ["apa","harvard","mla","chicago","ieee","compact"]

    def make_authors():
        k = random.choices([1,2,3,4], weights=[0.4,0.35,0.2,0.05])[0]
        names=[]
        for _ in range(k):
            s = random.choice(surnames)
            ini = random.choice(initials)
            if random.random() < 0.25:
                ini = ini + " " + random.choice(initials)
            names.append(f"{s}, {ini}")
        return names[0] if k==1 else and_tokens[random.randrange(len(and_tokens))].join(names)

    def make_title():
        v = random.choice(verbs); t = random.choice(topics)
        left,right = random.choice([('"','"'),('“','”')]); end = random.choice([".","",""])
        return f'{left}{v} {t}{end}{right}'

    def pick_journal():
        full = random.choice(journals_list)
        return make_abbr(full) if random.random() < abbr_prob else full

    def make_pages():
        a = random.randint(1,450); b = a + random.randint(5,40); dash = random.choice(["–","-"])
        return f"{a}{dash}{b}"

    def make_vol_issue(y):
        # volume grossièrement croissant dans le temps (mais l'ANNÉE elle-même = y passé à la fonction)
        base = 5 + (y-1900)//3
        vol = max(1, base + random.randint(-3,3))
        issue = random.randint(1,4)
        return vol, issue

    def maybe_doi_or_jstor():
        r = random.random()
        if r<0.15: return f" doi:10.{random.randint(1000,9999)}/{random.randint(100000,999999)}"
        if r<0.30: return f" Stable URL: www.jstor.org/stable/{random.randint(100000,999999)}"
        return ""

    def format_entry(style, authors, y, title, journal, vol, issue, pages):
        tclean = title.strip('“”"')
        if style=="apa":     return f"{authors} ({y}). {title} {journal}, {vol}({issue}), {pages}."
        if style=="harvard": return f"{authors} {y}, {title} {journal} {vol}({issue}), pp. {pages}."
        if style=="mla":     return f'{authors}. "{tclean}" {journal} {vol}.{issue} ({y}): {pages}.'
        if style=="chicago": return f"{authors}. {y}. {title} {journal} {vol}, no. {issue}: {pages}."
        if style=="ieee":    return f'[{random.randint(1,999)}] {authors.split(",")[0]} et al., "{tclean}", {journal}, vol. {vol}, no. {issue}, pp. {pages}, {y}.'
        if style=="compact": return f"{authors} ({y}) {title} {journal} {vol}({issue}):{pages}."
        return f"{authors} ({y}). {title} {journal}, {vol}({issue}), {pages}."

    out=[]
    for y in years:                      # <-- ICI : l’ANNÉE vient directement de l’itérable 'years'
        for _ in range(n_per_year):      # on génère n_per_year références pour CETTE année y
            authors = make_authors()
            title = make_title()
            journal = pick_journal()
            vol,issue = make_vol_issue(y)
            pages = make_pages()
            style = random.choice(styles)
            entry = format_entry(style, authors, y, title, journal, vol, issue, pages) + maybe_doi_or_jstor()
            out.append(entry)

    if include_headers:
        out += ["References","Références","BIBLIOGRAPHY","References (continued)","Works Cited"]
    return out


fake_refs = generate_fake_references()
ref_embs = model.encode(fake_refs, convert_to_numpy=True, normalize_embeddings=False)
ref_proto = ref_embs.mean(axis=0)
ref_proto = ref_proto / (np.linalg.norm(ref_proto) + 1e-12)  # unit norm

# 4) Inspection visuelle rapide 
def find_treshold(year:int, output_dir:str, ref_proto:np.ndarray, batch_size:int=200_000):
    """
    Calcule la similarité cosinus avec le prototype 'référence' pour TOUTES les phrases
    d'une année donnée et retourne un DataFrame (sentence, similarity, year).
    """
    fpath = os.path.join(output_dir, f"sentence_embeddings_{year}.feather")
    if not os.path.exists(fpath):
        raise FileNotFoundError(fpath)

    table = pf.read_table(fpath, memory_map=True)
    results = []

    for batch in table.to_batches(max_chunksize=batch_size):
        emb_list = batch.column("embedding").to_pylist()
        X = np.asarray(emb_list, dtype=np.float32)

        # cos-sim = dot / (||x||*||ref||) ; ref_proto est déjà unitaire
        dots = X @ ref_proto
        norms = np.linalg.norm(X, axis=1) + 1e-12
        sims = dots / norms

        sents = batch.column("sentence").to_pylist()
        df_batch = pd.DataFrame({
            "year": year,
            "sentence": sents,
            "similarity": sims
        })
        results.append(df_batch)

    df_all = pd.concat(results, ignore_index=True)
    return df_all

# extract years for supervision (>0.65 threshold)
df1960 = find_treshold(1960, OUTPUT_DIR, ref_proto)
df1960_filtered = df1960[df1960["similarity"] > 0.65]


# 5) Now we have a treshold of 0.65 that is very conservative and should give us very few false positives. 
# We can now applied this treshold and extract all sentences from the folder to delete with their id, and the year of publication.

sentences_to_delete = []

for year in tqdm(range(1900, 2021)):

    df_year = find_treshold(year, OUTPUT_DIR, ref_proto)
    df_year_filtered = df_year[df_year["similarity"] > 0.65]
    sentences_to_delete.append(df_year_filtered)
    print(f"Year {year} done, {len(df_year_filtered)} sentences to delete.")

df_sentences_to_delete = pd.concat(sentences_to_delete, ignore_index=True)

# save in feather
output_path = os.path.join(JSTOR_RAW_DATA_PATH, "sentences_to_delete.feather")
pf.write_feather(df_sentences_to_delete, output_path)