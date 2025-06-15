######## Moved to building Jstor database project

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Matching function ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

perform_record_matching <- function(jstor_art_matching_dt = jstor_art_matching,
                                    wos_art_matching_dt = wos_art_matching,
                                    matching_variable = c("title_cleaned", "year"),
                                    match_suffix = "match_1",
                                    id_jstor_col = "id_jstor",
                                    id_wos_col = "id_wos") {
  
  # Define column names
  cols_from_match <- c(id_jstor_col, id_wos_col)
  id_match_col_name <- paste0(id_wos_col, "_", match_suffix) # e.g., id_wos_match_1
  id_stat_col_name <- paste0("share_matching_", match_suffix) # e.g., share_matching_match_1
  match_check_col_name <- paste0("is_", match_suffix, "_true") # e.g., is_match_1_true
  duplication_rate_stat_col_name <- paste0("duplication_rate", match_suffix) # e.g., share_matching_match_1
  
  # Create tables
  jstor_filtered_prep <- copy(jstor_art_matching_dt[, .SD, .SDcols = c(id_jstor_col, matching_variable)])
  wos_filtered_prep <- copy(wos_art_matching_dt[, .SD, .SDcols = c(id_wos_col, matching_variable)])
  
  # Process Jstor data
  jstor_filtered <- na.omit(jstor_filtered_prep, cols = matching_variable)
  jstor_filtered[, paste_match := do.call(paste, .SD), .SDcols = matching_variable]
  jstor_filtered <- jstor_filtered[, .SD, .SDcols = c(id_jstor_col, "paste_match")]
  jstor_filtered <- unique(jstor_filtered)
  
  # Process WoS data
  wos_filtered <- na.omit(wos_filtered_prep, cols = matching_variable)
  wos_filtered[, paste_match := do.call(paste, .SD), .SDcols = matching_variable]
  wos_filtered <- wos_filtered[, .SD, .SDcols = c(id_wos_col, "paste_match")]
  wos_filtered <- unique(wos_filtered)
  
  # Match
  matched_ids <- merge(jstor_filtered, 
                       wos_filtered, 
                       all.x = TRUE, by = "paste_match")
  jstor_matched_stats <- merge(jstor_art_matching_dt, 
                               matched_ids[, .SD, .SDcols = c(id_jstor_col, id_wos_col)], 
                               all.x = TRUE, by = "id_jstor")
  
  
  # Statistics table
  output_stat_dt <- jstor_matched_stats[, .SD, .SDcols = c(id_jstor_col, id_wos_col)]
  # Match check
  output_stat_dt[, (match_check_col_name) := 1]
  output_stat_dt[is.na(id_wos), (match_check_col_name) := 0]
  output_stat_dt[, (id_stat_col_name) := sum(get(match_check_col_name)) / .N * 100]
  # Match check
  output_stat_dt[,(duplication_rate_stat_col_name):=round((output_stat_dt[,.N]-jstor_art[,.N])/output_stat_dt[,.N]*100,2)]
  
  # Change name of ids_wos
  output_stat_dt <- output_stat_dt[, (id_match_col_name) := get(id_wos_col)]
  output_stat_dt <- output_stat_dt[, (id_wos_col) := NULL]
  print(paste0("We matched ", round(output_stat_dt[, .SD, .SDcols = c(id_stat_col_name)][1],2)," % of jstor articles in WoS"))
  print(paste0("With", round(output_stat_dt[, .SD, .SDcols = c(duplication_rate_stat_col_name)][1],2)," of duplications"))
  return(output_stat_dt)
}


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Intro ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

require(here)
source(here("scripts", "paths_and_packages.R"))

# Common info between the two db: 
# - year of publication
# - title
# - journal
# - volume
# - issues 
# - page begin
# - page end

# jstor
jstor_art <- readRDS(here(data_path, "full_metadata_journals.RDS"))
jstor_art[,identifier:=NULL]
jstor_art[,creator:=NULL]
jstor_art[,language:=NULL]
jstor_art[,tdmCategory:=NULL]
jstor_art[,sourceCategory:=NULL]
jstor_art[,outputFormat:=NULL]
jstor_art[,keyphrase:=NULL]

