# One Sentence at a Time: A Quantitative History of Rationality in Economic Thought

Replication repository for:

> Delcey, T., Goutsmedt, A., & Truc, A. (forthcoming). "One Sentence at a Time: A Quantitative History of Rationality in Economic Thought." *European Journal of the History of Economic Thought*, [preprint](https://hal.science/hal-05431080/)

## Authors

- [Thomas Delcey](https://github.com/tdelcey/) (Université de Bourgogne Europe) 
- [Aurélien Goutsmedt](https://github.com/agoutsmedt/) (UC Louvain, ISPOLE / ICHEC Brussels)
- [Alexandre Truc](https://github.com/Alex7722) (Université Côte d'Azur)


## Overview

This repository contains the code to reproduce the quantitative analysis in the paper. Because the data are under license restrictions and cannot be shared, we did not structure the repo for direct replication but to help interested readers understand the data processing pipeline and adapt it to their own corpora. 

The result of the analysis can be explored using the interactive Shiny app available for download at [10.5281/zenodo.20558669](https://zenodo.org/record/20558669). A version of the app is also hosted online at [https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/](https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/). 

## Repository structure

```
scripts/
├── paths_and_packages.R              # R setup: packages and data paths
├── paths.py                          # Python setup: data paths
├── functions/                        # Shared utility functions (R + Python)
│
├── 1_corpus/                         # Corpus construction and noise cleaning
├── 2_representative_vectors/         # Reference vectors and top-1% sentence selection
├── 3_clustering/                     # UMAP + HDBSCAN clustering
├── 4_network_analysis/               # Bibliometric network analysis
└── 5_outputs/                        # Figures and tables for the paper

paper/
└── paper_v3.qmd                      # Quarto manuscript
```

## Data

Raw data comes from four sources and is **not included** in this repository due to size and licensing restrictions:

| Source | Content |
|--------|---------|
| JSTOR | Full-text economics articles |
| Web of Science | Citation metadata |
| Elsevier | Full-text economics articles |
| ISTEX | Full-text economics articles |

Sentence embeddings were pre-computed with [`sentence-transformers/all-mpnet-base-v2`](https://huggingface.co/sentence-transformers/all-mpnet-base-v2) and stored externally alongside the raw data.

## Setup

### 1. Configure data paths

Edit `scripts/paths.py` (Python) and `scripts/paths_and_packages.R` (R) to point to your local data directories. 

### 2. R environment

R packages are managed via [pacman](https://cran.r-project.org/package=pacman) and installed automatically when you source `scripts/paths_and_packages.R`. The only manual step is:

```r
install.packages("pacman")
```

### 3. Python environment

```bash
pip install -r requirements.txt
```

> All Python scripts must be run from the **project root** so that `import scripts.paths` resolves correctly. 

## Execution order

### Phase 1 — Corpus construction and noise cleaning

This phase is specific to our corpus and is not reusable for other corpora. It creates a unified metadata table across sources and identifies "noisy" sentences (affiliations, acknowledgements, headers, references) to be removed from the subsequent analysis.

| Script | Description |
|--------|-------------|
| `1_corpus/01_create_unified_metadata.R` | Build unified metadata across sources |
| `1_corpus/02_compute_noisy_centroids.py` | Compute centroids for noisy sentence categories (affiliations, acknowledgements, headers, references) |
| `1_corpus/03_compute_threshold_youden.py` | Compute Youden-optimal similarity threshold per noise category |
| `1_corpus/04_evaluate_threshold.py` | *(Diagnostic)* Inspect flagged sentences around the threshold |
| `1_corpus/05_collect_noisy_sentences.py` | Apply thresholds to flag and remove noisy sentences → `sentences_to_delete.feather` |

### Phase 2 — Representative vectors and sentence selection

This phase computes representative vectors for the concept of rationality. It also creates our two corpora for subsequent analysis: the top-10% most relevant documents for bibliometric communities and the top-1% most relevant sentences for textual clusters.

| Script | Description |
|--------|-------------|
| `2_representative_vectors/01_compute_rv.py` | Compute yearly and moving-average representative vectors for "rationality" → `rv_moving_average_by_year.feather` |
| `2_representative_vectors/02_compute_similarity_fulltexts.py` | Cosine similarity of each fulltext to the representative vector → `fulltexts_cosine_sim_with_rv.feather` *(used in Phase 4 to select the top-10% most relevant documents for network analysis)* |
| `2_representative_vectors/03_compute_1pct_sentences.py` | Extract top-1% sentences closest to the representative vector → `top1pct_sentences_by_year.feather` |

### Phase 3 — Clustering

This phase creates our textual clusters (UMAP projection + HDBSCAN). 

| Script | Description |
|--------|-------------|
| `3_clustering/01_add_embeddings_1pct.R` | Attach embedding vectors to the top-1% sentence dataset |
| `3_clustering/02_hdbscan.py` | UMAP projection + HDBSCAN clustering by time window → `hdbscan_all_sentences_with_clusters.feather` |
| `3_clustering/03_merge_clusters.R` | Track clusters across time windows via centroid similarity |

### Phase 4 — Network analysis

This phase creates our bibliometric communities. 

| Script | Description |
|--------|-------------|
| `4_network_analysis/01_create_tables.R` | Filter top-10% documents by cosine similarity to the RV, then build bibliometric coupling tables |
| `4_network_analysis/02_analysis.Rmd` | Network analysis and visualisation |

### Phase 5 — Outputs

This phase produces the figures and tables for the paper. 

| Script | Description |
|--------|-------------|
| `5_outputs/01_plot_diagrams.R` | Methodology diagrams |
| `5_outputs/02_plot_database_distribution.R` | Corpus distribution figures |
| `5_outputs/03_plot_description_clusters.R` | Cluster description figures |
| `5_outputs/04_frequency_neighbors.py` | Compute neighbor word frequencies around "rational(ity)" |
| `5_outputs/05_plot_frequency_rationality.R` | Frequency of rationality over time |
| `5_outputs/06_plot_frequency_rationality_neighbor.R` | Neighbor word frequency plots |
| `5_outputs/07_top_sentences_to_rv.py` | Top sentences closest to the reference sentence |
| `5_outputs/08_table_closest_sentences.R` | Table of closest sentences per cluster |
| `5_outputs/09_table_corpus_overlap.R` | Corpus overlap table |
| `5_outputs/10_table_wos_matching.R` | WoS matching table |

