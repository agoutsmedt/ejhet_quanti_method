# Generate all paper diagrams (PNG files saved to paper/images/)
# Run this script manually to regenerate figures.

source(here::here("scripts", "paths_and_packages.R"))
pacman::p_load(DiagrammeR, DiagrammeRsvg, rsvg, glue)

# --- Shared data for labels -------------------------------------------

nb_sentences_top_1_percent <- read_feather(
  here::here(data_path, "top1pct_sentences_by_year.feather"),
  as_data_frame = FALSE
) %>%
  nrow()

nb_articles_meta_corpus <- read_feather(
  here::here(data_path, "metadata_maintext.feather"),
  as_data_frame = FALSE
) %>%
  nrow()

nb_articles_top_10_percent <- read_feather(
  here::here(data_path, "fulltexts_cosine_sim_with_rv.feather"),
  as_data_frame = FALSE
) %>%
  slice_max(cosine_doc_with_rv, prop = 0.1, with_ties = FALSE) %>%
  collect() %>%
  nrow()


# ======================================================================
# 1. method_schema.png  — full data pipeline workflow
# ======================================================================

out_path <- here::here("paper", "images", "method_schema.png")
png(out_path, width = 1800, height = 2000, res = 300)

op <- par(mar = c(0, 0, 0, 0))
plot.new()
plot.window(xlim = c(0, 1), ylim = c(0, 1))

inst_fill <- "#F0BC96" # light orange  (institutional sources)
corpus_fill <- "#9DCAE0" # light blue    (constructed corpora)
proc_fill <- "white"

draw_box <- function(
  x,
  y,
  w,
  h,
  label,
  sub_label = "",
  cex = 0.9,
  sub_cex = 0.75,
  fill = "white"
) {
  rect(x, y, x + w, y + h, lwd = 1.2, col = fill, border = "grey30")
  if (nzchar(sub_label)) {
    text(x + w / 2, y + h * 0.72, label, cex = cex, adj = c(0.5, 0.5))
    text(x + w / 2, y + h * 0.30, sub_label, cex = sub_cex, adj = c(0.5, 0.5))
  } else {
    text(x + w / 2, y + h * 0.5, label, cex = cex, adj = c(0.5, 0.5))
  }
}

draw_arrow <- function(x0, y0, x1, y1) {
  arrows(x0, y0, x1, y1, length = 0.07, lwd = 1.0)
}

# Top row
draw_box(
  0.07,
  0.90,
  0.24,
  0.07,
  "JSTOR economics\njournals",
  cex = 0.80,
  fill = inst_fill
)
draw_box(
  0.37,
  0.90,
  0.56,
  0.07,
  "Scopus economics journals",
  cex = 0.85,
  fill = inst_fill
)

# Sources
draw_box(0.39, 0.78, 0.22, 0.07, "Elsevier API", fill = inst_fill)
draw_box(0.70, 0.78, 0.22, 0.07, "ISTEX API", fill = inst_fill)

# Main pipeline
draw_box(
  0.27,
  0.64,
  0.46,
  0.10,
  "Merge and clean",
  sub_label = "English articles,\nwithout headings, bibliography, etc.",
  cex = 0.88,
  sub_cex = 0.72,
  fill = proc_fill
)
draw_box(
  0.27,
  0.53,
  0.46,
  0.08,
  "Meta-corpus",
  sub_label = glue("{nb_articles_meta_corpus} full-text documents"),
  cex = 0.86,
  sub_cex = 0.70,
  fill = corpus_fill
)
draw_box(
  0.05,
  0.42,
  0.18,
  0.07,
  "Web of\nScience",
  cex = 0.84,
  fill = inst_fill
)
draw_box(0.27, 0.42, 0.46, 0.07, "Add citation data", fill = proc_fill)
draw_box(0.27, 0.33, 0.46, 0.06, "Compute sentence vectors", fill = proc_fill)
draw_box(
  0.27,
  0.25,
  0.46,
  0.06,
  "Compute representative vectors",
  fill = proc_fill
)

# Output corpora
draw_box(
  0.12,
  0.12,
  0.28,
  0.09,
  "Sentences-corpus",
  sub_label = glue("Top 1% sentences\n{nb_sentences_top_1_percent} sentences"),
  cex = 0.85,
  sub_cex = 0.70,
  fill = corpus_fill
)
draw_box(
  0.60,
  0.12,
  0.28,
  0.09,
  "Articles-corpus",
  sub_label = glue(
    "Top 10% articles\n{nb_articles_top_10_percent} articles (post-1960)"
  ),
  cex = 0.85,
  sub_cex = 0.70,
  fill = corpus_fill
)