jstor_art <- jstor_art %>% rename(
  year = publicationYear, 
  journal = isPartOf,
  issue = issueNumber,
  volume = volumeNumber,
  page_start = pageStart,
  page_end = pageEnd,
  id_jstor = id
)

jstor_art <- jstor_art[year>=1945]
jstor_art <- jstor_art[year<=2000]
jstor_art <- jstor_art[docSubType=="research-article"]
jstor_art <- unique(jstor_art)

# wos
wos_art <- arrow::read_parquet(here(general_data_path,"all_art.parquet"), arrow.unsafe_metadata = TRUE)
journal_wos <- fread(here(general_data_path,"all_journals.csv"))
issue_wos <- fread(here(general_data_path,"revueID.csv"))

wos_art <- merge(wos_art, journal_wos[,.(Code_Revue, Revue, Code_Discipline)], all.x = TRUE, by = "Code_Revue")
wos_art <- merge(wos_art, issue_wos[,.(IssueID, Volume, Numero)], all.x = TRUE, by = "IssueID")

wos_art <- wos_art %>% rename(
  year = Annee_Bibliographique, 
  title = Titre,
  journal = Revue,
  issue = Numero,
  volume = Volume,
  page_start = Page_Debut,
  page_end = Page_Fin,
  id_wos = ID_Art
)

wos_art <- wos_art[year>=1945]
wos_art <- wos_art[year<=2000]

# some filters
jstor_art[,language_title := cld2::detect_language(title)] 
english_art <- jstor_art[language_title=="en"]$id_jstor


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Normalize corpora ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
## Cleaning NAs ##
cols_to_clean <- c("year", "title", "journal", "issue", "volume", "page_start", "page_end")
values_to_na <- c("[NULL]", "NULL", "<NA>", "", " ", "0")
for (col_name in cols_to_clean) {
  wos_art[, (col_name) := as.character(get(col_name))]
  jstor_art[, (col_name) := as.character(get(col_name))]
  wos_art[get(col_name) %in% values_to_na, (col_name) := NA_character_]
  jstor_art[get(col_name) %in% values_to_na, (col_name) := NA_character_]
}

## Titles ####
# remove special characters that might diminish the chances of matching, we will avoid false positive by selecting a threshold with the length of titles
jstor_art[,title_cleaned := title]
wos_art[,title_cleaned := title]

jstor_art[,title_cleaned := tolower(title_cleaned)]
wos_art[,title_cleaned := tolower(title_cleaned)]

jstor_art[,title_cleaned := str_replace_all(title_cleaned, "[^[:alnum:]]", " ")]
wos_art[,title_cleaned := str_replace_all(title_cleaned, "[^[:alnum:]]", " ")]

jstor_art[,title_cleaned := str_squish(title_cleaned)]
wos_art[,title_cleaned := str_squish(title_cleaned)]

# add variable for unique titles
jstor_art[,n_occurence_title := .N, title_cleaned]
wos_art[,n_occurence_title := .N, title_cleaned]

jstor_art[n_occurence_title==1 ,title_unique := title_cleaned]
wos_art[n_occurence_title==1 ,title_unique := title_cleaned]

## Journals ####
jstor_art[,journal_cleaned := journal]
wos_art[,journal_cleaned := journal]

jstor_art[,journal_cleaned := stringi::stri_trans_general(journal_cleaned, "Latin-ASCII")] # accented character into non-accented (é into e)
wos_art[,journal_cleaned := stringi::stri_trans_general(journal_cleaned, "Latin-ASCII")]

jstor_art[,journal_cleaned := tolower(journal_cleaned)]
wos_art[,journal_cleaned := tolower(journal_cleaned)]

jstor_art[,journal_cleaned := str_replace_all(journal_cleaned, "[^[:alnum:]]", " ")]
wos_art[,journal_cleaned := str_replace_all(journal_cleaned, "[^[:alnum:]]", " ")]

jstor_art[,journal_cleaned := str_replace_all(journal_cleaned, "&", " and ")] # change & in and
wos_art[,journal_cleaned := str_replace_all(journal_cleaned, "&", " and ")]

