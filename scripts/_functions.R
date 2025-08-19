#' Launch an Interactive Shiny App to Explore Network Graphs
#'
#' @description
#' `r lifecycle::badge("experimental")`
#'
#' This function launches an interactive Shiny application to explore one or several
#' network graphs (as `tbl_graph` or list of `tbl_graph`). If a list is passed, each
#' graph should be named according to its time window (e.g., "2010-2012"), enabling dynamic selection.
#'
#' The interface supports cluster exploration, tooltip interactivity, layout computation, and node metadata inspection.
#'
#' @param graph_tbl A `tbl_graph` object or a **named list of `tbl_graph`**, each representing a time window.
#' @param cluster_id Column name in the node data identifying clusters.
#' @param cluster_information Character vector of node metadata columns to show in the table.
#' @param cluster_tooltip Optional. Tooltip shown when hovering over cluster labels.
#' @param node_id Column name identifying node IDs.
#' @param node_tooltip Optional. Tooltip for node-level interaction.
#' @param node_size Optional. Column name used to scale node size.
#' @param color Optional. Column used to color nodes. If `NULL`, colors are generated.
#' @param layout Character. Layout algorithm passed to `networkflow::layout_networks()` (e.g., `"kk"`, `"fr"`).
#'
#' @return A Shiny app interface to interact with the network graph(s).
#' @export
launch_network_app <- function(
    graph_tbl,
    cluster_id,
    cluster_information,
    cluster_tooltip = NULL,
    node_id,
    node_tooltip = NULL,
    node_size = NULL,
    color = NULL,
    layout = "kk"
) {
  stopifnot(
    requireNamespace("shiny"),
    requireNamespace("ggiraph"),
    requireNamespace("ggplot2"),
    requireNamespace("DT"),
    requireNamespace("dplyr"),
    requireNamespace("ggraph"),
    requireNamespace("rlang"),
    requireNamespace("shinycssloaders"),
    requireNamespace("tidygraph"),
    requireNamespace("networkflow"),
    requireNamespace("cli")
  )
  
  # Validate input
  is_list_graph <- is.list(graph_tbl) && all(purrr::map_lgl(graph_tbl, ~ inherits(.x, "tbl_graph")))
  if (is_list_graph && is.null(names(graph_tbl))) {
    cli::cli_abort("The list of graphs must be named, where names correspond to time windows (e.g., '2010-2012').")
  }
  
  if (!is.null(layout)) {
    cli::cli_alert_info("Computing layout with {.fn networkflow::layout_networks} using layout = '{layout}'")
    graph_tbl <- networkflow::layout_networks(
      graphs = graph_tbl,
      node_id = node_id,
      layout = layout
    )
  }
  
  if (is.null(color)) {
    cli::cli_alert_info("Generating node colors via {.fn networkflow::color_networks}")
    graph_tbl <- networkflow::color_networks(
      graphs = graph_tbl,
      column_to_color = cluster_id,
      unique_color_across_list = FALSE
    )
    color <- "color"
  }
  
  # Symbols
  color_sym   <- rlang::sym(color)
  cluster_sym <- rlang::sym(cluster_id)
  id_sym      <- rlang::sym(node_id)
  tooltip_sym <- if (!is.null(node_tooltip)) rlang::sym(node_tooltip) else NULL
  
  # UI
  ui <- shiny::fluidPage(
    shiny::titlePanel("Network Explorer"),
    shiny::sidebarLayout(
      sidebarPanel = shiny::sidebarPanel(
        width = 3,
        if (is_list_graph) {
          shiny::selectInput("selected_graph", "Select Time Window:",
                             choices = names(graph_tbl),
                             selected = names(graph_tbl)[1])
        },
        shiny::sliderInput("min_edge_width", "Min Edge Width:", min = 0.01, max = 10, value = 0.01, step = 0.01),
        shiny::sliderInput("max_edge_width", "Max Edge Width:", min = 0.01, max = 10, value = 1, step = 0.01),
        shiny::sliderInput("min_node_size", "Min Node Size:", min = 0.1, max = 10, value = 0.5, step = 0.01),
        shiny::sliderInput("max_node_size", "Max Node Size:", min = 0.1, max = 10, value = 2, step = 0.01),
        shiny::sliderInput("label_size", "Label size", min = 0.5, max = 5, value = 2, step = 0.1)
      ),
      mainPanel = shiny::mainPanel(
        shiny::div(
          style = "border: 1px solid #ccc; padding: 10px; border-radius: 5px;",
          shinycssloaders::withSpinner(
            ggiraph::girafeOutput("network_plot", width = "100%", height = "600px")
          )
        ),
        shiny::hr(),
        shiny::h4("Documents in Selected Cluster"),
        DT::DTOutput("cluster_docs")
      )
    )
  )
  
  # Server
  server <- function(input, output, session) {
    selected_cluster <- shiny::reactiveVal(NULL)
    
    active_graph <- shiny::reactive({
      if (is_list_graph) graph_tbl[[input$selected_graph]] else graph_tbl
    })
    
    output$network_plot <- ggiraph::renderGirafe({
      g_tbl <- active_graph()
      g_tbl <- tidygraph::activate(g_tbl, "nodes")
      
      if (is.null(node_size)) {
        g_tbl <- dplyr::mutate(g_tbl, size = 1)
      } else {
        if (!(node_size %in% colnames(as.data.frame(g_tbl)))) {
          cli::cli_abort("The column specified in {.arg node_size} does not exist in the node data.")
        }
        g_tbl <- dplyr::mutate(g_tbl, size = !!rlang::sym(node_size))
      }
      
      nodes_df <- as.data.frame(tidygraph::activate(g_tbl, "nodes"))
      
      required_cols <- c(cluster_id, node_id, color, "size", "x", "y")
      missing_main <- setdiff(required_cols, colnames(nodes_df))
      missing_info <- setdiff(cluster_information, colnames(nodes_df))
      
      if (length(missing_main) > 0 || length(missing_info) > 0) {
        cli::cli_abort("Missing required columns in nodes: {paste(c(missing_main, missing_info), collapse = ', ')}")
      }
      
      # Build aesthetics for nodes
      node_aes <- list(
        x = quote(x),
        y = quote(y),
        fill = color_sym,
        size = quote(size)
      )
      if (!is.null(tooltip_sym)) {
        node_aes$tooltip <- tooltip_sym
        node_aes$data_id <- tooltip_sym
      }
      
      # Cluster label data
      label_data <- nodes_df %>%
        dplyr::group_by(!!cluster_sym) %>%
        dplyr::summarise(
          label_x = mean(x, na.rm = TRUE),
          label_y = mean(y, na.rm = TRUE),
          color = first(!!color_sym),
          cluster_label = first(!!cluster_sym),
          .groups = "drop"
        )
      
      label_aes <- list(
        x = quote(label_x),
        y = quote(label_y),
        label = quote(cluster_label),
        data_id = quote(cluster_label),
        fill = quote(color)
      )
      if (!is.null(cluster_tooltip)) {
        label_aes$tooltip <- cluster_tooltip
      }
      
      edge_width_range <- c(input$min_edge_width, input$max_edge_width)
      node_size_range  <- c(input$min_node_size, input$max_node_size)
      label_size <- input$label_size


      g <- ggraph::ggraph(g_tbl, layout = "manual", x = x, y = y) +
        ggraph::geom_edge_arc0(
          ggplot2::aes(color = !!color_sym, width = weight),
          alpha = 0.3, strength = 0.2, show.legend = FALSE
        ) +
        ggiraph::geom_point_interactive(
          mapping = do.call(ggplot2::aes, node_aes),
          shape = 21, alpha = 0.8, show.legend = FALSE
        ) +
        ggiraph::geom_label_repel_interactive(
          data = label_data,
          mapping = do.call(ggplot2::aes, label_aes),
          alpha = 0.9, fontface = "bold", show.legend = FALSE,
          size = label_size,
        ) +
        ggraph::scale_edge_width_continuous(range = edge_width_range) +
        ggplot2::scale_size_continuous(range = node_size_range) +
        ggraph::scale_edge_colour_identity() +
        ggplot2::scale_fill_identity() +
        ggplot2::theme_void()
      
      ggiraph::girafe(
        ggobj = g,
        width_svg = 10,
        height_svg = 6,
        options = list(ggiraph::opts_selection(type = "single"))
      )
    })
    
    shiny::observeEvent(input$network_plot_selected, {
      selected_cluster(input$network_plot_selected)
    })
    
    output$cluster_docs <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      nodes_df <- tidygraph::activate(g_tbl, "nodes") %>% as.data.frame()
      
      nodes_df %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(all_of(cluster_information)) %>%
        DT::datatable(options = list(pageLength = 10))
    })
  }
  
  shiny::shinyApp(ui = ui, server = server)
}



