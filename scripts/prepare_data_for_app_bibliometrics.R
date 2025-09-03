# Loading data

graphs <- readRDS(here::here(
  data_path,
  "networks_1960_2014_8_year_windows_0.1_rationality_score.RDS"
))

labels <- readRDS(here::here(
  data_path,
  "label_ai_1960_2014_8_year_windows_0.1_rationality_score.RDS"
  ))

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
  "closest_sentences_0.01_filtered_rationality_score_window_5.rds"
)) %>%
  bind_rows() %>%
  filter(publication_year > 1959) %>% 
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
# Apply to all graphs (optionally parallelize with future.apply)
graphs <- lapply(graphs, function(g) {
  m <- compute_role_fast(g, comm_attr = "cluster_leiden", weight_attr = "weight")
  g %N>% mutate(
    total_strength = m$total_strength,
    participation_coefficient = m$participation_coefficient,
    z_within = m$z_within
  )
})

#' The last thing to do is to choose a threshold which depends of the distribution of all our
#' z and P values. The original paper used z = 2.5 and P = 0.62 and 0.80 for non-hubs, but
#' it should be adapted to our data.
# choose_role_thresholds <- function(z, P, hub_q = 0.975, k_nonhub = 4, k_hub = 3) {
#   stopifnot(length(z) == length(P))
#   z  <- z[is.finite(z)]; P <- P[is.finite(P)]
#   if (!length(z)) stop("empty z")
#   
#   hub_thr <- unname(stats::quantile(z, hub_q, na.rm = TRUE))
#   
#   nonhub_P <- P[z <  hub_thr]
#   hub_P    <- P[z >= hub_thr]
#   
#   get_breaks <- function(x, k, fallback) {
#     if (length(x) >= k && length(unique(x)) >= k) {
#       km <- stats::kmeans(x, centers = k, iter.max = 100)
#       centers <- sort(as.numeric(km$centers))
#       sort((centers[-k] + centers[-1]) / 2)         # midpoints between centers
#     } else fallback
#   }
#   
#   nonhub_brks <- get_breaks(nonhub_P, k_nonhub, c(0.05, 0.62, 0.80))
#   hub_brks    <- get_breaks(hub_P,    k_hub,    c(0.30, 0.75))
#   
#   list(hub_z = hub_thr, nonhub_P = nonhub_brks, hub_P = hub_brks)
# }

# Extract data for all our graphs to choose thresholds
all_graphs_data <- map(graphs, ~ . %N>% as_tibble()) %>% 
  bind_rows() %>%
  select(ID_Art, z_within, participation_coefficient)
thr <- choose_role_thresholds(z = all_graphs_data$z_within,
                              P = all_graphs_data$participation_coefficient)

graphs <- lapply(graphs, function(graph) {
graph <- graph %N>%
  dplyr::mutate(
    role = dplyr::case_when(
      z_within <  thr$hub_z & participation_coefficient <= thr$nonhub_P[1] ~ "ultra-peripheral",
      z_within <  thr$hub_z & participation_coefficient <= thr$nonhub_P[2] ~ "peripheral",
      z_within <  thr$hub_z & participation_coefficient <= thr$nonhub_P[3] ~ "connector",
      z_within <  thr$hub_z                                                ~ "kinless",
      z_within >= thr$hub_z & participation_coefficient <= thr$hub_P[1]    ~ "provincial hub",
      z_within >= thr$hub_z & participation_coefficient <= thr$hub_P[2]    ~ "connector hub",
      TRUE                                                                 ~ "kinless hub"
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

# Adding references
cli::cli_alert_info("Adding references...")
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
cli::cli_alert_info("Adding closest sentences...")
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
cli::cli_alert_info("Calculating circulation of nodes between clusters over time...")
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
  here::here("app", "data_for_app_bibliometrics.RDS")
)