jstor_art[,journal_cleaned := str_replace_all(journal_cleaned, "\\bthe\\b", " ")]
wos_art[,journal_cleaned := str_replace_all(journal_cleaned, "\\bthe\\b", " ")]

jstor_art[,journal_cleaned := str_squish(journal_cleaned)]
wos_art[,journal_cleaned := str_squish(journal_cleaned)]

jstor_art[,.N,journal][,.N]
jstor_art[,.N,journal_cleaned][,.N] # we lose only one journal with our cleaning, and it is an error from jstor db
wos_art[,.N,journal][,.N]
wos_art[,.N,journal_cleaned][,.N] 

# checking journal match
n_journal_match <- merge(jstor_art[,.N,journal_cleaned], wos_art[,.N,journal_cleaned], all.x = TRUE, by = "journal_cleaned")
print(paste0("We matched ", round(n_journal_match[!is.na(N.y),.N,N.y][,.N]/jstor_art[,.N,journal][,.N]*100,2), "% of jstor journals"))
big_journals_we_miss <- n_journal_match[is.na(N.y)][order(-N.x)]

# some manual cleaning 
wos_art[journal=="OXFORD ECONOMIC PAPERS-NEW SERIES", journal_cleaned:= "oxford economic papers"]
wos_art[journal=="JAHRBUCHER FUR NATIONALOKONOMIE UND STATISTIK", journal_cleaned:= "jahrbucher fur nationalokonomie und statistik journal of economics and statistics"]
wos_art[journal=="FINANZARCHIV", journal_cleaned:= "finanzarchiv public finance analysis"]
wos_art[journal=="WELTWIRTSCHAFTLICHES ARCHIV-REVIEW OF WORLD ECONOMICS", journal_cleaned:= "weltwirtschaftliches archiv"]

# this one is particularly funny because even the econlit database is not in accordance with itself so we corrected manually
wos_art[journal=="JOURNAL OF INSTITUTIONAL AND THEORETICAL ECONOMICS-ZEITSCHRIFT FUR DIE GESAMTE STAATSWISSENSCHAFT", journal_cleaned:= "zeitschrift fur die gesamte staatswissenschaft journal of institutional and theoretical economics"]
jstor_art[journal_cleaned=="journal of institutional and theoretical economics jite zeitschrift fur die gesamte staatswissenschaft", journal_cleaned:= "zeitschrift fur die gesamte staatswissenschaft journal of institutional and theoretical economics"]


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Matching ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
jstor_art_matching <- copy(jstor_art)
jstor_art_stat_matching <- jstor_art_matching[,.(id_jstor)]
wos_art_matching <- copy(wos_art)

## matching_1: journal + volume + issue + page_start + year + page_end####
match_1 <- perform_record_matching(matching_variable = c("journal_cleaned", "volume", "issue", "year", "page_start", "page_end"),
                                   match_suffix = "match_1")
## matching_2: exact titles when no double titles exists in the DB ####
match_2 <- perform_record_matching(matching_variable = c("title_unique"),
                                   match_suffix = "match_2")
## matching_3: title + year ####
match_3 <- perform_record_matching(matching_variable = c("title_cleaned", "year", "page_start"),
                                   match_suffix = "match_3")
## matching_4: journal + volume + issue + page_start + year ####
match_4 <- perform_record_matching(matching_variable = c("journal_cleaned", "volume", "issue", "year", "page_start"),
                                   match_suffix = "match_4")

## matching_5: fuzzy_matching (not done) ####
jstor_fuzzy <- jstor_art_matching[,.(id_jstor, title_unique)]
wos_fuzzy <- wos_art_matching[,.(id_wos, title_unique)]

all_matches <- list()
word_match <- list()
ratio_treshold <- 0.9

