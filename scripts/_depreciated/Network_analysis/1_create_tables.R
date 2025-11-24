source(file.path("scripts", "paths_and_packages.R"))

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#### Function ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

layout_fa2_javaV3 <- function(
  tbl = tbl,
  niter = 3000,
  barneshut = "true",
  path = here(
    dirname(dirname(data_path)),
    "Home",
    "2-External_tools",
    "GephiLayouts-1.0.jar"
  ),
  data_path = data_path
) {
  #Layout
  graph_before <- tbl %>% activate(nodes) %>% mutate(id = as.character(Id))
  nodes_before <- tbl %>% activate(nodes) %>% as.data.table()

  if ("x" %in% colnames(nodes_before)) {
    graph_before <- graph_before %>%
      activate(nodes) %>%
      mutate(x = ifelse(is.na(x) == TRUE, sample(1:100), x))
    graph_before <- graph_before %>%
      activate(nodes) %>%
      mutate(y = ifelse(is.na(y) == TRUE, sample(1:100), y))
    graph_before <- graph_before %>%
      activate(nodes) %>%
      select(c(id, ID_Art, x, y, size))
  } else {
    graph_before <- graph_before %>%
      activate(nodes) %>%
      select(c(id, ID_Art, size))
  }

  write.graph(
    graph = graph_before,
    file = here(data_path, 'tidy.graphml'),
    format = 'graphml'
  )
  system(paste0(
    'java -jar \"',
    path,
    '\" forceatlas2 -i "/',
    here(data_path, 'tidy.graphml'),
    '" -o "/',
    here(data_path, 'forceatlas2.graphml'),
    '" -threads 16 -maxiters ',
    niter,
    ' -barneshut ',
    barneshut,
    ' -adjustsizes true -gravity 1'
  ))

  gml <- read.graph(here(data_path, 'forceatlas2.graphml'), format = "graphml")
  graph_after <- as_tbl_graph(gml)
  graph_after <- graph_after %>%
    activate(nodes) %>%
    as.data.table() %>%
    .[, .(x, y, ID_Art)]

  if ("x" %in% colnames(nodes_before)) {
    tbl <- tbl %>%
      activate(nodes) %>%
      select(-c(x, y)) %>%
      left_join(graph_after)
  } else {
    tbl <- tbl %>% activate(nodes) %>% left_join(graph_after)
  }

  return(tbl)
}

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#### Parameters ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

time_window_var <- 8
length_cl_var <- 2
share_cl_max_var <- 0.05
year_high <- 2014
year_low <- 1960
rationality_score_filter <- 0.05
rationality_prop_filter <- 0.10

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#### Introduction ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

# matching bd
jstor_matched <- read_rds(here(
  jstor_data_path,
  "jstor_constellate_merged_metadata.rds"
))
jstor_matched <- jstor_matched[
  !is.na(id_wos_matched),
  .(id = url, id_wos_matched)
]

scopus_matched <- read_rds(here(
  elsevier_data_path,
  "scopus_economics_articles.rds"
))
scopus_matched <- scopus_matched[
  !is.na(id_wos_matched),
  .(id = scopus_id, id_wos_matched)
]
matching <- rbind(jstor_matched, scopus_matched)

# Similarity scores
# rationality_score <- readRDS(here(data_path, "rationality_similarity_scores.RDS"))

# rationality_score_original <- arrow::read_feather(here(data_path, "similarities_by_document.feather")) %>% as.data.table()
rationality_score_original <- arrow::read_feather(here(
  data_path,
  "fulltexts_cosine_sim_with_rv.feather"
)) %>%
  as.data.table()

rationality_score <- rationality_score_original[, .(
  id,
  similarity = cosine_doc_with_rv
)]

filter_mean_score_ids <- rationality_score %>%
  slice_max(similarity, prop = rationality_prop_filter) %>%
  .[[1]]

# mean_three_pages <- rationality_score[order(jstor_id,-similarity)][, head(.SD, 3), by = jstor_id]
# mean_three_pages[,mean_3_p:=mean(similarity), jstor_id]
# mean_three_pages <- mean_three_pages[,.N,.(jstor_id,mean_3_p)]

# before <- ggplot(rationality_score_original, aes(x=publication_year)) +
#   geom_histogram(color="black")
# after <- ggplot(rationality_score_original %>% slice_max(cosine_sim_centered, prop = rationality_prop_filter), aes(x=publication_year)) +
#   geom_histogram(color="black")

