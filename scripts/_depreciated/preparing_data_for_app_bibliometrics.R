# Loading data

graphs <- readRDS(here::here(
  data_path,
  "networks",
  "networks_1960_2014_8_year_windows_0.1_rationality_score.RDS"
))

ref_dataset <- open_dataset(
  here::here(wos_data_path, "all_ref.parquet"),
  format = "parquet"
)

list_ids <- lapply(graphs, function(graph) {
  graph %>%
    activate(nodes) %>%
    as_tibble() %>%
    select(ID_Art) %>%
    distinct()
}) %>%
  bind_rows() %>%
  distinct() %>%
  pull(ID_Art) %>%
  as.integer()

refs <- ref_dataset %>%
  filter(ID_Art %in% list_ids) %>%
  select(ID_Art, ItemID_Ref, Annee, Nom, Revue_Abbrege) %>%
  collect()

labels <- readRDS(here::here(
  data_path,
  "networks",
  "label_ai_1960_2014_8_year_windows_0.1_rationality_score.RDS"
))

metadata <- arrow::read_feather(here::here(
  data_path,
  "metadata_maintext.feather"
)) %>%
  mutate(
    url = if_else(str_detect(id, "jstor"), id, str_c("https://doi.org/", doi))
  ) %>%
  select(id_wos_matched, id, url) %>%
  rename(ID_Art = id_wos_matched, id_text = id) %>%
  mutate(ID_Art = as.character(ID_Art)) %>%
  filter(!is.na(ID_Art)) %>%
  distinct(ID_Art, .keep_all = TRUE)

graphs <- lapply(graphs, function(graph) {
  graph <- graph %>%
    activate(nodes) %>%
    left_join(
      metadata,
      by = "ID_Art"
    )
})

sentences <- arrow::read_feather(here::here(
  data_path,
  "closest_sentences_0.01_rationality_score_filtered_with_embeddings.feather"
)) %>%
  filter(year > 1959)

# Getting the most representative sentence per article

article_sentences <- sentences %>%
  group_by(id) %>%
  slice_max(order_by = similarity_rv, n = 1, with_ties = FALSE) %>%
  select(id, sentence, similarity_rv)

# add labels to the list of graphs and prepare node tooltips
graphs <- lapply(graphs, function(graph) {
  graph <- graph %>%
    activate(nodes) %>%
    left_join(labels, by = c("dynamic_cluster_leiden" = "id_col")) %>%
    left_join(article_sentences, by = c("id_text" = "id")) %>%
    arrange(desc(node_size)) %>%
    rename(color = main_colors) %>%
    mutate(
      nodes_tooltip = paste0(
        Nom,
        " \\(",
        Annee_Bibliographique,
        "\\) ",
        Titre
      ) %>%
        str_replace_all(., "[:punct:]", " ") %>%
        str_squish(),
      value_col = if_else(is.na(value_col), dynamic_cluster_leiden, value_col)
    )

  graph <- graph %>%
    activate(edges) %>%
    rename(color = color_edges)
})

# Calculating Guimerà–Amaral roles
#' - P tells you the scope of a node’s connections (local vs cross-cluster).
#' - z tells you the intensity of a node’s position inside its cluster (hub vs peripheral).
#' - Together they classify each paper’s role: insider, bridge, local hub, or global connector.
# Apply to all graphs (optionally parallelize with future.apply)
graphs <- lapply(graphs, function(g) {
  m <- compute_role_fast(
    g,
    comm_attr = "cluster_leiden",
    weight_attr = "weight"
  )
  g %N>%
    mutate(
      total_strength = m$total_strength,
      participation_coefficient = m$participation_coefficient,
      z_within = m$z_within
    )
})

#' The last thing to do is to choose a threshold which depends of the distribution of all our
#' z and P values. The original paper used z = 2.5 and P = 0.62 and 0.80 for non-hubs, but
#' it should be adapted to our data.

# Extract data for all our graphs to choose thresholds
all_graphs_data <- map(graphs, ~ . %N>% as_tibble()) %>%
  bind_rows() %>%
  select(ID_Art, z_within, participation_coefficient)

thr <- choose_role_thresholds(
  z = all_graphs_data$z_within,
  P = all_graphs_data$participation_coefficient
)

