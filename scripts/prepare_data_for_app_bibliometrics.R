# Loading data
complete_graphs <- FALSE

if(complete_graphs){
  graphs <- readRDS(here::here(
    data_path,
    "networks_1960_2014_10_year_windows_0.1_rationality_score.RDS"
  ))
  
  labels <- readRDS(here::here(
    data_path,
    "label_ai_1960_2014_10_year_windows_0.1_rationality_score.RDS"
  ))
} else {
  graphs <- readRDS(here::here(data_path, "networks_1960_2014_10_year_windows_0.1_rationality_score_with_roles.RDS"))
}

match_jstor_wos <- readRDS(here::here(data_path, "final_match.RDS")) %>%
  filter(!is.na(id_match_final)) %>%
  distinct(url_jstor = id_jstor, ID_Art = id_match_final) %>%
  mutate(
    id_jstor = str_extract(url_jstor, "\\/[0-9]+$") %>% str_remove(., "/"),
    ID_Art = as.character(ID_Art)
  ) %>%
  distinct(ID_Art, .keep_all = TRUE)

sentences <- read_rds(here::here(
  data_path,
  "closest_sentences_0.01_filtered_rationality_score.rds"
)) %>%
  bind_rows() %>%
  left_join(
    match_jstor_wos,
    by = c("id" = "id_jstor"),
    relationship = "many-to-many"
  )


# Getting the most representative sentence per article

article_sentences <- sentences %>%
  group_by(ID_Art) %>%
  slice_max(order_by = similarity, n = 1, with_ties = FALSE) %>%
  select(ID_Art, sentence, similarity)

# add labels to the list of graphs
if(complete_graphs){
graphs <- lapply(graphs, function(graph) {
  
  graph <- graph %>% 
    activate(nodes) %>% 
    left_join(labels, by = c("dynamic_cluster_leiden" = "id_col")) %>%
    left_join(match_jstor_wos, by = c("ID_Art" = "ID_Art")) %>%
    left_join(article_sentences, by = c("ID_Art" = "ID_Art")) %>%
    arrange(desc(node_size)) %>% 
    rename(color = main_colors) %>% 
    mutate(nodes_tooltip = paste0(Nom, " \\(", Annee_Bibliographique, "\\) ", Titre) %>% 
             str_replace_all(., "[:punct:]", " ") %>% 
             str_squish(),
           value_col = if_else(is.na(value_col), dynamic_cluster_leiden, value_col))
  
  graph <- graph %>% 
    activate(edges) %>%
    rename(color = color_edges)
  
})

# Calculating Guimerà–Amaral roles
#' - P tells you the scope of a node’s connections (local vs cross-cluster).
#' - z tells you the intensity of a node’s position inside its cluster (hub vs peripheral).
#' - Together they classify each paper’s role: insider, bridge, local hub, or global connector.
graphs <- lapply(graphs, function(graph) {
  cli::cli_alert_info("Calculating Guimerà–Amaral roles for graph {graph %N>% pull(time_window) %>% unique()} with {gorder(graph)} nodes and {gsize(graph)} edges.")
  total_strength <- strength(graph, vids = V(graph), mode = "all", weights = E(graph)$weight)
  
  # Helper: for a node i, return a named vector of strength to each neighbor community
  .community_strength_i <- function(i){
    ei <- incident(graph, i, mode = "all")
    if(length(ei) == 0) return(numeric(0))
    w  <- E(graph)[ei]$weight
    # other endpoint of each incident edge
    ends_i <- ends(graph, ei, names = FALSE)
    other  <- ifelse(ends_i[,1] == i, ends_i[,2], ends_i[,1])
    comms  <- V(graph)$cluster_leiden[other]
    tapply(w, comms, sum)
  }
  
  # 2) Weighted participation coefficient
  #    P_i = 1 - sum_c ( s_ic / s_i )^2   where s_ic is strength to community c
  P <- sapply(seq_len(gorder(graph)), function(i){
    if(total_strength[i] > 0){
      cs <- .community_strength_i(i)
      if(length(cs) > 0) {                           # keep your small-degree filter
        1 - sum((cs / total_strength[i])^2)
      } else {
        NA_real_
      }
    } else {
      NA_real_
    }
  })
  
  # 3) Within-module strength z-score
  # z_i = ( s_i^in - mean_s^in_cluster ) / sd_s^in_cluster
  # where s_i^in = sum of weights from i to nodes in its own cluster
  own_comm <- V(graph)$cluster_leiden
  s_in <- sapply(seq_len(gorder(graph)), function(i){
    ei <- incident(graph, i, mode = "all")
    if(length(ei) == 0) return(0)
    ends_i <- ends(graph, ei, names = FALSE)
    other  <- ifelse(ends_i[,1] == i, ends_i[,2], ends_i[,1])
    mask   <- own_comm[other] == own_comm[i]
    if(!any(mask)) return(0)
    sum(E(graph)[ei][mask]$weight)
  })
  
  # compute z within each community
  z <- numeric(gorder(graph))
  for(comm in unique(own_comm)){
    idx   <- which(own_comm == comm)
    mu    <- mean(s_in[idx])
    sdv   <- sd(s_in[idx])
    if(is.na(sdv) || sdv == 0) {
      z[idx] <- 0
    } else {
      z[idx] <- (s_in[idx] - mu) / sdv
    }
  }
  
  # 4) Attach metrics and classify nodes by Guimerà–Amaral roles
  graph <- graph %N>%
    mutate(
      total_strength = total_strength,
      participation_coefficient = P,
      z_within = z,
      role = dplyr::case_when(
        z_within <  2.5 & participation_coefficient <= 0.05 ~ "ultra-peripheral",
        z_within <  2.5 & participation_coefficient <= 0.62 ~ "peripheral",
        z_within <  2.5 & participation_coefficient <= 0.80 ~ "connector",
        z_within <  2.5                                       ~ "kinless",
        z_within >= 2.5 & participation_coefficient <= 0.30 ~ "provincial hub",
        z_within >= 2.5 & participation_coefficient <= 0.75 ~ "connector hub",
        TRUE                                                ~ "kinless hub"
      )
    )
})

# rounding graph statistics:
graphs <- lapply(graphs, function(graph) {
  graph <- graph %N>%
    mutate(
      similarity = round(similarity, 3),
      participation_coefficient = round(participation_coefficient, 3),
      z_within = round(z_within, 3)
    )
})

}