# for (i in 1:nrow(jstor_fuzzy)) {
#   all_matches <- list()
#   
#   for (j in 1:nrow(wos_fuzzy)) {
#     
#     title_jstor <- jstor_fuzzy[i][,title_unique]
#     id <- jstor_fuzzy[i][,id_jstor]
#     title_wos <- wos_fuzzy[j][,title_unique]
#     
#     ratio <- fuzz_ratio(title_jstor, title_wos)
#     
#     word_match[[length(word_match) + 1]] <- data.frame(
#       title_jstor = title_jstor,
#       id_jstor = id,
#       title_wos = title_wos,
#       ratio = ratio
#     )
#  word_match_df <- rbindlist(word_match)
#  match <- word_match_df[order(-ratio)][ratio>=ratio_treshold][1]
#  
#   }
# }

## Collecting stats ####
final_match <- purrr::reduce(
  list(
    match_1, 
    match_2, 
    match_3,
    match_4), 
  merge, by = c('id_jstor'), all = T)

final_match[!is.na(id_wos_match_4), id_match_final := id_wos_match_4]
final_match[!is.na(id_wos_match_3), id_match_final := id_wos_match_3]
final_match[!is.na(id_wos_match_2), id_match_final := id_wos_match_2]
final_match[!is.na(id_wos_match_1), id_match_final := id_wos_match_1]
final_match[, share_match_final := (final_match[,.N] - final_match[is.na(id_match_final),.N])/final_match[,.N]*100]

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Final stats ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
print(paste0("We matched ", round(final_match[,share_match_final][1],2)," % of jstor articles in WoS"))
print(paste0("Including ", round((final_match[,.N]-jstor_art[,.N])/final_match[,.N]*100,2)," % with ambiguous matching"))
stats_for_english_matching <- final_match[id_jstor %in% english_art]
stats_for_english_matching[, share_match_final := (stats_for_english_matching[,.N] - stats_for_english_matching[is.na(id_match_final),.N])/stats_for_english_matching[,.N]*100]
print(paste0("We matched ", round(stats_for_english_matching[,share_match_final][1],2)," % of jstor articles classified as english by the db"))

plot_year <- merge(final_match, jstor_art[,.(id_jstor, year)], all.x=TRUE)
plot_year[,id_match_true:=0]
plot_year[!is.na(id_match_final),id_match_true:=1]
plot_year[id_match_true==1, id_match_var_graph:="MATCH"]
plot_year[id_match_true==0, id_match_var_graph:="NO MATCH"]

ggplot(plot_year[,.(id_match_var_graph, year)], aes(x = year, fill = id_match_var_graph)) +
  geom_bar(position = "fill",  width = 0.7) + # position="fill" creates the proportional stacking
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1), # Angle x-axis labels if many years
    legend.position = "top"
  )

plot_year <- merge(final_match, jstor_art[,.(id_jstor, year)], all.x=TRUE)
plot_year[,id_match_true:=0]
plot_year[!is.na(id_match_final),id_match_true:=1]
plot_year[id_match_true==1, id_match_var_graph:="MATCH"]
plot_year[id_match_true==0, id_match_var_graph:="NO MATCH"]

ggplot(plot_year[,.(id_match_var_graph, year)], aes(x = year, fill = id_match_var_graph)) +
  geom_bar(position = "fill",  width = 0.7) + # position="fill" creates the proportional stacking
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1), # Angle x-axis labels if many years
    legend.position = "top"
  )

plot_journal <- merge(final_match, jstor_art[,.(id_jstor, journal_cleaned)], all.x=TRUE)
plot_journal[,id_match_true:=0]
plot_journal[!is.na(id_match_final),id_match_true:=1]
plot_journal[id_match_true==1, id_match_var_graph:="MATCH"]
plot_journal[id_match_true==0, id_match_var_graph:="NO MATCH"]
plot_journal[, n_art_journal:= .N, journal_cleaned]
plot_journal[,order_x_axis := sum(id_match_true)/n_art_journal, journal_cleaned]

ggplot(plot_journal, aes(x = reorder(journal_cleaned, order_x_axis), fill = id_match_var_graph)) +
  geom_bar(position = "fill",  width = 0.7) + # position="fill" creates the proportional stacking
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(hjust = 0.5, face = "bold"),
    axis.text.x = element_text(angle = 45, hjust = 1), # Angle x-axis labels if many years
    legend.position = "top"
  )