#' Automatically Label Clusters Using Ollama::generate()
#'
#' @description
#' For each cluster in a `tbl_graph` or a list of `tbl_graph`s, this function aggregates
#' selected textual node metadata, passes it to a local LLM via `ollamar::generate()`,
#' and assigns a concise label back to the cluster.
#'
#' @param graph_tbl A `tbl_graph` or a named list of `tbl_graph` objects.
#' @param cluster_id Column name used to group nodes into clusters.
#' @param cluster_information Character vector of node metadata columns to include.
#' @param model Name of the Ollama model to use (e.g., "llama3", "mistral").
#' @param max_words Maximum number of words allowed in the label (default = 5).
#'
#' @return A `tbl_graph` or list of `tbl_graphs` with `cluster_label` added to nodes.
#' @export
label_cluster_llm <- function(graph_tbl,
                              cluster_id,
                              cluster_information,
                              model = "llama3.1",
                              max_words = 5) {
  library(dplyr)
  library(tidygraph)
  library(data.table)
  library(ollamar)
  library(jsonlite)
  library(rlang)
  
  label_one_graph <- function(g) {
    g_df <- activate(g, "nodes") %>% as_tibble()
    
    if (!cluster_id %in% colnames(g_df)) stop("cluster_id not found in node data.")
    if (!all(cluster_information %in% colnames(g_df))) stop("Some cluster_information columns are missing.")
    
    cluster_ids <- unique(g_df[[cluster_id]])
    cluster_labels <- vector("list", length(cluster_ids))
    
    for (i in seq_along(cluster_ids)) {
      
      cid <- cluster_ids[i]
      cluster_data <- g_df %>% filter(!!sym(cluster_id) == cid)
      
      data_text <- cluster_data %>%
        select(all_of(cluster_information)) %>%
        mutate(across(everything(), as.character)) %>%
        mutate(row = row_number()) %>%
        pivot_longer(-row, names_to = "field", values_to = "content") %>%
        group_by(field) %>%
        summarise(values = list(na.omit(content)), .groups = "drop") %>%
        data.table::as.data.table()
      
      json_input <- toJSON(data_text, pretty = TRUE)
      
      prompt <- paste0("Here is a cluster or scientific articles in economics made using bibliographic coupling.
                       Each article is described by its metadada.
                       Using this information to name cluster using no more than 5 words.
                       Your output should start with the name of the cluster followed by a full stop.
                       Your output should only be the name of the cluster, nothing else. I insist: output only the name of the cluster.
                       Here is the data: ", json_input)
      
      label <- ollamar::generate(model = model, prompt = prompt, output = "text")
      
      cluster_labels[[i]] <- tibble(
        !!sym(cluster_id) := cid,
        cluster_label = trimws(label)
      )
    }
    
    cluster_labels_df <- bind_rows(cluster_labels)
    
    g <- g %>%
      activate(nodes) %>%
      left_join(cluster_labels_df, by = cluster_id)
    
    return(g)
  }
  
  if (inherits(graph_tbl, "list")) {
    return(lapply(graph_tbl, label_one_graph))
  } else if (inherits(graph_tbl, "tbl_graph")) {
    return(label_one_graph(graph_tbl))
  } else {
    stop("Input must be a tbl_graph or a named list of tbl_graphs.")
  }
}