# wos
wos_art <- arrow::read_parquet(
  here(general_data_path, "all_art.parquet"),
  arrow.unsafe_metadata = TRUE
)
journal_wos <- fread(here(general_data_path, "all_journals.csv"))
wos_aut <- readRDS(here(general_data_path, "all_aut.RDS"))
wos_refs <- arrow::read_parquet(
  here(general_data_path, "all_ref.parquet"),
  arrow.unsafe_metadata = TRUE
)
refs_info <- copy(wos_art)

# Add variables
wos_art <- merge(
  wos_art,
  wos_aut[Ordre == 1, .(Nom, ID_Art)],
  by = "ID_Art",
  all.x = TRUE
)
wos_art <- wos_art[, name_short := gsub("-.*", "", Nom)]
wos_art$name_short <- toupper(wos_art$name_short)
wos_art <- wos_art[, Label := paste0(name_short, ",", Annee_Bibliographique)]
wos_art[, c("name_short") := NULL]

# Filtering
ids_rationality <- matching[id_jstor %in% filter_mean_score_ids]

rationality_score_abstract <- arrow::read_feather(here(
  data_path,
  "similarities_wos_abstracts_window_5.feather"
)) %>%
  as.data.table()

ids_rationality_abstract <- rationality_score_abstract %>%
  slice_max(cosine_sim_centered, prop = rationality_prop_filter) %>%
  .[[1]]

ids_rationality <- append(
  ids_rationality$id_match_final,
  ids_rationality_abstract
)
ids_rationality <- ids_rationality %>% na.omit() %>% unique()

# ids_jstor <- mean_three_pages %>% slice_max(mean_3_p, prop = rationality_prop_filter)
# ids_rationality <- matching[id_jstor %in% ids_jstor$jstor_id]

wos_art <- wos_art[
  Annee_Bibliographique >= year_low & Annee_Bibliographique <= year_high
]
wos_art <- wos_art[ID_Art %in% ids_rationality]

wos_refs <- wos_refs[ItemID_Ref != 0]
wos_refs <- wos_refs[ID_Art %in% wos_art$ID_Art]

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#### Publications - Coupling ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

nodes <- copy(wos_art)
edges <- copy(wos_refs)

coup_network <- networkflow::build_dynamic_networks(
  nodes = nodes,
  directed_edges = edges,
  source_id = "ID_Art",
  target_id = "ItemID_Ref",
  time_variable = "Annee_Bibliographique",
  time_window = time_window_var,
  cooccurrence_method = "coupling_strength",
  overlapping_window = TRUE,
  compute_size = TRUE,
  edges_threshold = 2
)

coup_network <- lapply(coup_network, function(tbl) {
  (tbl %>% activate(nodes) %>% left_join(journal_wos, by = "Code_Revue"))
})
tbl_coup_list <- networkflow::filter_components(coup_network)

set.seed(1858545)
tbl_coup_list <- networkflow::add_clusters(
  tbl_coup_list,
  clustering_method = "leiden",
  objective_function = "modularity"
)
tbl_coup_list <- networkflow::merge_dynamic_clusters(
  list_graph = tbl_coup_list,
  cluster_id = "cluster_leiden",
  node_id = "ID_Art",
  threshold_similarity = 0.501,
  similarity_type = "partial"
)

# Position
tbl_coup_list <- lapply(tbl_coup_list, function(tbl) {
  tbl %N>% mutate(Id = as.character(ID_Art), ID_Art = as.character(ID_Art))
})
tbl_coup_list <- lapply(tbl_coup_list, function(tbl) {
  tbl %N>% mutate(size = node_size)
})
tbl_coup_list <- lapply(tbl_coup_list, function(tbl) {
  tbl %N>% mutate(size = ifelse(is.na(size), 0, size))
})

names(tbl_coup_list) <- substr(names(tbl_coup_list), 1, 4)

list_graph_position <- list()
for (Year in names(tbl_coup_list) %>% as.integer) {
  if (is.null(tbl_coup_list[[paste0(Year - 1)]])) {
    list_graph_position[[paste0(Year)]] <- layout_fa2_javaV3(
      tbl_coup_list[[paste0(Year)]],
      niter = 20000,
      barneshut = "true",
      path = here(
        dirname(dirname(data_path)),
        "Home",
        "2-External_tools",
        "GephiLayouts-1.0.jar"
      ),
      data_path = data_path
    )
  }
  if (!is.null(tbl_coup_list[[paste0(Year - 1)]])) {
    past_position <- list_graph_position[[paste0(Year - 1)]] %>%
      activate(nodes) %>%
      as.data.table()
    past_position <- past_position[, .(Id, x, y)]

    tbl <- tbl_coup_list[[paste0(Year)]] %>%
      activate(nodes) %>%
      left_join(past_position)

    list_graph_position[[paste0(Year)]] <- layout_fa2_javaV3(
      tbl,
      niter = 20000,
      barneshut = "true",
      path = here(
        dirname(dirname(data_path)),
        "Home",
        "2-External_tools",
        "GephiLayouts-1.0.jar"
      ),
      data_path = data_path
    )
  }
}
list_position <- lapply(list_graph_position, function(tbl) {
  tbl %N>% as.data.table() %>% .[, .(ID_Art, x, y)]
})

