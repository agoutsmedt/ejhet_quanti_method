# LOADING DATA AND LIBRARIES----------------------
source(file.path("scripts", "paths_and_packages.R"))

graphs <- readRDS(here::here(jstor_raw_data, "networks_1970_2014_10_year_windows_0.15_rationality_score.RDS"))
labels <- readRDS(here::here(jstor_raw_data, "label_ai_1970_2014_10_year_windows_0.15_rationality_score.RDS"))


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
    
  return(graph)
})


launch_network_app(
    graph_tbl = graphs, 
    cluster_id = "value_col", 
    cluster_information = c("Titre", "Annee_Bibliographique", "Nom"),
    cluster_tooltip = "Click on cluster to see more information",
    node_id = "ID_Art",
    node_tooltip = "nodes_tooltip",
    node_size = "node_size",
    color = "color",
    layout = NULL # already layouted
)


