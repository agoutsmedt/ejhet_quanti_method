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
# Lucas Jr, R. E. (1972). Expectations and the Neutrality of Money. Journal of economic theory, 4(2), 103-124. / 39162373 / 214939
# Fama, E. F. (1970). Efficient capital markets: A review of theory and empirical work. The journal of Finance, 25(2), 383-417. 38367949 / 366345


require(here)
source(here("scripts", "paths_and_packages.R"))

# matching bd
matching <- readRDS(here(data_path, "final_match.RDS"))

# Similarity scores
rationality_score_original <- arrow::read_feather(here(data_path, "similarities_fulltexts.feather")) %>% as.data.table()
rationality_score_original[,id:=paste0("http://www.jstor.org/stable/", id)]
rationality_score <- rationality_score_original %>% rename(jstor_id = id, similarity = cosine_sim_centered) %>% select(jstor_id, similarity) %>% unique()

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
wos_art <- wos_art[Annee_Bibliographique<=2015]

# list of manual articles (wos)
relevant_art_manual_ids <- c("31113069", "34984336", "37794648", "38435704", "43187584", "41379225", "35865922")
relevant_art_manual_ids_ref <- c("49148", "147083", "802523", "76538", "45628", "3179152", "1163215", "214939", "366345")

# list of manual articles (jstor)
relevant_art_manual_jstor_ids <- matching[id_match_final %in% relevant_art_manual_ids]

# refs
wos_refs <- arrow::read_parquet(here(general_data_path,"all_ref.parquet"), arrow.unsafe_metadata = TRUE)
wos_refs_filtered <- wos_refs[ItemID_Ref %in% relevant_art_manual_ids_ref | 
                                Revue_Abbrege=="ESSAYS POSITIVE EC" |
                                Revue_Abbrege=="THEORY GAMES EC BEHA" |
                                Revue_Abbrege=="FDN STAT" |
                                Revue_Abbrege=='GENERAL THEORY EMPLO' |
                                Revue_Abbrege=='GEN THEORY EMPLOYMEN']
wos_refs_filtered <- wos_refs_filtered[,ItemID_Ref:=as.character(ItemID_Ref)]

# books
wos_refs_filtered[Revue_Abbrege=="ESSAYS POSITIVE EC", ItemID_Ref:="Friedman 1953"]
wos_refs_filtered[Revue_Abbrege=="THEORY GAMES EC BEHA", ItemID_Ref:="VNM 1944"]
wos_refs_filtered[Revue_Abbrege=="FDN STAT", ItemID_Ref:="Savage 1954"]
wos_refs_filtered[Revue_Abbrege=="GENERAL THEORY EMPLO", ItemID_Ref:="Key 1936"]
wos_refs_filtered[Revue_Abbrege=="GEN THEORY EMPLOYMEN", ItemID_Ref:="Key 1936"]

# citations
wos_citations <- merge(wos_refs_filtered[ID_Art %in% wos_art[Code_Discipline==119]$ID_Art], wos_art[,.(Annee_Bibliographique, ID_Art)], by = "ID_Art", all.x = TRUE)
wos_citations <- merge(wos_citations, wos_art[Code_Discipline==119,.N,Annee_Bibliographique], by = "Annee_Bibliographique", all.x = TRUE)
wos_citations <- wos_citations %>% rename(n_art_year_tot = N)

wos_citations_top_5 <- merge(wos_refs_filtered[ID_Art %in% wos_art[Code_Revue %in% c("758", "13694", "4695", "9662", "13992")]$ID_Art], wos_art[,.(Annee_Bibliographique, ID_Art)], by = "ID_Art", all.x = TRUE)
wos_citations_top_5 <- merge(wos_citations_top_5, wos_art[Code_Revue %in% c("758", "13694", "4695", "9662", "13992"),.N,Annee_Bibliographique], by = "Annee_Bibliographique", all.x = TRUE)
wos_citations_top_5 <- wos_citations_top_5 %>% rename(n_art_year_tot = N)


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Rationality score analysis ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

