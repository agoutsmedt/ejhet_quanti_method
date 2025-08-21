# LOADING DATA AND LIBRARIES----------------------
source(file.path("scripts", "_functions.R"))
source(file.path("scripts", "paths_and_packages.R"))

pacman::p_load(shiny, shinycssloaders)

graphs <- readRDS(here::here(data_path, "networks_1970_2014_10_year_windows_0.1_rationality_score.RDS"))
labels <- readRDS(here::here(data_path, "label_ai_1970_2014_10_year_windows_0.1_rationality_score.RDS"))

# rationality_score_original <- read_feather(here::here(data_path, "similarities_by_document.feather")) %>% 
#   as.data.table()


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


# # Similarity scores
# rationality_score_original[,id:=paste0("http://www.jstor.org/stable/", id)]
# rationality_score <- rationality_score_original %>% rename(jstor_id = id, similarity = cosine_sim_centered) %>% select(jstor_id, similarity) %>% unique()
# rationality_score <- merge(matching, rationality_score, all.x = TRUE, by.x = "id_jstor", by.y = "jstor_id")
# rationality_score <- rationality_score[!is.na(id_match_final) & !is.na(similarity),.(id_match_final, similarity)] %>% rename(ID_Art = id_match_final)
# rationality_score[,ID_Art:=as.character(ID_Art)]
# rationality_score[,similarity:=mean(similarity), ID_Art]
# rationality_score <- unique(rationality_score)
# 
# # similarity scores to network
# tbl_networks <- lapply(tbl_networks, function(tbl)(tbl %>% activate(nodes) %>% 
#                                                    left_join(rationality_score, by = "ID_Art")))

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
