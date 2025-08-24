
# Load paths and packages defined elsewhere
source(file.path("scripts", "paths_and_packages.R"))

# Plan sémantique (jouet) avec UNIQUEMENT des mots (pas d'expressions)
library(tidyverse)
set.seed(123)

# Centres thématiques (coords fictives)
centers <- tribble(
  ~group,                   ~cx,  ~cy,
  "Core rationality",        0.0,  0.0,
  "Choice theory",           2.2,  0.8,
  "Rational expectations",   3.0, -1.0,
  "Behavioral economics",   -2.2,  0.6,
  "Game theory",             1.0,  2.2
)

# Mots (unigrammes) liés au projet
words <- tribble(
  ~word,           ~group,
  "rational",      "Core rationality",
  "rationality",   "Core rationality",
  "agent",         "Core rationality",
  "coherence",     "Core rationality",
  "utility",       "Choice theory",
  "preferences",   "Choice theory",
  "optimization",  "Choice theory",
  "axioms",        "Choice theory",
  "expectations",  "Rational expectations",
  "forecasting",   "Rational expectations",
  "information",   "Rational expectations",
  "equilibrium",   "Rational expectations",
  "bounded",       "Behavioral economics",
  "heuristics",    "Behavioral economics",
  "biases",        "Behavioral economics",
  "satisficing",   "Behavioral economics",
  "Nash",          "Game theory",
  "strategy",      "Game theory",
  "payoff",        "Game theory",
  "dominance",     "Game theory"
)

# Placement autour du centre de groupe (petit jitter)
df <- words %>%
  left_join(centers, by = "group") |> 
  mutate(
    x = cx + runif(n(), -0.8, 0.8),
    y = cy + runif(n(), -0.8, 0.8)
  )

# Plot
ggplot(df, aes(x, y, color = group)) +
  geom_point(data = centers, aes(cx, cy, color = group),
             size = 2, alpha = 0.15, inherit.aes = FALSE) +
  geom_point(size = 1, alpha = 0.5) +
  geom_text(aes(label = word), nudge_y = 0.12, size = 3, show.legend = FALSE) +
  ggsci::scale_color_npg("nrc", alpha = 0.8) +
  # increase x and y limits to avoid cutting text
  labs(
    x = NULL, y = NULL, color = NULL
  ) +
  xlim(-4, 4) +
  theme_light(base_size = 12) +
  # legend at bottom
  theme(legend.position = "bottom") +
  theme(
    # delete y and x number axis 
    axis.text.x = element_blank(),
    axis.text.y = element_blank(),
    panel.grid = element_blank()
  ) + 
  # legent on two lines
  guides(color = guide_legend(nrow = 2, byrow = TRUE))
  

ggsave(file.path("pictures", "fake_semantic_space_words_in_2D.png"),
       width = 6, height = 5, dpi = 300)