# ggplot(rationality_score[,.N,.(jstor_id, mean_similarity)], aes(x=mean_similarity)) + 
#   geom_histogram(aes(y=..density..), colour="black", fill="white", bins = 100)+
#   geom_density(alpha=.2, fill="#FF6666") 

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

plot_citations <- ggplot(citations_selected_articles, aes(x=Annee_Bibliographique, y=share_citations, group=ItemID_Ref, color=ItemID_Ref)) +
  # annotate("rect", xmin = 1945, xmax = 1965, ymin = 0, ymax = Inf, fill = "#E41A1C", alpha = 0.3) +
  # annotate("rect", xmin = 1965, xmax = 1975, ymin = 0, ymax = Inf, fill = "#377EB8", alpha = 0.3) +
  # annotate("rect", xmin = 1975, xmax = 1986, ymin = 0, ymax = Inf, fill = "#4DAF4A", alpha = 0.3) +
  # annotate("rect", xmin = 1986, xmax = max(citations_selected_articles$Annee_Bibliographique), ymin = 0, ymax = Inf, fill = "#FF7F00", alpha = 0.3) +
  # geom_text(x = (1945 + 1965) / 2, y = max(citations_selected_articles$share_citations)*0.9, label = "Rise of rationality", color = "black", size = 6, fontface = "bold", inherit.aes = FALSE) +
  # geom_text(x = (1965 + 1975) / 2, y = max(citations_selected_articles$share_citations)*0.8, label = "Low-intensity conflicts", color = "black", size = 6, fontface = "bold", inherit.aes = FALSE) +
  # geom_text(x = (1975 + 1986) / 2, y = max(citations_selected_articles$share_citations)*0.9, label = "Rise of controversies", color = "black", size = 6, fontface = "bold", inherit.aes = FALSE) +
  # geom_text(x = (1986 + max(citations_selected_articles$Annee_Bibliographique)) / 2, y = max(citations_selected_articles$share_citations)*0.8, label = "Heuristics and biases", color = "black", size = 6, fontface = "bold", inherit.aes = FALSE) +
  geom_smooth(method="auto", se=FALSE, fullrange=FALSE, level=0.95, span = 0.3) +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.75)) +
  scale_x_continuous("Years") +
  scale_y_continuous("Share of citations", limit=c(0,NA), labels = scales::percent_format(accuracy = 0.01)) +
  # coord_cartesian(ylim = c(0,NA), xlim = c(NA, 2022)) +
  scale_color_manual(values=c(brewer.pal(7, name = "Dark2"), brewer.pal(7, name = "Set1")), guide = FALSE) +
  geom_label_repel(aes(label = label), data = citations_selected_articles[Annee_Bibliographique==max(citations_selected_articles$Annee_Bibliographique)-1], nudge_x = 1, segment.color = NA) +
  theme_minimal() +
  theme(panel.background = element_rect(fill = "white", color = NA),
        plot.background = element_rect(fill = "white", color = NA))
ggsave(plot=plot_citations, here(data_path,"Pictures", paste0("plot_citations.png")), width=32, height=18, units = "cm", scale = 0.7)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Citation analysis (only bounded) ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

citations_selected_articles <- wos_citations[,.N,.(ItemID_Ref, Annee_Bibliographique, n_art_year_tot)]
citations_selected_articles[,share_citations:=N/n_art_year_tot]
citations_selected_articles <- citations_selected_articles[!is.na(Annee_Bibliographique) & !is.na(share_citations)]

citations_selected_articles <- complete(citations_selected_articles, ItemID_Ref, Annee_Bibliographique) %>% as.data.table()
citations_selected_articles[is.na(share_citations),share_citations:=0]
citations_selected_articles[,label:=ItemID_Ref]
citations_selected_articles[ItemID_Ref=="49148", label:="Allais 1953"]
citations_selected_articles[ItemID_Ref=="147083", label:="Simon 1955"]
citations_selected_articles[ItemID_Ref=="76538", label:="Akerlof 1970"]
citations_selected_articles[ItemID_Ref=="45628", label:="KT 1979"]

citations_selected_articles <- citations_selected_articles[ItemID_Ref %in% c("49148", "147083", "76538", "45628")]