graphs <- lapply(graphs, function(graph) {
  graph <- graph %N>%
    dplyr::mutate(
      role = dplyr::case_when(
        z_within < thr$hub_z & participation_coefficient <= thr$nonhub_P[1] ~
          "ultra-peripheral",
        z_within < thr$hub_z & participation_coefficient <= thr$nonhub_P[2] ~
          "peripheral",
        z_within < thr$hub_z & participation_coefficient <= thr$nonhub_P[3] ~
          "connector",
        z_within < thr$hub_z ~ "kinless",
        z_within >= thr$hub_z & participation_coefficient <= thr$hub_P[1] ~
          "provincial hub",
        z_within >= thr$hub_z & participation_coefficient <= thr$hub_P[2] ~
          "connector hub",
        TRUE ~ "kinless hub"
      )
    )
})

# Adding references
cli::cli_alert_info("Adding references...")
nodes <- map(graphs, ~ . %N>% as_tibble()) %>%
  bind_rows() %>%
  mutate(
    value_col = if_else(is.na(value_col), dynamic_cluster_leiden, value_col),
    ID_Art = as.integer(ID_Art),
    Titre = if_else(
      !is.na(url),
      glue("<a href='{url}' target='_blank'>{Titre}</a>"),
      Titre
    )
  )

references_cited <- nodes %>%
  distinct(ID_Art, value_col, time_window) %>%
  left_join(refs, by = "ID_Art", relationship = "many-to-many") %>%
  filter(ItemID_Ref != 0) %>%
  group_by(value_col, time_window, ItemID_Ref) %>%
  summarise(n = n(), .groups = "drop") %>%
  group_by(value_col, time_window)

top_refs <- references_cited %>%
  arrange(time_window, value_col, desc(n)) %>%
  group_by(time_window, value_col) %>%
  slice_head(n = 20) %>%
  ungroup() %>%
  filter(n > 1) %>%
  left_join(
    refs %>% distinct(ItemID_Ref, Nom, Annee, Revue_Abbrege),
    by = "ItemID_Ref",
    relationship = "many-to-many"
  ) %>%
  distinct(value_col, time_window, ItemID_Ref, nb_cit = n, .keep_all = TRUE)

top_refs_without_id <- nodes %>%
  distinct(ID_Art, value_col, time_window) %>%
  left_join(refs, by = "ID_Art", relationship = "many-to-many") %>%
  filter(ItemID_Ref == 0 & Annee != 0 & Nom != "") %>%
  group_by(value_col, time_window, Nom, Annee) %>%
  add_count() %>%
  filter(n > 1) %>%
  distinct(ID_Art, value_col, time_window, .keep_all = TRUE) %>%
  arrange(time_window, value_col, desc(n)) %>%
  group_by(time_window, value_col) %>%
  slice_head(n = 10) %>%
  ungroup() %>%
  # left_join(refs %>% distinct(ItemID_Ref, Nom, Annee, Revue_Abbrege), by = "ItemID_Ref", relationship = "many-to-many") %>%
  select(value_col, time_window, Nom, Annee, Revue_Abbrege, nb_cit = n) %>%
  distinct(value_col, time_window, Nom, Annee, .keep_all = TRUE)

rm(refs)

# Calculate nodes citations
references_cited <- references_cited %>%
  mutate(
    share_ref_cluster = n / sum(n),
    ItemID_Ref = as.character(ItemID_Ref)
  ) %>%
  distinct(
    value_col,
    time_window,
    ItemID_Ref,
    cluster_citation = n,
    share_ref_cluster
  )

graphs <- lapply(graphs, function(g) {
  g %N>%
    left_join(references_cited) %>%
    mutate(
      cluster_citation = if_else(is.na(cluster_citation), 0, cluster_citation),
      share_ref_cluster = if_else(
        is.na(share_ref_cluster),
        0,
        share_ref_cluster
      ),
      cit_from_cluster = cluster_citation / node_size
    )
})

# Adding closest sentences to each cluster
cli::cli_alert_info("Adding closest sentences...")
closest_sentences <- sentences %>%
  right_join(
    select(
      nodes,
      id_text,
      Annee_Bibliographique,
      Nom,
      Titre,
      value_col,
      time_window
    ),
    by = c("id" = "id_text"),
    relationship = "many-to-many"
  ) %>%
  distinct(
    value_col,
    time_window,
    Annee_Bibliographique,
    Nom,
    Titre,
    sentence,
    similarity_rv
  ) %>%
  group_by(value_col, time_window) %>%
  slice_max(order_by = similarity_rv, n = 15, with_ties = FALSE) %>%
  mutate(similarity_rv = round(similarity_rv, 3)) %>%
  arrange(desc(similarity_rv))


