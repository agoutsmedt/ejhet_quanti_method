# paths and packages
source(file.path("scripts", "paths_and_packages.R"))
pacman::p_load(patchwork)


df <- read_feather(file.path(
  data_path,
  "hdbscan_all_sentences_with_clusters_min_sample_1.feather"
))


# create a decade column
df <- df %>%
  mutate(decade = floor(year / 10) * 10)


# Count number of sentences per window that are going to be clustered

window_counts <- df %>%
  count(window)

p0 <- ggplot(window_counts, aes(x = window, y = n)) +
  geom_col(fill = color_roma_blue) +
  theme_custom() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(
    title = "Number of Sentences per Time Window",
    x = "Time Window",
    y = "Number of Sentences"
  )


# Plot distribution between noisy and clustered points over time
cluster_distribution <- df %>%
  mutate(is_noise = ifelse(cluster == -1, "Noise", "Clustered")) %>%
  group_by(window, is_noise) %>%
  summarise(n = n(), .groups = "drop")


p1 <- ggplot(cluster_distribution, aes(x = window, y = n, fill = is_noise)) +
  geom_col(position = "dodge") +
  theme_custom() +
  scale_fill_manual(
    values = c("Clustered" = color_roma_blue, "Noise" = color_roma_red)
  ) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),
    legend.position = "bottom"
  ) +
  labs(
    x = NULL,
    y = "Number of sentences",
    fill = "HDBSCAN Classification"
  )

ggsave(
  file.path(image_path, "hdbscan_cluster_distribution_over_time.png"),
  p1,
  width = 16,
  height = 10,
  units = "in",
  dpi = 300
)

# plot number of clusters per window

num_clusters_per_window <- df %>%
  filter(cluster != -1) %>%
  distinct(window, cluster) %>%
  count(window, name = "num_clusters")

p2 <- ggplot(num_clusters_per_window, aes(x = window, y = num_clusters)) +
  geom_col(fill = color_roma_blue) +
  theme_custom() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
  labs(
    x = NULL,
    y = "Number of clusters"
  )

ggsave(
  file.path(image_path, "hdbscan_number_of_clusters_per_window.png"),
  p2,
  width = 16,
  height = 10,
  units = "in",
  dpi = 300
)