plot_citations_bounded <- ggplot(citations_selected_articles, 
                                 aes(x=Annee_Bibliographique, y=share_citations, group=ItemID_Ref, color=ItemID_Ref)) +
  geom_text(x = 2002+4, 
            y = max(citations_selected_articles$share_citations)*0.97, 
            label = "Kahneman Nobel", color = "black", size = 3, fontface = "bold", inherit.aes = FALSE) +
  geom_vline(xintercept = 2002, linetype="dotted", color = "black", size=0.5) +
  geom_text(x = 2001-3.5, 
            y = max(citations_selected_articles$share_citations)*0.97, 
            label = "Akerlof Nobel", color = "black", size = 3, fontface = "bold", inherit.aes = FALSE) +
  geom_vline(xintercept = 2001, linetype="dotted", color = "black", size=0.5) +
  geom_text(x = 1988, 
            y = max(citations_selected_articles$share_citations)*0.97, 
            label = "Allais Nobel", color = "black", size = 3, fontface = "bold", inherit.aes = FALSE) +
  geom_vline(xintercept = 1988, linetype="dotted", color = "black", size=0.5) +
  geom_text(x = 1978, 
            y = max(citations_selected_articles$share_citations)*0.97, 
            label = "Simon Nobel", color = "black", size = 3, fontface = "bold", inherit.aes = FALSE) +
  geom_vline(xintercept = 1978, linetype="dotted", color = "black", size=0.5) +
  geom_smooth(method="auto", se=FALSE, fullrange=FALSE, level=0.95, span = 0.3) +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.75)) +
  scale_x_continuous("Years", limit=c(1955,2015)) +
  scale_y_continuous("Share of citations", limit=c(0,NA), labels = scales::percent_format(accuracy = 0.01)) +
  scale_color_manual(values=c(brewer.pal(7, name = "Dark2"), brewer.pal(7, name = "Set1")), guide = FALSE) +
  geom_label_repel(aes(label = label), data = citations_selected_articles[Annee_Bibliographique==(max(citations_selected_articles$Annee_Bibliographique)-1)], nudge_x = 1, segment.color = NA) +
  theme_minimal() +
  theme(panel.background = element_rect(fill = "white", color = NA),
        plot.background = element_rect(fill = "white", color = NA),
        plot.title = element_text(hjust = 0.5)) +
  ggtitle("All economics")
ggsave(plot=plot_citations_bounded, here(data_path,"Pictures", paste0("plot_citations_bounded.png")), width=32, height=18, units = "cm", scale = 0.7)

#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Citation analysis (only rational) ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

citations_selected_articles <- wos_citations[,.N,.(ItemID_Ref, Annee_Bibliographique, n_art_year_tot)]
citations_selected_articles[,share_citations:=N/n_art_year_tot]
citations_selected_articles <- citations_selected_articles[!is.na(Annee_Bibliographique) & !is.na(share_citations)]

citations_selected_articles <- complete(citations_selected_articles, ItemID_Ref, Annee_Bibliographique) %>% as.data.table()
citations_selected_articles[is.na(share_citations),share_citations:=0]
citations_selected_articles[,label:=ItemID_Ref]
citations_selected_articles[ItemID_Ref=="214939", label:="Lucas 1972"]
citations_selected_articles[ItemID_Ref=="802523", label:="Becker 1968"]
citations_selected_articles[ItemID_Ref=="1163215", label:="Muth 1961"]
citations_selected_articles[ItemID_Ref=="366345", label:="Fama 1970"]

citations_selected_articles <- citations_selected_articles[ItemID_Ref %in% c("214939", "802523", "1163215", "366345", "Friedman 1953", "VNM 1944","Savage 1954")]