tbl_coup_list <- lapply(names(tbl_coup_list), function(Year) {
  tbl_coup_list[[paste0(Year)]] %N>% left_join(list_position[[paste0(Year)]])
})
names(tbl_coup_list) <- names(list_position)

# Alluvial
alluv_dt <- networkflow::networks_to_alluv(
  tbl_coup_list,
  intertemporal_cluster_column = "dynamic_cluster_leiden",
  node_id = "ID_Art",
  summary_cluster_stats = TRUE
)
alluv_dt <- networkflow::minimize_crossing_alluvial(
  alluv_dt,
  intertemporal_cluster_column = "dynamic_cluster_leiden",
  node_id = "ID_Art",
  window_column = "window"
)

# Colors with some filtering based on alluvial
color <- as.character(paletteer::paletteer_d("ggsci::default_igv")) %>%
  as.data.table()
color2 <- brewer.pal(7, name = "Dark2") %>% as.data.table()
color3 <- brewer.pal(7, name = "Set1") %>% as.data.table()
color4 <- brewer.pal(12, name = "Paired") %>% as.data.table()
main_colors <- rbind(color, color2, color3, color4)
n_colors <- alluv_dt[
  length_cluster >= length_cl_var & share_cluster_max >= share_cl_max_var,
  .N,
  dynamic_cluster_leiden
][, .N]

main_colors_table <- data.table(
  dynamic_cluster_leiden = alluv_dt[
    length_cluster >= length_cl_var & share_cluster_max >= share_cl_max_var,
    .N,
    dynamic_cluster_leiden
  ][, dynamic_cluster_leiden],
  main_colors = rep(main_colors$., length.out = n_colors)
)

# Networks plot (colors and label)
tbl_networks <- lapply(tbl_coup_list, function(tbl) {
  tbl %N>%
    left_join(main_colors_table) %>%
    mutate(main_colors = ifelse(is.na(main_colors), "grey", main_colors))
})

tbl_networks <- lapply(tbl_networks, function(tbl) {
  tbl %>%
    activate(edges) %>%
    mutate(
      com_ID_to = .N()$main_colors[to],
      com_ID_from = .N()$main_colors[from]
    ) %>%
    mutate(
      color_edges = DescTools::MixColor(com_ID_to, com_ID_from, amount1 = 0.5)
    )
})

# Alluvial plot (colors and label)
label_mean <- copy(alluv_dt)
label_mean[, Label := dynamic_cluster_leiden]
label_mean <- label_mean[,
  window := round(mean(as.numeric(window))),
  dynamic_cluster_leiden
][, head(.SD, 1), .(dynamic_cluster_leiden)]
alluv_dt <- merge(
  alluv_dt,
  label_mean[, .(dynamic_cluster_leiden, window, Label)],
  by = c("dynamic_cluster_leiden", "window"),
  all.x = TRUE
)

alluv_dt <- alluv_dt %>%
  left_join(main_colors_table) %>%
  mutate(main_colors = ifelse(is.na(main_colors), "grey", main_colors))
alluv_dt[main_colors == "grey", Label := NA]

alluv_dt$dynamic_cluster_leiden <- forcats::fct_reorder(
  alluv_dt$dynamic_cluster_leiden,
  alluv_dt$minimize_crossing_order,
  min,
  .desc = TRUE
)

ggplot(
  alluv_dt,
  aes(
    x = window,
    y = y_alluv,
    stratum = dynamic_cluster_leiden,
    alluvium = ID_Art,
    fill = main_colors,
    label = dynamic_cluster_leiden
  )
) +
  geom_stratum(alpha = 1, size = 1 / 10) +
  geom_flow() +
  theme(legend.position = "none") +
  theme_minimal() +
  scale_fill_identity() +
  ggtitle("") +
  ggrepel::geom_label_repel(stat = "stratum", size = 6, aes(label = Label))


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#### 6 tf-idf ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
tf_idf <- copy(tbl_networks)
tf_idf <- networkflow::extract_tfidf(
  tf_idf,
  "Titre",
  "dynamic_cluster_leiden",
  grouping_across_list = FALSE,
  clean_word_method = "lemmatize",
  nb_terms = 20
)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#### AI name cluster ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
cluster_list <- alluv_dt[
  share_cluster_alluv >= 0.1,
  .N,
  dynamic_cluster_leiden
][, dynamic_cluster_leiden]