# Bottom outputs
draw_box(0.08, 0.03, 0.36, 0.055, "Semantic clusters", fill = proc_fill)
draw_box(0.56, 0.03, 0.36, 0.055, "Bibliometric communities", fill = proc_fill)

# Arrows
draw_arrow(0.19, 0.90, 0.38, 0.74) # JSTOR -> Merge
draw_arrow(0.50, 0.90, 0.50, 0.85) # Scopus -> Elsevier
draw_arrow(0.81, 0.90, 0.81, 0.85) # Scopus -> ISTEX
draw_arrow(0.50, 0.78, 0.50, 0.74) # Elsevier -> Merge
draw_arrow(0.81, 0.78, 0.62, 0.74) # ISTEX -> Merge
draw_arrow(0.50, 0.64, 0.50, 0.61) # Merge -> Meta-corpus
draw_arrow(0.50, 0.53, 0.50, 0.49) # Meta-corpus -> Add citation
draw_arrow(0.23, 0.455, 0.27, 0.455) # WoS -> Add citation
draw_arrow(0.50, 0.42, 0.50, 0.39) # Add citation -> Sentence vectors
draw_arrow(0.50, 0.33, 0.50, 0.31) # Sentence vectors -> Representative vectors
draw_arrow(0.50, 0.25, 0.30, 0.21)
draw_arrow(0.50, 0.25, 0.70, 0.21)
draw_arrow(0.26, 0.12, 0.26, 0.085)
draw_arrow(0.74, 0.12, 0.74, 0.085)

# Legend
legend(
  x = 0.76,
  y = 0.60,
  legend = c("Institutional sources", "Constructed corpora"),
  fill = c(inst_fill, corpus_fill),
  border = "grey30",
  bty = "n",
  cex = 0.72
)

par(op)
dev.off()
message("Saved: ", out_path)


# ======================================================================
# 2. rv_method_diagram.png  — representative vector construction
# ======================================================================

g <- grViz(
  "
digraph rv_method {
  graph [layout = dot, rankdir = TB, fontsize = 18]

  node [shape = box, style = rounded, fontname = Helvetica, fontsize = 11]
  edge [fontname = Helvetica, fontsize = 9]

  subgraph cluster_left {
    label = 'A. Build representative vector for 1910 (window 1905\u20131915)';
    color = gray70;
    style = rounded;

    y1915 [label='1915 embeddings of sentences\\nwith rational/rationality'];
    c1915 [label='Centroid 1915'];
    yd2   [label='...'];
    cd2   [label='...'];
    y1910 [label='1910 embeddings of sentences\\nwith rational/rationality'];
    c1910 [label='Centroid 1910'];
    yd1   [label='...'];
    cd1   [label='...'];
    y1906 [label='1906 embeddings of sentences\\nwith rational/rationality'];
    c1906 [label='Centroid 1906'];
    y1905 [label='1905 embeddings of sentences\\nwith rational/rationality'];
    c1905 [label='Centroid 1905'];

    rv1910 [label='Representative vector 1910\\n= mean(1905 ... 1915)',
            shape = box, style='filled', fillcolor='#8C360A'];

    y1915 -> c1915; yd2 -> cd2; y1910 -> c1910;
    yd1 -> cd1; y1906 -> c1906; y1905 -> c1905;
    c1905 -> rv1910; c1906 -> rv1910; cd1 -> rv1910;
    c1910 -> rv1910; cd2  -> rv1910; c1915 -> rv1910;
  }

  subgraph cluster_right {
    label = 'B. Score all 1910 sentences and keep top 1%';
    color = gray70;
    style = rounded;
    labelloc = b;
    labeljust = l;

    s1   [label='1910_sentence_1'];
    s2   [label='1910_sentence_2', style='filled', fillcolor='#2F8CBF'];
    sd1  [label='...'];
    sk   [label='1910_sentence_k'];
    sd2  [label='...'];
    sn   [label='1910_sentence_N', style='filled', fillcolor='#2F8CBF'];
    top1 [label='Top 1% selected = Sentences-corpus',
          style='filled', fillcolor='#2F8CBF'];

    { rank = same; s1; s2; sd1; sk; sd2; sn; }

    s1 -> s2 [style=invis, weight=10, constraint=false];
    s2 -> sd1 [style=invis, weight=10, constraint=false];
    sd1 -> sk [style=invis, weight=10, constraint=false];
    sk -> sd2 [style=invis, weight=10, constraint=false];
    sd2 -> sn [style=invis, weight=10, constraint=false];

    rv1910 -> s1; rv1910 -> s2; rv1910 -> sd1;
    rv1910 -> sk  [label='cosine similarity', fontsize=14, fontcolor='#4A4A4A'];
    rv1910 -> sd2; rv1910 -> sn;

    s2 -> top1 [color=gray40];
    sn -> top1 [color=gray40];
  }
}
"
)

