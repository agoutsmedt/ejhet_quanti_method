#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Intro ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Titre / id / ref or new_id2 / Revue_Abbrege for books
# Von Neumann, J., & Morgenstern, O. (1944). Theory of Games and Economic Behavior. 25387792 / THEORY GAMES EC BEHA
# Allais, M. (1953). "Le Comportement de l'Homme Rationnel devant le Risque: Critique des Postulats et Axiomes de l'École Américaine." Econometrica. / 31113069 / 49148
# Friedman, M. (1953). "The Methodology of Positive Economics." In Essays in Positive Economics. 10526583 / Revue_Abbrege=="ESSAYS POSITIVE EC"
# Savage, L. J. (1954). The Foundations of Statistics. 22072376 / FDN STAT
# Simon, H. A. (1955). "A Behavioral Model of Rational Choice." The Quarterly Journal of Economics. / 34984336 / 147083
# Becker, G. S. (1968). "Crime and Punishment: An Economic Approach." Journal of Political Economy. / 37794648 / 802523
# Akerlof, G. A. (1970). "The Market for 'Lemons': Quality Uncertainty and the Market Mechanism." The Quarterly Journal of Economics. / 38435704 / 76538
# Tversky, A., & Kahneman, D. (1974). "Judgment under Uncertainty: Heuristics and Biases." Science.
# Lucas, R. E. (1976). "Econometric Policy Evaluation: A Critique." Carnegie-Rochester Conference Series on Public Policy. / 41379225 / 3179152
# Kahneman, D., & Tversky, A. (1979). "Prospect Theory: An Analysis of Decision under Risk." Econometrica. / 43187584 / 45628     
# Muth, J. F. (1961). Rational expectations and the theory of price movements. Econometrica: journal of the Econometric Society, 315-335. / 35865922 / 1163215



require(here)
source(here("scripts", "paths_and_packages.R"))

# matching bd
matching <- readRDS(here(data_path, "final_match.RDS"))

# Similarity scores
rationality_score <- readRDS(here(data_path, "rationality_similarity_scores.RDS"))

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

# wos
wos_art <- arrow::read_parquet(here(general_data_path,"all_art.parquet"), arrow.unsafe_metadata = TRUE)
journal_wos <- fread(here(general_data_path,"all_journals.csv"))
issue_wos <- fread(here(general_data_path,"revueID.csv"))

wos_art <- merge(wos_art, journal_wos[,.(Code_Revue, Revue, Code_Discipline)], all.x = TRUE, by = "Code_Revue")
wos_art <- merge(wos_art, issue_wos[,.(IssueID, Volume, Numero)], all.x = TRUE, by = "IssueID")

wos_art <- wos_art[Annee_Bibliographique>=1945]
wos_art <- wos_art[Annee_Bibliographique<=2018]

# list of manual articles (wos)
relevant_art_manual_ids <- c("31113069", "34984336", "37794648", "38435704", "43187584", "41379225", "35865922")
relevant_art_manual_ids_ref <- c("49148", "147083", "802523", "76538", "45628", "3179152", "1163215")

# list of manual articles (jstor)
relevant_art_manual_jstor_ids <- matching[id_match_final %in% relevant_art_manual_ids]

# refs
wos_refs <- arrow::read_parquet(here(general_data_path,"all_ref.parquet"), arrow.unsafe_metadata = TRUE)
wos_refs_filtered <- wos_refs[ItemID_Ref %in% relevant_art_manual_ids_ref | 
                                         Revue_Abbrege=="ESSAYS POSITIVE EC" |
                                         Revue_Abbrege=="THEORY GAMES EC BEHA" |
                                         Revue_Abbrege=="FDN STAT"]
wos_refs_filtered <- wos_refs_filtered[,ItemID_Ref:=as.character(ItemID_Ref)]

# books
wos_refs_filtered[Revue_Abbrege=="ESSAYS POSITIVE EC", ItemID_Ref:="Friedman 1953"]
wos_refs_filtered[Revue_Abbrege=="THEORY GAMES EC BEHA", ItemID_Ref:="VNM 1944"]
wos_refs_filtered[Revue_Abbrege=="FDN STAT", ItemID_Ref:="Savage 1954"]

# citations
wos_citations <- merge(wos_refs_filtered, wos_art[,.(Annee_Bibliographique, ID_Art)], by = "ID_Art", all.x = TRUE)
wos_citations <- merge(wos_citations, wos_art[,.N,Annee_Bibliographique], by = "Annee_Bibliographique", all.x = TRUE)
wos_citations <- wos_citations %>% rename(n_art_year_tot = N)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Rationality score analysis ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

ggplot(rationality_score[,.N,.(jstor_id, mean_similarity)], aes(x=mean_similarity)) + 
  geom_histogram(aes(y=..density..), colour="black", fill="white", bins = 100)+
  geom_density(alpha=.2, fill="#FF6666") 

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Citation analysis ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
citations_selected_articles <- wos_citations[,.N,.(ItemID_Ref, Annee_Bibliographique, n_art_year_tot)]
citations_selected_articles[,share_citations:=N/n_art_year_tot]
citations_selected_articles <- citations_selected_articles[!is.na(Annee_Bibliographique) & !is.na(share_citations)]

citations_selected_articles[,label:=ItemID_Ref]
citations_selected_articles[ItemID_Ref=="49148", label:="Allais 1953"]
citations_selected_articles[ItemID_Ref=="147083", label:="Simon 1955"]
citations_selected_articles[ItemID_Ref=="802523", label:="Becker 1968"]
citations_selected_articles[ItemID_Ref=="76538", label:="Akerlof 1970"]
citations_selected_articles[ItemID_Ref=="3179152", label:="Lucas 1976"]
citations_selected_articles[ItemID_Ref=="45628", label:="KT 1979"]
citations_selected_articles[ItemID_Ref=="1163215", label:="Muth 1961"]

ggplot(citations_selected_articles, aes(x=Annee_Bibliographique, y=share_citations, group=ItemID_Ref, color=ItemID_Ref)) +
  geom_smooth(method="auto", se=FALSE, fullrange=FALSE, level=0.95, span = 0.25)+
  theme(axis.text.x = element_text(angle = 90, vjust = 0.75)) +
  scale_x_continuous("Years") +
  scale_y_continuous("Share of citations") +
  # coord_cartesian(ylim = c(0,NA), xlim = c(NA, 2022)) +
  scale_color_discrete(guide = FALSE) +
  geom_label_repel(aes(label = label), data = citations_selected_articles[Annee_Bibliographique==max(citations_selected_articles$Annee_Bibliographique)-1], nudge_x = 1, segment.color = NA) +
  theme_minimal() 

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Citation analysis ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

mean_rationality_table <- merge(jstor_art[,.(year, id_jstor)], rationality_score[,.(jstor_id, mean_similarity)], by.x = "id_jstor", by.y = "jstor_id")
mean_rationality_table <- unique(mean_rationality_table)
mean_rationality_table[,mean_similarity_year := mean(mean_similarity), year]

ggplot(mean_rationality_table, aes(x=year, y=mean_similarity_year)) +
  geom_smooth(method="auto", se=FALSE, fullrange=FALSE, level=0.95, span = 0.75)+
  theme(axis.text.x = element_text(angle = 90, vjust = 0.75)) +
  scale_x_continuous("Years") +
  scale_y_continuous("Mean of rationality similarity") +
  theme_minimal() 
