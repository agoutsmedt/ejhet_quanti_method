# LOADING DATA AND LIBRARIES----------------------
source(file.path("scripts", "_functions.R"))
source(file.path("scripts", "paths_and_packages.R"))

pacman::p_load(shiny, shinycssloaders)

graphs <- readRDS(here::here(data_path, "networks_1960_2014_10_year_windows_0.1_rationality_score.RDS"))
labels <- readRDS(here::here(data_path, "label_ai_1960_2014_10_year_windows_0.1_rationality_score.RDS"))

# add labels to the list of graphs

graphs <- lapply(graphs, function(graph) {
  
  graph <- graph %>% 
    activate(nodes) %>% 
    left_join(labels, by = c("dynamic_cluster_leiden" = "id_col")) %>%
    arrange(desc(node_size)) %>% 
    rename(color = main_colors) %>% 
    mutate(nodes_tooltip = paste0(Nom, " \\(", Annee_Bibliographique, "\\) ", Titre) %>% str_remove_all(., "[:punct:]"),
           value_col = if_else(is.na(value_col), dynamic_cluster_leiden, value_col)) 
  
  graph <- graph %>% 
    activate(edges) %>%
    rename(color = color_edges)
})

# Adding references
nodes <- map(graphs, ~ . %N>% as_tibble()) %>% 
  bind_rows() %>% 
  mutate(value_col = if_else(is.na(value_col), dynamic_cluster_leiden, value_col),
         ID_Art = as.integer(ID_Art)) %>% 
  distinct(ID_Art, value_col, time_window)

refs <- read_parquet(here::here(wos_data_path, "all_ref.parquet"), as_data_frame = FALSE) %>% 
  filter(ID_Art %in% nodes$ID_Art) %>% 
  select(ID_Art, ItemID_Ref, Annee, Nom, Revue_Abbrege) %>% 
  collect()

top_refs <- nodes %>% 
  left_join(refs, by = "ID_Art", relationship = "many-to-many") %>% 
  filter(ItemID_Ref != 0) %>% 
  group_by(value_col, time_window, ItemID_Ref) %>% 
  summarise(n = n(), .groups = "drop") %>% 
  arrange(time_window, value_col, desc(n)) %>% 
  group_by(time_window, value_col) %>% 
  slice_head(n = 10) %>% 
  ungroup() %>% 
  filter(n > 1) %>%
  left_join(refs %>% distinct(ItemID_Ref, Nom, Annee, Revue_Abbrege), by = "ItemID_Ref", relationship = "many-to-many") %>% 
  distinct(value_col, time_window, ItemID_Ref, nb_cit = n, .keep_all = TRUE) 

top_refs_without_id <- nodes %>%  
  left_join(refs, by = "ID_Art", relationship = "many-to-many") %>% 
  filter(ItemID_Ref == 0 & Annee != 0 & Nom != "") %>%
  group_by(value_col, time_window, Nom, Annee) %>% 
  summarise(n = n(), .groups = "drop") %>% 
  arrange(time_window, value_col, desc(n)) %>% 
  group_by(time_window, value_col) %>% 
  slice_head(n = 10) %>% 
  ungroup() %>% 
  filter(n > 1) %>%
 # left_join(refs %>% distinct(ItemID_Ref, Nom, Annee, Revue_Abbrege), by = "ItemID_Ref", relationship = "many-to-many") %>% 
  distinct(value_col, time_window, Nom, Annee, nb_cit = n) 

# Calculating circulation of nodes between clusters over time
alluvial_data <- networkflow::networks_to_alluv(graphs,
                                                intertemporal_cluster_column = "dynamic_cluster_leiden",
                                                node_id = "ID_Art",
                                                cluster_label_column = "value_col")

window_levels <- alluvial_data$window %>% 
  as.integer() %>% 
  unique()
cluster_origins <- vector("list", length(window_levels))
names(cluster_origins) <- window_levels
cluster_destinies <- vector("list", length(window_levels))
names(cluster_destinies) <- window_levels