list_clusters_ai_names <- list()
counter <- 0
for (cl in cluster_list) {
  art <- alluv_dt[dynamic_cluster_leiden == cl]

  top_20_refs <- wos_refs[ID_Art %in% art$ID_Art][, .N, .(ItemID_Ref)][order(
    -N
  )][1:40]
  top_20_refs <- merge(
    top_20_refs,
    refs_info[, .(ItemID_Ref, Titre)],
    by = "ItemID_Ref",
    all.x = TRUE
  )

  top_20_authors <- wos_aut[ID_Art %in% art$ID_Art]
  top_20_authors <- top_20_authors[, .N, Nom][order(-N)][1:20]

  top_20_tfidf <- tf_idf[dynamic_cluster_leiden == cl]
  top_20_tfidf <- top_20_tfidf[order(-tf_idf)][1:20]

  DT <- data.table(
    top_20_references_title = top_20_refs[order(-N)]$Titre,
    top_20_authors = top_20_authors$Nom,
    top_20_tfidf = top_20_tfidf$term
  )

  txt <- ollamar::generate(
    "gemma3:27b",
    paste0(
      "Here is a cluster or scientific articles in economics made using bibliographic coupling. 
                       You can find in the following text the top 20 most common references in the cluster, their title when available, and the 20 most prolific authors in the cluster.
                       Using this information to name cluster using no more than 5 words. 
                       Your output should start with the name of the cluster followed by a full stop.
                       Your output should only be the name of the cluster, nothing else. I insist: output only the name of the cluster. 
                       Here is the data: ",
      toJSON(DT, pretty = TRUE)
    ),
    output = "text"
  )

  list_clusters_ai_names[[as.character(cl)]] <- txt

  counter <- counter + 1
  print(paste0("cluster ", counter, " out of ", length(cluster_list)))
}

names_ai <- data.table(
  id_col = names(list_clusters_ai_names),
  value_col = unlist(list_clusters_ai_names, use.names = FALSE) # use.names = FALSE to avoid issues if names had patterns
)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#### 8 Saving ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
saveRDS(
  tf_idf,
  here(
    data_path,
    "Networks",
    paste(
      "tf_idf",
      year_low,
      year_high,
      time_window_var,
      "year_windows",
      rationality_prop_filter,
      "rationality_score.RDS",
      sep = "_"
    )
  )
)
saveRDS(
  alluv_dt,
  here(
    data_path,
    "Networks",
    paste(
      "alluv",
      year_low,
      year_high,
      time_window_var,
      "year_windows",
      rationality_prop_filter,
      "rationality_score.RDS",
      sep = "_"
    )
  )
)
saveRDS(
  tbl_networks,
  here(
    data_path,
    "Networks",
    paste(
      "networks",
      year_low,
      year_high,
      time_window_var,
      "year_windows",
      rationality_prop_filter,
      "rationality_score.RDS",
      sep = "_"
    )
  )
)
saveRDS(
  names_ai,
  here(
    data_path,
    "Networks",
    paste(
      "label_ai",
      year_low,
      year_high,
      time_window_var,
      "year_windows",
      rationality_prop_filter,
      "rationality_score.RDS",
      sep = "_"
    )
  )
)


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
#### Networks ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
names_ai <- names_ai %>% rename(dynamic_cluster_leiden = id_col)
alluv_dt <- merge(
  alluv_dt,
  names_ai,
  by = "dynamic_cluster_leiden",
  all.x = TRUE
)
alluv_dt[!is.na(value_col), dynamic_cluster_leiden := value_col]
alluv_dt[!is.na(Label), Label := dynamic_cluster_leiden]
alluv_dt$dynamic_cluster_leiden <- forcats::fct_reorder(
  alluv_dt$dynamic_cluster_leiden,
  alluv_dt$minimize_crossing_order,
  min,
  .desc = TRUE
)

ggplot(
  alluv_dt,
  aes(
    x = window,
    y = y_alluv,
    stratum = dynamic_cluster_leiden,
    alluvium = ID_Art,
    fill = main_colors,
    label = dynamic_cluster_leiden
  )
) +
  geom_stratum(alpha = 1, size = 1 / 10) +
  geom_flow() +
  theme_minimal() +
  theme(
    legend.position = "none",
    panel.background = element_rect(fill = 'white', color = NA)
  ) +
  scale_fill_identity() +
  ggtitle("") +
  ggrepel::geom_label_repel(stat = "stratum", size = 2, aes(label = Label))
