# ===========================================================================
# Shared figure theme and default palette (all paper plots)
# base_size = 30 matches ggsave(width=16, height=10, dpi=300) -> ~9pt at 12cm
# ===========================================================================

theme_custom <- function(base_size = 30, base_family = "sans") {
  ggplot2::theme_light(
    base_size = base_size,
    base_family = base_family
  ) %+replace%
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      strip.background = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(colour = "black"),
      legend.background = ggplot2::element_blank(),
      legend.key = ggplot2::element_blank()
    )
}

# Single accent colour from roma (position 0.2 = warm red, used for unfaceted bars)
color_roma_red <- scico::scico(10, palette = "roma")[1]
color_roma_blue <- scico::scico(10, palette = "roma")[8]
