# LOADING DATA AND LIBRARIES----------------------
source(file.path("scripts", "_functions.R"))
source(file.path("scripts", "paths_and_packages.R"))

pacman::p_load(shiny, shinycssloaders)

# load graphs 
graphs <- readRDS(here::here(data_path, "networks_1970_2014_10_year_windows_0.1_rationality_score.RDS"))
labels <- readRDS(here::here(data_path, "label_ai_1970_2014_10_year_windows_0.1_rationality_score.RDS"))

# add labels to the list of graphs  
graphs <- lapply(graphs, function(graph) {
  
  graph <- graph %>% 
    activate(nodes) %>% 
    left_join(labels, by = c("dynamic_cluster_leiden" = "id_col")) %>%
    rename(color = main_colors) %>% 
    mutate(nodes_tooltip = paste0(Nom, " \\(", Annee_Bibliographique, "\\) ", Titre) %>% str_remove_all(., "[:punct:]"))
  
  graph <- graph %>% 
    activate(edges) %>%
    rename(color = color_edges)
})


launch_network_app(
    graph_tbl = graphs, 
    cluster_id = "value_col", 
    cluster_information = c("Titre", "Annee_Bibliographique", "Nom", "node_size"),
    cluster_tooltip = "Click on cluster to see more information",
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