out_path <- here::here("paper", "images", "rv_method_diagram.png")
svg_txt <- DiagrammeRsvg::export_svg(g)
rsvg::rsvg_png(charToRaw(svg_txt), file = out_path, width = 2400, height = 1500)
message("Saved: ", out_path)


# ======================================================================
# 2b. rv_method_diagram_bis.png  — grouped-cluster version (fewer arrows)
#     5 rectangles (one per node type), 4 arrows (one per action)
# ======================================================================

g_bis <- grViz(
  "
digraph rv_method_bis {
  graph [layout = dot, rankdir = TB, compound = true,
         fontsize = 11, nodesep = 0.4, ranksep = 0.4]
  node  [shape = box, style = solid, fontname = Helvetica, fontsize = 10]
  edge  [fontname = Helvetica, fontsize = 10]

  // ---- Cluster 1: one HTML-table node per year (sub-clusters don't render with rank=same) ----
  subgraph cluster_sent_window {
    label = 'Sentences with rational/rationality  between 1905 and 1915';
    color = gray60; style = rounded; bgcolor = 'white';

    y1905 [shape=none, margin=0, label=<
      <TABLE BORDER='1' CELLBORDER='0' CELLSPACING='4' CELLPADDING='4'>
        <TR><TD COLSPAN='4'><B>1905</B></TD></TR>
        <TR><TD BORDER='1'>s1</TD><TD BORDER='1'>s2</TD><TD>...</TD><TD BORDER='1'>sn</TD></TR>
      </TABLE>>];

    yw_d [label='...', shape=plaintext];

    y1910 [shape=none, margin=0, label=<
      <TABLE BORDER='1' CELLBORDER='0' CELLSPACING='4' CELLPADDING='4'>
        <TR><TD COLSPAN='4'><B>1910</B></TD></TR>
        <TR><TD BORDER='1'>s1</TD><TD BORDER='1'>s2</TD><TD>...</TD><TD BORDER='1'>sn</TD></TR>
      </TABLE>>];

    yw_d2 [label='...', shape=plaintext];

    y1915 [shape=none, margin=0, label=<
      <TABLE BORDER='1' CELLBORDER='0' CELLSPACING='4' CELLPADDING='4'>
        <TR><TD COLSPAN='4'><B>1915</B></TD></TR>
        <TR><TD BORDER='1'>s1</TD><TD BORDER='1'>s2</TD><TD>...</TD><TD BORDER='1'>sn</TD></TR>
      </TABLE>>];

    { rank=same; y1905; yw_d; y1910; yw_d2; y1915; }
    y1905 -> yw_d -> y1910 -> yw_d2 -> y1915 [style=invis];
  }

  // ---- Cluster 2: one centroid per year ----
  subgraph cluster_centroids {
    label = 'Year centroids';
    color = gray60; style = rounded; bgcolor = 'white';
    cw1905 [label='1905']; cw_d1 [label='...']; cw1910 [label='1910'];
    cw_d2  [label='...']; cw1915 [label='1915'];
    { rank=same; cw1905; cw_d1; cw1910; cw_d2; cw1915; }
    cw1905 -> cw_d1 -> cw1910 -> cw_d2 -> cw1915 [style=invis];
  }

  // ---- Standalone: RV 1910 ----
  rv1910 [label = 'Representative vector 1910\n= mean(centroids 1905\u20131915)',
          style = 'filled', fillcolor = 'white', width = 4];

  // ---- Cluster 3: all 1910 sentences, some blue (top 1%) ----
  subgraph cluster_all_sent {
    label = 'All 1910 sentences';
    color = gray60; style = rounded; bgcolor = 'white';
    sa1   [label='s1', style='filled', fillcolor='#9DCAE0'];
    sa2   [label='s2'];
    sa_d1 [label='...', shape=plaintext];
    saK   [label='s121'];
    sa_e  [label='s122' style='filled', fillcolor='#9DCAE0'];
    sa_d2 [label='...', shape=plaintext];
    saN   [label='sN'];
    { rank=same; sa1; sa2; sa_d1; saK; sa_e; sa_d2; saN; }
    sa1 -> sa2 -> sa_d1 -> saK -> sa_e -> sa_d2 -> saN [style=invis];
  }

  // ---- Standalone: Sentences-corpus ----
  top1 [label = 'Sentences-corpus  (top 1%)',
        style = 'rounded,filled', fillcolor = '#9DCAE0', width = 3];

  // ---- Broken arrows: steps 1-4 ----
  lbl_centroid [label='compute centroid',          shape=plaintext, fontsize=10];
  lbl_mean     [label='compute mean',              shape=plaintext, fontsize=10];
  lbl_cosine   [label='compute cosine similarity', shape=plaintext, fontsize=10];
  lbl_select   [label='select top 1%',             shape=plaintext, fontsize=10];

  y1910        -> lbl_centroid [arrowhead=none];
  lbl_centroid -> cw1910       [lhead=cluster_centroids];

  cw1910       -> lbl_mean     [ltail=cluster_centroids, arrowhead=none];
  lbl_mean     -> rv1910;

  rv1910       -> lbl_cosine   [arrowhead=none];
  lbl_cosine   -> saK          [lhead=cluster_all_sent];

  saK          -> lbl_select   [ltail=cluster_all_sent, arrowhead=none];
  lbl_select   -> top1;
}
"
)