plot_citations_rational <- ggplot(citations_selected_articles, 
                                  aes(x=Annee_Bibliographique, y=share_citations, group=ItemID_Ref, color=ItemID_Ref)) +
  geom_smooth(method="auto", se=FALSE, fullrange=FALSE, level=0.95, span = 0.3) +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.75)) +
  scale_x_continuous("Years", limit=c(1945,2015)) +
  scale_y_continuous("Share of citations", limit=c(0,NA), labels = scales::percent_format(accuracy = 0.01)) +
  scale_color_manual(values=c(brewer.pal(7, name = "Dark2"), brewer.pal(7, name = "Set1")), guide = FALSE) +
  geom_label_repel(aes(label = label), data = citations_selected_articles[Annee_Bibliographique==(max(citations_selected_articles$Annee_Bibliographique)-1)], nudge_x = 1, segment.color = NA) +
  theme_minimal() +
  theme(panel.background = element_rect(fill = "white", color = NA),
        plot.background = element_rect(fill = "white", color = NA),
        plot.title = element_text(hjust = 0.5)) +
  ggtitle("All economics")
ggsave(plot=plot_citations_rational, here(data_path,"Pictures", paste0("plot_citations_rational.png")), width=32, height=18, units = "cm", scale = 0.7)



#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Citation analysis top 5####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#

citations_selected_articles <- wos_citations_top_5[,.N ,.(ItemID_Ref, Annee_Bibliographique, n_art_year_tot)]
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

plot_citations <- ggplot(citations_selected_articles, aes(x=Annee_Bibliographique, y=share_citations, group=ItemID_Ref, color=ItemID_Ref)) +
  # annotate("rect", xmin = 1945, xmax = 1965, ymin = 0, ymax = Inf, fill = "#E41A1C", alpha = 0.3) +
  # annotate("rect", xmin = 1965, xmax = 1975, ymin = 0, ymax = Inf, fill = "#377EB8", alpha = 0.3) +
  # annotate("rect", xmin = 1975, xmax = 1986, ymin = 0, ymax = Inf, fill = "#4DAF4A", alpha = 0.3) +
  # annotate("rect", xmin = 1986, xmax = max(citations_selected_articles$Annee_Bibliographique), ymin = 0, ymax = Inf, fill = "#FF7F00", alpha = 0.3) +
  # geom_text(x = (1945 + 1965) / 2, y = max(citations_selected_articles$share_citations)*0.9, label = "Rise of rationality", color = "black", size = 6, fontface = "bold", inherit.aes = FALSE) +
  # geom_text(x = (1965 + 1975) / 2, y = max(citations_selected_articles$share_citations)*0.8, label = "Low-intensity conflicts", color = "black", size = 6, fontface = "bold", inherit.aes = FALSE) +
  # geom_text(x = (1975 + 1986) / 2, y = max(citations_selected_articles$share_citations)*0.9, label = "Rise of controversies", color = "black", size = 6, fontface = "bold", inherit.aes = FALSE) +
  # geom_text(x = (1986 + max(citations_selected_articles$Annee_Bibliographique)) / 2, y = max(citations_selected_articles$share_citations)*0.8, label = "Heuristics and biases", color = "black", size = 6, fontface = "bold", inherit.aes = FALSE) +
  geom_smooth(method="auto", se=FALSE, fullrange=FALSE, level=0.95, span = 0.3) +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.75)) +
  scale_x_continuous("Years") +
  scale_y_continuous("Share of citations", limit=c(0,NA), labels = scales::percent_format(accuracy = 0.01)) +
  # coord_cartesian(ylim = c(0,NA), xlim = c(NA, 2022)) +
  scale_color_manual(values=c(brewer.pal(7, name = "Dark2"), brewer.pal(7, name = "Set1")), guide = FALSE) +
  geom_label_repel(aes(label = label), data = citations_selected_articles[Annee_Bibliographique==max(citations_selected_articles$Annee_Bibliographique)-1], nudge_x = 1, segment.color = NA) +
  theme_minimal() +
  theme(panel.background = element_rect(fill = "white", color = NA),
        plot.background = element_rect(fill = "white", color = NA))
ggsave(plot=plot_citations, here(data_path,"Pictures", paste0("plot_citations_top_5.png")), width=32, height=18, units = "cm", scale = 0.7)


