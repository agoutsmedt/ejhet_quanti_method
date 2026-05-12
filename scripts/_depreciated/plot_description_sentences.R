# paths and packages
source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(patchwork)

# Loading Data
sentences <- read_feather(file.path(
  data_path,
  "closest_sentences_0.01_rationality_score_filtered_with_embeddings.feather"
))


# Plotting distribution of sentences over time

p1 <- sentences %>%
  count(year, name = "n_sentences") %>%
  ggplot(aes(x = year, y = n_sentences)) +
  geom_col() +
  labs(
    title = "Number of Top 1% Cited Sentences by Year",
    x = "",
    y = "Number of Sentences"
  ) +
  theme_minimal(base_size = 14)

# plotting average and median similarity over time

p2 <- sentences %>%
  group_by(year) %>%
  mutate(
    median_similarity = median(similarity_rv),
    avg_similarity = mean(similarity_rv)
  ) %>%
  ungroup() %>%
  distinct(year, avg_similarity, median_similarity) %>%
  pivot_longer(
    cols = c(avg_similarity, median_similarity),
    names_to = "similarity_type",
    values_to = "similarity_value"
  ) %>%
  ggplot(aes(
    x = year,
    y = similarity_value,
    linetype = similarity_type,
    color = similarity_type
  )) +
  geom_line() +
  scale_linetype_manual(
    name = NULL,
    values = c(avg_similarity = "solid", median_similarity = "dashed"),
    labels = c("Average", "Median")
  ) +
  scale_color_manual(
    name = NULL,
    values = c(avg_similarity = "#1b9e77", median_similarity = "#d95f02"),
    labels = c("Average", "Median")
  ) +
  labs(
    title = "Average and median similarity of top 1% cited sentences to rationality vector by year",
    x = "",
    y = "Similarity"
  ) +
  # legend at bottom
  theme_minimal(base_size = 14) +
  theme(legend.position = "bottom")

# plot both and delete x axis from 1
p1_clean <- p1 +
  theme(
    axis.title.x = element_blank(),
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank()
  )

plot <- p1_clean / p2 + plot_layout(heights = c(1, 1))


# Saving plot
ggsave(
  filename = file.path(
    image_path_temp,
    "description_sentences_over_time.png"
  ),
  plot = plot,
  width = 10,
  height = 8,
  dpi = 300
)