out_path <- here::here("paper", "images", "rv_method_diagram_bis.png")
svg_txt <- DiagrammeRsvg::export_svg(g_bis)
rsvg::rsvg_png(charToRaw(svg_txt), file = out_path, width = 2400, height = 2200)
message("Saved: ", out_path)


# ======================================================================
# 3. text_clustering_schema.png  — text clustering workflow
# ======================================================================

out_path <- here::here("paper", "images", "text_clustering_schema.png")
png(out_path, width = 1600, height = 1000, res = 200)
op <- par(mar = c(0, 0, 0, 0))
plot.new()
plot.window(xlim = c(0, 1), ylim = c(0, 1))

draw_box <- function(x, y, w, h, label) {
  rect(x, y, x + w, y + h, lwd = 1.2)
  text(x + w / 2, y + h / 2, label, cex = 0.9)
}
draw_arrow <- function(x0, y0, x1, y1) {
  arrows(x0, y0, x1, y1, length = 0.08, lwd = 1.0)
}

draw_box(0.28, 0.72, 0.44, 0.08, "Representative vector")
draw_box(0.28, 0.60, 0.44, 0.08, "Select top 1% sentences")
draw_box(0.28, 0.48, 0.44, 0.08, "Project with UMAP (100 Dimensions)")
draw_box(0.28, 0.36, 0.44, 0.08, "Cluster with HDBSCAN")
draw_box(0.28, 0.24, 0.44, 0.08, "Merge clusters over time")
draw_box(0.28, 0.12, 0.44, 0.08, "Intertemporal semantic clusters")

draw_arrow(0.50, 0.712, 0.50, 0.688)
draw_arrow(0.50, 0.592, 0.50, 0.568)
draw_arrow(0.50, 0.472, 0.50, 0.448)
draw_arrow(0.50, 0.352, 0.50, 0.328)
draw_arrow(0.50, 0.232, 0.50, 0.208)

par(op)
dev.off()
message("Saved: ", out_path)


# ======================================================================
# 4. biblio_coupling_schema.png  — bibliometric community detection
# ======================================================================

out_path <- here::here("paper", "images", "biblio_coupling_schema.png")
png(out_path, width = 1600, height = 1000, res = 200)
op <- par(mar = c(0, 0, 0, 0))
plot.new()
plot.window(xlim = c(0, 1), ylim = c(0, 1))

draw_box(0.28, 0.74, 0.44, 0.08, "Representative vectors")
draw_box(0.28, 0.59, 0.44, 0.08, "Select closest documents")
draw_box(0.28, 0.44, 0.44, 0.08, "Leiden community detection")
draw_box(0.28, 0.29, 0.44, 0.08, "Merge communities over time")
draw_box(0.28, 0.14, 0.44, 0.08, "Intertemporal bibliometric communities")

draw_arrow(0.50, 0.732, 0.50, 0.67)
draw_arrow(0.50, 0.582, 0.50, 0.52)
draw_arrow(0.50, 0.432, 0.50, 0.37)
draw_arrow(0.50, 0.282, 0.50, 0.22)

par(op)
dev.off()
message("Saved: ", out_path)