for(win in window_levels){
  window_data <- alluvial_data[window == win][, .(ID_Art, value_col, window)]
  if(win != min(window_levels)) {
    window_data <- merge(window_data, 
                         alluvial_data[window == (win - 1), .(ID_Art, previous_cluster = value_col)],
                         by = "ID_Art",
                         all.x = TRUE)
    window_data[, previous_cluster := fifelse(is.na(previous_cluster), "New articles", previous_cluster)]
    window_data[, origin := .N, by = .(previous_cluster, value_col)]
    window_data[, origin_percent := round(origin/.N, 3), by = value_col]
    cluster_origins[[as.character(win)]] <- window_data %>% 
      arrange(value_col, desc(origin_percent)) %>% 
      distinct(value_col, window, previous_cluster, origin_percent)
  }
  if(win != max(window_levels)) {
    window_data <- merge(window_data, 
                         alluvial_data[window == (win + 1), .(ID_Art, forward_cluster = value_col)],
                         by = "ID_Art",
                         all.x = TRUE)
    window_data[, forward_cluster := fifelse(is.na(forward_cluster), "Disappearing articles", forward_cluster)]
    window_data[, destiny := .N, by = .(forward_cluster, value_col)]
    window_data[, destiny_percent := round(destiny/.N, 3), by = value_col]
    cluster_destinies[[as.character(win)]] <- window_data %>% 
      arrange(value_col, desc(destiny_percent)) %>% 
      distinct(value_col, window, forward_cluster, destiny_percent)
  }
}
cluster_origins <- bind_rows(cluster_origins) %>% 
  mutate(time_window = str_c(as.integer(window), "-", as.integer(window) + 9)) %>% 
  select(-window)
cluster_destinies <- bind_rows(cluster_destinies) %>% 
  mutate(time_window = str_c(as.integer(window), "-", as.integer(window) + 9)) %>% 
  select(-window)

# Calculating tf-idf per cluster per time window
tf_idf <- networkflow::extract_tfidf(graphs,
                                     n_gram = 3,
                                     text_column = "Titre",
                                     grouping_column = "value_col",
                                     grouping_across_list = TRUE,
                                     nb_terms = 10) %>% 
  mutate(time_window = str_c(as.integer(list_names), "-", as.integer(list_names) + 9)) %>% 
  select(-list_names)
  
# Lauching the app
launch_network_app(
    graph_tbl = graphs, 
    cluster_id = "value_col", 
    cluster_information = c("Titre", "Annee_Bibliographique", "Nom", "node_size"),
    cluster_tooltip = "Click on cluster to see more information",
    top_references = top_refs,
    top_references_without_id = top_refs_without_id,
    cluster_origins = cluster_origins,
    cluster_destinies = cluster_destinies,
    tf_idf_data = tf_idf,
    node_id = "ID_Art",
    node_tooltip = "nodes_tooltip",
    node_size = "node_size",
    color = "color",
    layout = NULL # already layouted
)

# to add textual values 

# retrieve text from jstor and wos  
fulltexts <- open_dataset(here(jstor_raw_data, "sentences_embeddings"), format = "feather")
abstracts <- open_dataset(here(jstor_raw_data, "Abstract_wos", "sentences_embeddings"), format = "feather")

# add representative text using rv 
graphs <- lapply(graphs, function(graph) {

  # get id 
  list_ids <- graph |> 
    activate(nodes) |> 
    as.data.frame() |> 
    select(ID_Art) |> 
    unique() |> 
    pull(ID_Art)

  fulltexts_query <- fulltexts |> 
    filter(id %in% list_ids) |> 
    collect() |> 
    select(id, sentence) |> 
    rename(fulltext = sentence,
           ID_Art = id) |> 
    # merge sentence from the same id 
    group_by(ID_Art) |>
    summarise(fulltext = paste(fulltext, collapse = ". "))

  abstracts_query <- abstracts |> 
    filter(id %in% list_ids) |> 
    select(id, sentence) |> 
    collect() |> 
    rename(abstract = sentence,
           ID_Art = id) |> 
    mutate(ID_Art = as.character(ID_Art))

  # if not empty, add fulltexts and abstracts to the graph
    graph <- graph |> 
      activate(nodes) |> 
      left_join(fulltexts_query) 

    graph <- graph |> 
      activate(nodes) |>
      left_join(abstracts_query) 
  
  return(graph)
})