#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
# Citation analysis (only bounded top 5) ####
#%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%#
citations_selected_articles <- wos_citations_top_5[,.N,.(ItemID_Ref, Annee_Bibliographique, n_art_year_tot)]
citations_selected_articles[,share_citations:=N/n_art_year_tot]
citations_selected_articles <- citations_selected_articles[!is.na(Annee_Bibliographique) & !is.na(share_citations)]

citations_selected_articles <- citations_selected_articles[ItemID_Ref %in% c("49148", "147083", "76538", "45628")]

citations_selected_articles <- complete(citations_selected_articles, ItemID_Ref, Annee_Bibliographique) %>% as.data.table()
citations_selected_articles[is.na(share_citations),share_citations:=0]
citations_selected_articles[,label:=ItemID_Ref]
citations_selected_articles[ItemID_Ref=="49148", label:="Allais 1953"]
citations_selected_articles[ItemID_Ref=="147083", label:="Simon 1955"]
citations_selected_articles[ItemID_Ref=="76538", label:="Akerlof 1970"]
citations_selected_articles[ItemID_Ref=="45628", label:="KT 1979"]

plot_citations_bounded_top5 <- ggplot(citations_selected_articles, 
                                      aes(x=Annee_Bibliographique, y=share_citations, group=ItemID_Ref, color=ItemID_Ref)) +
  # geom_text(x = 2002+4, 
  #           y = max(citations_selected_articles[$share_citations)*0.6, 
  #           label = "Kahneman Nobel", color = "black", size = 4, fontface = "bold", inherit.aes = FALSE) +
  geom_vline(xintercept = 2002, linetype="dotted", color = "black", size=0.5) +
  # geom_text(x = 2001-3.5, 
  #           y = max(citations_selected_articles$share_citations)*0.6, 
  #           label = "Akerlof Nobel", color = "black", size = 4, fontface = "bold", inherit.aes = FALSE) +
  geom_vline(xintercept = 2001, linetype="dotted", color = "black", size=0.5) +
  # geom_text(x = 1988, 
  #           y = max(citations_selected_articles$share_citations)*0.6, 
  #           label = "Allais Nobel", color = "black", size = 4, fontface = "bold", inherit.aes = FALSE) +
  geom_vline(xintercept = 1988, linetype="dotted", color = "black", size=0.5) +
  # geom_text(x = 1978, 
  #           y = max(citations_selected_articles$share_citations)*0.6, 
  #           label = "Simon Nobel", color = "black", size = 4, fontface = "bold", inherit.aes = FALSE) +
  geom_vline(xintercept = 1978, linetype="dotted", color = "black", size=0.5) +
  geom_smooth(method="auto", se=FALSE, fullrange=FALSE, level=0.95, span = 0.3) +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.75)) +
  scale_x_continuous("Years", limit=c(1955,2015)) +
  scale_y_continuous("Share of citations", limit=c(0,NA), labels = scales::percent_format(accuracy = 0.01)) +
  scale_color_manual(values=c(brewer.pal(7, name = "Dark2"), brewer.pal(7, name = "Set1")), guide = FALSE) +
  geom_label_repel(aes(label = label), data = citations_selected_articles[Annee_Bibliographique==(max(citations_selected_articles$Annee_Bibliographique-1))], nudge_x = 1, segment.color = NA) +
  theme_minimal() +
  theme(panel.background = element_rect(fill = "white", color = NA),
        plot.background = element_rect(fill = "white", color = NA),
        plot.title = element_text(hjust = 0.5)) +
  ggtitle("Top 5 economics journals")
ggsave(plot=plot_citations_bounded_top5, here(data_path,"Pictures", paste0("plot_citations_bounded_top_5.png")), width=32, height=18, units = "cm")

combined <- patchwork::wrap_plots(plot_citations_bounded/plot_citations_bounded_top5 + patchwork::plot_layout(axes = "collect_x"))
ggsave(plot=combined, here(data_path,"Pictures", paste0("plot_citations_bounded_combined.png")), width=32, height=18, units = "cm", scale = 0.8)
ggsave(plot=combined, here(data_path,"Pictures", paste0("plot_citations_bounded_combined_high.png")), width=25, height=18, units = "cm", scale = 0.8)

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



