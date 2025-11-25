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
# Sum by year
# → We sum them TOGETHER (before + after)
# ----------------------------------------------------------

yearly <- neighbors[, .(N_year = sum(count)), by = .(year, word)]

# ----------------------------------------------------------
# Compute decade
# ----------------------------------------------------------
yearly[, decade := floor(year / 10) * 10]

# Merge 1900 + 1910 → "1900-1910"
yearly[,
  decade := fifelse(
    decade %in% c(1900, 1910),
    "1900-1910",
    as.character(decade)
  )
]
yearly <- yearly[!decade %in% c("1900", "1910")]

# filter anything before 1900 and after 2011
yearly <- yearly[!(year > 2011 | year < 1900)]

# ----------------------------------------------------------
# Sum by decade
# ----------------------------------------------------------
decadal <- yearly[, .(N_decade = sum(N_year)), by = .(decade, word)]

# ----------------------------------------------------------
# Keep top 6 words per decade
# ----------------------------------------------------------

# remove stopwords
df_top <- decadal |>
  as_tibble() |>
  mutate(decade = paste0(decade, "s")) |>
  slice_max(order_by = N_decade, n = 6, by = decade, with_ties = FALSE) |>
  mutate(word = reorder_within(word, N_decade, decade))

# ----------------------------------------------------------
# Plot
# ----------------------------------------------------------
p <- df_top |>
  ggplot(aes(x = word, y = N_decade)) +
  geom_col(fill = "steelblue") +
  facet_wrap(~decade, scales = "free") +
  coord_flip() +
  scale_x_reordered() +
  labs(
    x = NULL,
    y = "Frequency"
  ) +
  scale_y_continuous(
    breaks = scales::breaks_pretty(n = 3),
    labels = scales::label_number()
  ) +
  theme_light(base_size = 28)

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