# Adding references
nodes <- map(graphs, ~ . %N>% as_tibble()) %>%
  bind_rows() %>%
  mutate(
    value_col = if_else(is.na(value_col), dynamic_cluster_leiden, value_col),
    ID_Art = as.integer(ID_Art),
    Titre = if_else(
      !is.na(url_jstor),
      glue("<a href='{url_jstor}' target='_blank'>{Titre}</a>"),
      Titre
    )
  )

refs <- open_dataset(
  here::here(wos_data_path, "all_ref.parquet"),
  format = "parquet"
) %>%
  filter(ID_Art %in% nodes$ID_Art) %>%
  select(ID_Art, ItemID_Ref, Annee, Nom, Revue_Abbrege) %>%
  collect()

top_refs <- nodes %>%
  distinct(ID_Art, value_col, time_window) %>%
  left_join(refs, by = "ID_Art", relationship = "many-to-many") %>%
  filter(ItemID_Ref != 0) %>%
  group_by(value_col, time_window, ItemID_Ref) %>%
  summarise(n = n(), .groups = "drop") %>%
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

# Adding closest sentences to each cluster
closest_sentences <- sentences %>%
  mutate(ID_Art = as.integer(ID_Art)) %>%
  right_join(
    select(
      nodes,
      ID_Art,
      Annee_Bibliographique,
      Nom,
      Titre,
      value_col,
      time_window
    ),
    by = c("ID_Art" = "ID_Art"),
    relationship = "many-to-many"
  ) %>%
  distinct(
    value_col,
    time_window,
    Annee_Bibliographique,
    Nom,
    Titre,
    sentence,
    similarity
  ) %>%
  group_by(value_col, time_window) %>%
  slice_max(order_by = similarity, n = 15, with_ties = FALSE) %>%
  mutate(similarity = round(similarity, 3)) %>%
  arrange(desc(similarity))


# Calculating circulation of nodes between clusters over time
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
    time_window = str_c(as.integer(window), "-", as.integer(window) + 9)
  ) %>%
  select(-window)

cluster_destinies <- bind_rows(cluster_destinies) %>%
  mutate(
    time_window = str_c(as.integer(window), "-", as.integer(window) + 9)
  ) %>%
  select(-window)

# Calculating tf-idf per cluster per time window
tf_idf <- networkflow::extract_tfidf(
  graphs,
  n_gram = 3,
  text_column = "Titre",
  grouping_column = "value_col",
  grouping_across_list = TRUE,
  nb_terms = 20
) %>%
  mutate(
    time_window = str_c(as.integer(list_names), "-", as.integer(list_names) + 9)
  ) %>%
  select(-list_names)

graphs <- lapply(graphs, function(graph) {
  # We change the title at the end as titles are used to compute tf_idf
  graph <- graph %>%
    activate(nodes) %>%
    mutate(
      Titre = if_else(
        !is.na(url_jstor),
        glue("<a href='{url_jstor}' target='_blank'>{Titre}</a>"),
        Titre
      )
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
