if(! "pacman" %in% rownames(installed.packages())) {
  install.packages("pacman")
}

library(pacman)

p_load(RSQLite,
       DBI,
       dplyr,
       dbplyr,
       data.table,
       tidyverse,
       stringr,
       stringi,
       glue,
       cli,
       tidyfast,
       tidytext,
       word2vec,
       arrow,
       cld2,
       ggrepel,
       RColorBrewer,
       ggalluvial,
       ggraph,
       tidygraph,
       igraph,
       DescTools,
       jsonlite,
       progress,
       tictoc,
       ollamar)

#original text path stored in google drive 
if(str_detect(getwd(), "goutsmed")){
  if(str_detect(getwd(), "agoutsmedt")){
    data_path <- file.path(path.expand("~"), "Nextcloud", "Research", "data", "jstor")
    jstor_raw_data <- file.path(path.expand("~"), "data", "jstor") # I'm storing the raw data in a different folder because it's heavy.
  } else {
    data_path <- file.path(path.expand("~"), "data", "jstor")
    jstor_raw_data <- data_path
  }
} else if (str_detect(getwd(), "D:/Dropbox/8")){
  data_path <- "D:/Dropbox/8-Projets Quanti/1-R_Projects/Data/ejhet_quanti_method"
  general_data_path <- "D:/Dropbox/8-Projets Quanti/1-R_Projects/Data/1-General_data"
} else if (str_detect(getwd(), "E:/Dropbox/8")){
  data_path <- "E:/Dropbox/8-Projets Quanti/1-R_Projects/Data/ejhet_quanti_method"
  general_data_path <- "E:/Dropbox/8-Projets Quanti/1-R_Projects/Data/1-General_data"
} else {
  if(str_detect(getwd(), "Admin")) {
    data_path <- "C:/Users/Admin/MEGA/data/jstor"
    jstor_raw_data <- data_path # I'm supposing you're not doing the same for this data
  } else {
    if(str_detect(getwd(), "thomd")) {
      data_path <- "C:/Users/thomd/MEGA/data/jstor"
      jstor_raw_data <- data_path
    }}
}
print(paste("The path for data is", data_path))

# increasing parallelization for data.table
setDTthreads(percent = 20)
