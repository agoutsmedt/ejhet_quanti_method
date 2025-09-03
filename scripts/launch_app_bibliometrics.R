# LOADING DATA AND LIBRARIES----------------------
source(file.path("scripts", "_functions.R"))
source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(shiny, shinycssloaders)

RUN_DATA_PREPARATION <- TRUE

if (RUN_DATA_PREPARATION) {
  # Preparing data for the app
  source(file.path("scripts", "prepare_data_for_app_bibliometrics.R"))
  message("Data preparation done, you can now run the app.")
}

# load data for the app
data_app <- readRDS(here::here(data_path, "data_for_app_bibliometrics.RDS"))
list2env(data_app, envir = environment())
rm(data_app)
  
# Lauching the app
launch_network_app(
    graph_tbl = graphs, 
    cluster_id = "value_col", 
    cluster_information = c("Titre", 
                            "Annee_Bibliographique", 
                            "Nom", 
                            "sentence",
                            "node_size", 
                            "cit_from_cluster",
                            "share_ref_cluster",
                            "participation_coefficient", 
                            "z_within", 
                            "role"),
    cluster_tooltip = "Click on cluster to see more information",
    cluster_sentences = closest_sentences,
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
