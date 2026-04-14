source(here::here("scripts", "paths_and_packages.R"))

# --- Load metadata ---
metadata <- read_feather(
  file.path(data_path, "metadata_maintext.feather"),
  col_select = c("id", "journal", "year", "id_wos_matched", "type")
)

# ============================================================
# 1. Match rate by decade (1940–2009, exclude pre-1940: 0% by
#    construction — WOS has no records that early)
# ============================================================

match_by_decade <- metadata %>%
  filter(year >= 1940, year <= 2009) %>%
  mutate(decade = paste0(floor(year / 10) * 10, "s")) %>%
  group_by(decade) %>%
  summarise(
    n_articles = n(),
    n_matched = sum(!is.na(id_wos_matched)),
    pct_matched = round(100 * n_matched / n_articles, 1)
  ) %>%
  arrange(decade)

# ============================================================
# 2. Match rate by journal — best and worst (n >= 200)
# ============================================================

match_by_journal <- metadata %>%
  group_by(journal) %>%
  summarise(
    n_articles = n(),
    n_matched = sum(!is.na(id_wos_matched)),
    pct_matched = round(100 * n_matched / n_articles, 1)
  ) %>%
  filter(n_articles >= 200) %>%
  arrange(desc(pct_matched), desc(n_articles))

# Top 15 best-matched journals
top_matched <- match_by_journal %>%
  slice_head(n = 15)

# Worst-matched: journals entirely absent from WOS (0%) —
# these are journals not indexed in WOS for this period.
# We separate them from journals with partial coverage.
unmatched_journals <- match_by_journal %>%
  filter(pct_matched == 0) %>%
  arrange(desc(n_articles)) %>%
  slice_head(n = 15)

# Journals with partial but incomplete coverage (between 10% and 90%)
partial_matched <- match_by_journal %>%
  filter(pct_matched > 10, pct_matched < 90) %>%
  arrange(desc(n_articles)) %>%
  slice_head(n = 15)

# ============================================================
# 3. Save
# ============================================================

saveRDS(match_by_decade, file.path(data_path, "wos_match_by_decade.rds"))
saveRDS(top_matched, file.path(data_path, "wos_match_top_journals.rds"))
saveRDS(
  unmatched_journals,
  file.path(data_path, "wos_match_absent_journals.rds")
)
saveRDS(partial_matched, file.path(data_path, "wos_match_partial_journals.rds"))

message("Saved: wos_match_by_decade.rds")
message("Saved: wos_match_top_journals.rds")
message("Saved: wos_match_absent_journals.rds")
message("Saved: wos_match_partial_journals.rds")

# Quick console summary
cat("=== Match by decade ===\n")
print(match_by_decade)
cat("\n=== Top 15 best-matched journals (n >= 200) ===\n")
print(top_matched)
cat("\n=== Top 15 journals absent from WOS (n >= 200) ===\n")
print(unmatched_journals)
cat("\n=== Top 15 major journals with partial WOS coverage ===\n")
print(partial_matched)
