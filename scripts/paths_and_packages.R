if (!"pacman" %in% rownames(installed.packages())) {
  install.packages("pacman")
}

library(pacman)

pacman::p_load(
  here,
  RSQLite,
  DBI,
  duckdb,
  dbplyr,
  data.table,
  tidyverse,
  stringi,
  glue,
  cli,
  tidyfast,
  tidytext,
  arrow,
  cld2,
  ggrepel,
  RColorBrewer,
  ggraph,
  ggalluvial,
  hrbrthemes, # nice themes for ggplot
  igraph,
  tidygraph,
  jsonlite,
  progress,
  tictoc,
  scico # nice color palettes
)

#original text path stored in google drive
if (str_detect(getwd(), "goutsmed")) {
  if (str_detect(getwd(), "agoutsmedt")) {
    data_path <- file.path(
      path.expand("~"),
      "Nextcloud",
      "ejhet_project"
    )
    jstor_data_path <- file.path(
      path.expand("~"),
      "Nextcloud",
      "jstor"
    )
    jstor_raw_data <- file.path(path.expand("~"), "data", "jstor") # I'm storing the raw data in a different folder because it's heavy.

    wos_data_path <- file.path(
      path.expand("~"),
      "data",
      "wos"
    )

    elsevier_data_path <- file.path(
      path.expand("~"),
      "Nextcloud",
      "Research",
      "data",
      "elsevier"
    )
    project_path <- path.expand("~/r_github_projects/history_labor_economics/")
  } else {
    data_path <- file.path(path.expand("~"), "data", "ejhet_project")
    jstor_data_path <- file.path(path.expand("~"), "data", "jstor")
    jstor_raw_data <- jstor_data_path
    wos_data_path <- file.path(path.expand("~"), "data", "wos")
    elsevier_data_path <- file.path(path.expand("~"), "data", "elsevier")
    embeddings_data <- file.path(path.expand("~"), "data", "econ_embeddings")
  }
} else if (str_detect(getwd(), "D:/Dropbox/8")) {
  data_path <- "D:/Dropbox/8-Projets Quanti/1-R_Projects/Data/ejhet_quanti_method"
  general_data_path <- "D:/Dropbox/8-Projets Quanti/1-R_Projects/Data/1-General_data"
} else if (str_detect(getwd(), "E:/Dropbox/8")) {
  data_path <- "E:/Dropbox/8-Projets Quanti/1-R_Projects/Data/ejhet_quanti_method"
  general_data_path <- "E:/Dropbox/8-Projets Quanti/1-R_Projects/Data/1-General_data"
} else {
  if (str_detect(getwd(), "github_p")) {
    data_path <- "C:/cloud/data/ejhet_project"
    jstor_raw_data <- "D:/jstor"
    jstor_data_path <- "D:/jstor"
    wos_data_path <- "D:/wos"
    istex_data <- "D:/istex"
    istex_data_path <- "D:/istex"
    elsevier_data <- "D:/elsevier"
    elsevier_data_path <- "D:/elsevier"
    embeddings_data <- "D:/econ_embeddings"
  } else {
    if (str_detect(getwd(), "github_w")) {
      data_path <- "C:/cloud/data/ejhet_project"
      jstor_raw_data <- "D:/jstor"
      jstor_data_path <- "D:/jstor"
      wos_data_path <- "D:/wos"
      istex_data <- "D:/istex"
      istex_data_path <- "D:/istex"
      elsevier_data <- "D:/elsevier"
      elsevier_data_path <- "D:/elsevier"
      embeddings_data <- "D:/econ_embeddings"
    }
  }
}


image_path <- here::here("paper", "images")
image_path_temp <- here::here("pictures")

# increasing parallelization for data.table
setDTthreads(percent = 20)

# load functions file

invisible(lapply(
  sort(list.files(
    here::here("scripts", "functions"),
    full.names = TRUE,
    pattern = "\\.R$"
  )),
  source
))
