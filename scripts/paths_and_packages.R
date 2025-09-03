if(! "pacman" %in% rownames(installed.packages())) {
  install.packages("pacman")
}

library(pacman)

p_load(here,
       RSQLite,
       DBI,
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
     #  DescTools,
       jsonlite,
       progress,
       tictoc)

#original text path stored in google drive 
if(str_detect(getwd(), "goutsmed")){
  if(str_detect(getwd(), "agoutsmedt")){
    data_path <- file.path(path.expand("~"), "Nextcloud", "Research", "data", "jstor")
    jstor_raw_data <- file.path(path.expand("~"), "data", "jstor") # I'm storing the raw data in a different folder because it's heavy.
    wos_data_path <- file.path(path.expand("~"), "Nextcloud", "Research", "data", "wos")
    } else {
    data_path <- file.path(path.expand("~"), "data", "jstor")
    jstor_raw_data <- data_path
    wos_data_path <- file.path(path.expand("~"), "data", "wos")
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
    wos_data_path <- "C:/Users/Admin/MEGA/data/wos"
  } else {
    if(str_detect(getwd(), "thomd")) {
      data_path <- "C:/Users/thomd/MEGA/data/jstor"
      jstor_raw_data <- data_path
      wos_data_path <- "C:/Users/thomd/MEGA/data/wos"
    }}
}


image_path <- here::here("paper", "images")
image_path_temp <- here::here("pictures")


print(paste("The path for data is", data_path))

# increasing parallelization for data.table
setDTthreads(percent = 20)

# load functions file

source(here::here("scripts", "_functions.R"))


