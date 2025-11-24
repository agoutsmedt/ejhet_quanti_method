import os
import pandas as pd
from groq import Groq
import uuid
import time
import paths

# ===========================================
# CONFIG
# ===========================================

PARQUET_PATH = os.path.join(paths.ejhet_project_data_path, "sample_sentences_for_labelling.parquet")

OUT_PATH = os.path.join(paths.ejhet_project_data_path, "sample_sentences_labelled.parquet")

GROQ_MODEL = "llama-3.1-8b-instant"

API_KEY_PATH = os.getcwd() + "\\groq_api_key.txt"

with open(API_KEY_PATH, "r") as f:
    GROQ_API_KEY = f.read().strip()

client = Groq(api_key=GROQ_API_KEY)

SYSTEM_PROMPT = """Classify the following scientific sentence into ONE label:

CLEAN_TEXT  = real scientific prose
AFFILIATION = author names, institutions, emails, departments
HEADER      = copyright, ISSN, publisher boilerplate
REFERENCE   = bibliography, DOI, journal info, volume/page
ACK         = acknowledgments or funding statements

Return ONLY one label: CLEAN_TEXT, AFFILIATION, HEADER, REFERENCE, ACK.
"""

# ===========================================
# LOAD DATA
# ===========================================

df = pd.read_parquet(PARQUET_PATH)
df["custom_id"] = [str(uuid.uuid4()) for _ in range(len(df))]

labels = []

# ===========================================
# CLASSIFY SENTENCES (FAST LOOP)
# ===========================================

for i, row in df.iterrows():
    user_prompt = f"sentence: {row['sentence']}\nregex_guess: {row['regex_guess']}"

    resp = client.chat.completions.create(
        model=GROQ_MODEL,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user_prompt},
        ],
        max_tokens=4,
        temperature=0,
    )

    label = resp.choices[0].message.content.strip()
    labels.append({"custom_id": row["custom_id"], "label": label})

    if i % 500 == 0:
        print(f"{i}/{len(df)} classified")

# ===========================================
# MERGE RESULTS
# ===========================================

df_labels = pd.DataFrame(labels)
df_final = df.merge(df_labels, on="custom_id")

df_final.to_parquet(OUT_PATH, index=False)
print("DONE:", OUT_PATH)
