source(file.path("scripts", "paths_and_packages.R"))


df <- read_feather(here::here(jstor_raw_data, "nearest_neighbors_bert-base-uncased.feather"))

targets <- c("rational", "rationality", "both")

for (target in targets) {
  
  if (target == "both") {
    df_filtered <- df %>%
      filter(target_word %in% c("rational", "rationality"))
  } else {
    df_filtered <- df %>%
      filter(target_word == target)
  }
  
  # Préparation des données
  df_long <- df_filtered %>%
    mutate(year = as.numeric(year), decade = floor(year / 10) * 10) %>%
    unnest(nearest_neighbors) %>% 
    filter(decade > 1890) 
  

  
  # Fréquence des mots par décennie
  decade_freq <- df_long %>%
    group_by(decade, nearest_neighbors) %>%
    summarise(freq = n(), .groups = "drop")
  
  # Garder les top 10 mots par décennie
  top_decades <- decade_freq %>%
    group_by(decade) %>%
    slice_max(order_by = freq, n = 10) %>%
    ungroup %>% 
    mutate(nearest_neighbors = reorder_within(nearest_neighbors, freq, decade)) %>%
    ungroup
  
  # Bar plot
  gg <- ggplot(top_decades, aes(x = freq, y = nearest_neighbors)) +
    geom_col(show.legend = FALSE, fill = "lightblue") +
    facet_wrap(~decade, ncol = 3, scales = "free") +
    labs(
      title = paste0("Top 10 Nearest Neighbors by Decade: ", target),
      x = "Frequency",
      y = NULL
    ) +
    scale_y_reordered() +
    theme_light(base_size = 10) +
    theme(
      strip.text = element_text(size = 14, face = "bold"),
      axis.text.y = element_text(size = 8)
    )

# Sauvegarde
  ggsave(
    here::here(image_path, paste0("bar_neighbors_", target, "_by_decade.png")),
    plot = gg,
    width = 12,
    height = 8,
    dpi = 300
  )
}
