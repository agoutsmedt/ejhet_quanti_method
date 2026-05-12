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
  mutate(decade = ifelse(decade < 1920, "1900s-1910s", str_c(decade, "s"))) %>%
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
  geom_col(fill = color_roma_blue) +
  facet_wrap(~decade, scales = "free") +
  coord_flip() +
  scale_x_reordered() +
  scale_y_continuous(
    labels = scales::label_number(scale_cut = scales::cut_short_scale())
  ) +
  labs(x = NULL, y = "Frequency") +
  theme_custom() +
  theme(
    axis.text.x = element_text(size = 18),
    # text of facet labels
    strip.text = element_text(size = 18)
  )

print(p)

# ----------------------------------------------------------
# Save
# ----------------------------------------------------------
ggsave(
  here::here(image_path, "top_neighbor_words_decades.png"),
  plot = p,
  width = 16,
  height = 10,
  units = "in",
  dpi = 300
)