# Calculating circulation of nodes between clusters over time
cli::cli_alert_info(
  "Calculating circulation of nodes between clusters over time..."
)

alluvial_data <- networkflow::networks_to_alluv(
  graphs,
  intertemporal_cluster_column = "dynamic_cluster_leiden",
  node_id = "ID_Art",
  cluster_label_column = "value_col"
)

window_levels <- alluvial_data$window %>%
  as.integer() %>%
  unique()

cluster_origins <- vector("list", length(window_levels))
names(cluster_origins) <- window_levels
cluster_destinies <- vector("list", length(window_levels))
names(cluster_destinies) <- window_levels

for (win in window_levels) {
  window_data <- alluvial_data[window == win][, .(ID_Art, value_col, window)]
  if (win != min(window_levels)) {
    window_data <- merge(
      window_data,
      alluvial_data[
        window == (win - 1),
        .(ID_Art, previous_cluster = value_col)
      ],
      by = "ID_Art",
      all.x = TRUE
    )
    window_data[,
      previous_cluster := fifelse(
        is.na(previous_cluster),
        "New articles",
        previous_cluster
      )
    ]
    window_data[, origin := .N, by = .(previous_cluster, value_col)]
    window_data[, origin_percent := round(origin / .N, 3), by = value_col]
    cluster_origins[[as.character(win)]] <- window_data %>%
      arrange(value_col, desc(origin_percent)) %>%
      distinct(value_col, window, previous_cluster, origin_percent)
  }
  if (win != max(window_levels)) {
    window_data <- merge(
      window_data,
      alluvial_data[
        window == (win + 1),
        .(ID_Art, forward_cluster = value_col)
      ],
      by = "ID_Art",
      all.x = TRUE
    )
    window_data[,
      forward_cluster := fifelse(
        is.na(forward_cluster),
        "Disappearing articles",
        forward_cluster
      )
    ]
    window_data[, destiny := .N, by = .(forward_cluster, value_col)]
    window_data[, destiny_percent := round(destiny / .N, 3), by = value_col]
    cluster_destinies[[as.character(win)]] <- window_data %>%
      arrange(value_col, desc(destiny_percent)) %>%
      distinct(value_col, window, forward_cluster, destiny_percent)
  }
}

cluster_origins <- bind_rows(cluster_origins) %>%
  mutate(
    time_window = str_c(as.integer(window), "-", as.integer(window) + 7)
  ) %>%
  select(-window)

cluster_destinies <- bind_rows(cluster_destinies) %>%
  mutate(
    time_window = str_c(as.integer(window), "-", as.integer(window) + 7)
  ) %>%
  select(-window)

# Calculating tf-idf per cluster per time window
cli::cli_alert_info("Calculating tf-idf per cluster per time window...")
tf_idf <- networkflow::extract_tfidf(
  graphs,
  n_gram = 3,
  text_column = "Titre",
  grouping_column = "value_col",
  grouping_across_list = TRUE,
  nb_terms = 20
) %>%
  mutate(
    time_window = str_c(as.integer(list_names), "-", as.integer(list_names) + 7)
  ) %>%
  select(-list_names)

graphs <- lapply(graphs, function(graph) {
  # We change the title at the end as titles are used to compute tf_idf
  graph <- graph %>%
    activate(nodes) %>%
    mutate(
      Titre = if_else(
        !is.na(url),
        glue("<a href='{url}' target='_blank'>{Titre}</a>"),
        Titre
      )
    )
})

# rounding graph statistics:
graphs <- lapply(graphs, function(graph) {
  graph <- graph %N>%
    mutate(
      similarity_rv = round(similarity_rv, 3),
      participation_coefficient = round(participation_coefficient, 3),
      z_within = round(z_within, 3),
      cit_from_cluster = round(cit_from_cluster, 3),
      share_ref_cluster = round(share_ref_cluster, 3)
    )
})

# save all data required for the app
saveRDS(
  list(
    graphs = graphs,
    closest_sentences = closest_sentences,
    top_refs = top_refs,
    top_refs_without_id = top_refs_without_id,
    cluster_origins = cluster_origins,
    cluster_destinies = cluster_destinies,
    tf_idf = tf_idf
  ),
  here::here(data_path, "data_for_app_bibliometrics.RDS")
)
