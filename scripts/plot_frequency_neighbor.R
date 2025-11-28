# ----------------------------------------------------------
# Load data
# ----------------------------------------------------------
source(file.path("scripts", "paths_and_packages.R"))

input <- file.path(data_path, "rationality_neighbors_by_year.feather")
neighbors <- read_feather(input) |> as.data.table()

# ----------------------------------------------------------
# Remove stopwords
# ----------------------------------------------------------
data("stop_words")
stopwords <- unique(stop_words$word)

neighbors <- neighbors[!(tolower(word) %in% stopwords)]

# ----------------------------------------------------------
# Aggregate by decade
# ----------------------------------------------------------
decadal <- neighbors %>%
  mutate(decade = year - (year %% 10)) %>%
  # merge 1900s and 1910s
  mutate(decade = ifelse(decade < 1920, "1900-1910s", as.character(decade))) %>%
  summarise(
    N_decade = sum(count),
    .by = c("word", "decade")
  )

# filter any before 1900 and 2009
decadal <- decadal %>%
  filter(decade >= 1900 & decade <= 2009)

df_top <- decadal %>%
  filter(decade >= 1900 & decade <= 2009) %>%
  group_by(decade) %>%
  slice_max(N_decade, n = 5) %>%
  ungroup() %>%
  mutate(word = reorder_within(word, N_decade, decade))

p <- ggplot(df_top, aes(x = word, y = N_decade)) +
  geom_col(fill = "grey50", color = "grey20") +
  facet_wrap(~decade, scales = "free") +
  coord_flip() +
  scale_x_reordered() +
  labs(x = NULL, y = "Frequency") +
  theme_light(base_size = 28) +
  theme(
    strip.background = element_blank(),
    strip.text = element_text(colour = "black")
  )

print(p)

# ----------------------------------------------------------
# Save
# ----------------------------------------------------------
ggsave(
  here::here(image_path, "top_neighbor_words_decades.png"),
  plot = p,
  width = 60,
  height = 50,
  units = "cm",
  dpi = 300
)
