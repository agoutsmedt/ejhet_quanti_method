build_dynamic_networks_bb <- function(nodes,
                                      directed_edges,
                                      source_id,
                                      target_id,
                                      time_variable = NULL,
                                      time_window = NULL,
                                      backbone_method = c("statistical", "structured"),
                                      statistical_method = c("sdsm", "fdsm", "fixedfill", "fixedfrow", "fixedcol"),
                                      alpha = alpha,
                                      coupling_measure = c("coupling_angle", "coupling_strength", "coupling_similarity"),
                                      edges_threshold = 1,
                                      overlapping_window = FALSE,
                                      compute_size = FALSE,
                                      keep_singleton = FALSE,
                                      filter_components = FALSE,
                                      min_share = NULL,
                                      nb_components = NULL,
                                      verbose = TRUE) {
  
  size <- node_size <- N <- method  <-  NULL
  
  # Making sure the table is a datatable
  nodes <- data.table::data.table(nodes)
  directed_edges <- data.table::data.table(directed_edges)
  
  # Checking the methods
  backbone_methods = c("statistical", "structured")
  
  coupling_measures <- c("coupling_angle",
                         "coupling_strength",
                         "coupling_similarity")
  
  statistical_methods <- c("sdsm", "fdsm", "fixedfill", "fixedfrow", "fixedcol")
  
  
  if (length(backbone_method) > 1) {
    cli::cli_abort(
      c(
        "You did not choose any method for extracting the backbone. You have to choose between: ",
        "*" = "\"statistical\";",
        "*" = "\"structured\"."
      )
    )
  }
  
  if (!backbone_method %in% backbone_methods) {
    cli::cli_abort(
      c(
        "You did not choose any method for extracting the backbone. You have to choose between: ",
        "*" = "\"statistical\";",
        "*" = "\"structured\";"
      )
    )
  }
  
  # check various setting for the structured methods
  
  if (backbone_method == "structured") {
    
    # Checking various problems: lacking method,
    if (length(coupling_measure) > 1) {
      cli::cli_abort(
        c(
          "For structured backbone extraction, you have to choose a coupling measure among: ",
          "*" = "\"coupling_angle\";",
          "*" = "\"coupling_strength\";",
          "*" = "\"coupling_similarity\"."
        )
      )
    }
    
    if (!coupling_measure %in% coupling_measures) {
      cli::cli_abort(
        c(
          "For structured backbone extraction, you have to choose a coupling measure among: ",
          "*" = "\"coupling_angle\";",
          "*" = "\"coupling_strength\";",
          "*" = "\"coupling_similarity\"."
        )
      )
    }
    
  }
  
  # check various setting for the statistical methods
  if (backbone_method == "statistical") {
    # check if a model is given
    if (length(statistical_method) > 1) {
      cli::cli_abort(
        c(
          "For statistical backbone extraction, you have to choose a model: ",
          "*" = "\"sdsm\";",
          "*" = "\"fdsm\";",
          "*" = "\"fixedfill\".",
          "*" = "\"fixedfrow\".",
          "*" = "\"fixedcol\"."
        )
      )
    }
    
    if (!statistical_method %in% statistical_methods) {
      cli::cli_abort(
        c(
          "For statistical backbone extraction, you have to choose a model: ",
          "*" = "\"sdsm\";",
          "*" = "\"fdsm\";",
          "*" = "\"fixedfill\".",
          "*" = "\"fixedfrow\".",
          "*" = "\"fixedcol\"."
        )
      )
    }
    
    # check if alpha is given
    if (is.null(alpha)) {
      cli::cli_abort(
        "For statistical backbone extraction, you have to choose a signifiance level alpha."
      )
    }
    
  }
  
  # warning if the source_id is not unique
  if (nodes[, .N, source_id, env = list(source_id = source_id)][N > 1, .N] > 0) {
    cli::cli_alert_warning(
      "Some identifiers in your column {.field {source_id}} in your nodes table are not unique. You need only one row per node."
    )
  }
  
  # check settings for intertemporal networks
  if (!is.null(time_window) & is.null(time_variable)) {
    cli::cli_abort(
      "You cannot have a {.emph time_window} if you don't give any column with a temporal variable. Put a column in {.emph time_variable} or remove the {.emph time_window}."
    )
  }
  
  
  # VERBOSE
  
  if (verbose == TRUE) {
    if (length(statistical_method > 0))
      cli::cli_alert_info(paste(
        "We extract the network backbone using the",
        backbone_method,
        "method."
      ))
    
    if (keep_singleton == FALSE)
      cli::cli_alert_info("Keep_singleton == FALSE: removing the nodes that are alone with no edge. \n\n")
  }
  
  
  # CHECKING THE DATA
  
  # NODES 
  nodes_coupling <- data.table::copy(nodes)
  nodes_coupling[, source_id := as.character(source_id), env = list(source_id = source_id)]
  
  if (is.null(time_variable)) {
    time_variable <- "fake_column"
    nodes_coupling[, time_variable := 1, env = list(time_variable = time_variable)]
  }
  
  
  if (!target_id %in% colnames(nodes_coupling) &
      compute_size == TRUE) {
    cli::cli_abort(
      "You don't have the column {.field {target_id}} in your nodes table. Set {.emph compute_size} to {.val FALSE}."
    )
  }
  
  if (compute_size == TRUE) {
    nodes_coupling[, target_id := as.character(target_id), env = list(target_id = target_id)]
  }
  
  # EDGES 
  
  edges <- data.table::copy(directed_edges)
  edges <- edges[, .SD, .SDcols = c(source_id, target_id)] # we keep only the columns we need
  edges[, c(source_id, target_id) := lapply(.SD, as.character), .SDcols = c(source_id, target_id)] # we need to have character columns
  
  
  
  ######################### Dynamics networks *********************
  
  # define the time window
  nodes_coupling <- nodes_coupling[order(time_variable), env = list(time_variable = time_variable)]
  nodes_coupling[, time_variable := as.integer(time_variable), env = list(time_variable = time_variable)]
  
  first_year <- nodes_coupling[, min(as.integer(time_variable)), env = list(time_variable = time_variable)]
  last_year <- nodes_coupling[, max(as.integer(time_variable)), env = list(time_variable = time_variable)]
  
  
  if (!is.null(time_window)) {
    if (last_year - first_year + 1 < time_window) {
      cli::cli_alert_warning(
        "Your time window is larger than the number of distinct values of {.field {time_variable}}"
      )
    }
  }
  
  if (is.null(time_window)) {
    all_years <- first_year
    time_window <- last_year - first_year + 1
  } else {
    if (overlapping_window == TRUE) {
      last_year <- last_year - time_window + 1
      all_years <- first_year:last_year
    } else {
      all_years <- seq(first_year, last_year, by = time_window)
      if (all_years[length(all_years)] + (time_window - 1) > last_year) {
        cli::cli_warn(
          "Your last network is shorter than the other(s) because the cutting by time window does not give a round count.
                The last time unity in your data is {.val {last_year}}, but the upper limit of your last time window is
                {.val {all_years[length(all_years)] + (time_window - 1)}}."
        )
      }
    }
  }
  
  # Prepare our list
  tbl_coup_list <- list()
  
  for (year in all_years) {
    nodes_of_the_year <- nodes_coupling[time_variable >= year &
                                          time_variable < (year + time_window), env = list(time_variable = time_variable, year = year)]
    
    if (time_variable != "fake_column") {
      nodes_of_the_year[, time_window := paste0(year, "-", year + time_window - 1), env = list(year = year)]
      
      if (verbose == TRUE)
        cli::cli_h1(
          "Generation of the network for the {.val {year}}-{.val {year + time_window - 1}} time window."
        )
    } else {
      nodes_of_the_year <- nodes_of_the_year[, -c("fake_column")]
    }
    
    edges_of_the_year <- edges[source_id %in% nodes_of_the_year[, source_id], env = list(source_id = source_id)]
    
    # size of nodes
    if (compute_size == TRUE) {
      nb_cit <- edges_of_the_year[source_id %in% nodes_of_the_year[, source_id], .N, target_id, env = list(source_id = source_id, target_id = target_id)]
      
      colnames(nb_cit)[colnames(nb_cit) == "N"] <- "node_size"
      
      if ("node_size" %in% colnames(nodes_coupling) == TRUE)
      {
        cli::cli_warn(
          "You already have a column name {.field node_size}. The content of the column will be replaced."
        )
      }
      
      nodes_of_the_year <- data.table::merge.data.table(nodes_of_the_year,
                                                        nb_cit,
                                                        by = target_id,
                                                        all.x = TRUE)
      
      nodes_of_the_year[is.na(node_size), node_size := 0]
    }
    
    
    
    # backbone
    
    if (backbone_method == "statistical") {
      # prepare backbone function
      backbone_functions <-
        data.table::data.table(
          biblio_function = c(
            rlang::expr(backbone::sdsm),
            rlang::expr(backbone::fdsm),
            rlang::expr(backbone::fixedfrow),
            rlang::expr(backbone::fixedcol),
            rlang::expr(backbone::fixedfill)
          ),
          method = c("sdsm", "fdsm", "fixedfrow", "fixedcol", "fixedfill")
        )
      
      backbone_functions <- backbone_functions[method == statistical_method][["biblio_function"]][[1]]
      
      # Evaluate the expression and catch internal errors to backbone package
      
      tryCatch({
        # using backbone with edgelist is simpler but lead to error in backbone function
        edges_of_the_year <-
          rlang::expr((!!backbone_functions)(
            B = as.data.frame(edges_of_the_year),
            alpha = rlang::inject(alpha)
          )) %>%
          eval() %>%
          as.data.table()
        
      }, error = function(e) {
        stop(
          "The backbone function failed with an error. Read the backbone documentation for more information. Error message: ",
          e$message
        )
      })
    }
    
    
    # coupling
    if (backbone_method == "structured") {
      biblio_functions <-
        data.table::data.table(
          biblio_function = c(
            rlang::expr(biblionetwork::biblio_coupling),
            rlang::expr(biblionetwork::coupling_strength),
            rlang::expr(biblionetwork::coupling_similarity)
          ),
          method = c(
            "coupling_angle",
            "coupling_strength",
            "coupling_similarity"
          )
        )
      
      biblio_function <- biblio_functions[method == coupling_measure][["biblio_function"]][[1]]
      
      # evaluate the expression and catch internal errors to biblionetwork package
      
      tryCatch({
        edges_of_the_year <-
          rlang::expr((!!biblio_function)(
            dt = edges_of_the_year,
            source = rlang::inject(source_id),
            ref = rlang::inject(target_id),
            weight_threshold = rlang::inject(edges_threshold)
          )
          ) %>%
          eval()
        
        
        
      }, error = function(e) {
        stop(
          "The coupling function failed with an error. Read the biblionetwork documentation for more information. Error message: ",
          e$message
        )
      })
      
    }
    
    
    edges_of_the_year[, source_id := from]
    edges_of_the_year[, target_it := to]
    
    # remove nodes with no edges
    if (keep_singleton == FALSE) {
      nodes_of_the_year <- nodes_of_the_year[source_id %in% edges_of_the_year$from |
                                               source_id %in% edges_of_the_year$to, env = list(source_id = source_id)]
    }
    
    # make tbl
    if (length(all_years) == 1)
    {
      tbl_coup_list <- tidygraph::tbl_graph(
        nodes = nodes_of_the_year,
        edges = edges_of_the_year,
        directed = FALSE,
        node_key = source_id
      )
    } else {
      tbl_coup_list[[paste0(year, "-", year + time_window - 1)]] <-
        tidygraph::tbl_graph(
          nodes = nodes_of_the_year,
          edges = edges_of_the_year,
          directed = FALSE,
          node_key = source_id
        )
    }
  }
  
  if (filter_components) {
    if (is.null(min_share) && is.null(nb_components)) {
      cli::cli_abort("Specify either min_share or nb_components when filter_components = TRUE.")
    }
    if (!is.null(min_share) && !is.null(nb_components)) {
      cli::cli_abort("Specify only one of min_share or nb_components, not both.")
    }
    
    if (verbose) {
      if (!is.null(min_share)) cli::cli_alert_info("Keeping components with share ≥ {min_share}.")
      if (!is.null(nb_components)) cli::cli_alert_info("Keeping top {nb_components} component(s).")
    }
    
    tbl_coup_list <- filter_components_dynamic(
      graphs = tbl_coup_list,
      min_share = min_share,
      nb_components = nb_components,
      verbose = FALSE
    )
  }
  
  return (tbl_coup_list)
  
}


###### custom filter components 

filter_components_dynamic <- function(graphs, 
                                      nb_components = NULL, 
                                      min_share = NULL, 
                                      keep_component_columns = FALSE, 
                                      verbose = FALSE) {
  
  # Helper function to apply filtering to a single graph
  filter_single_graph <- function(graph) {
    
    # checking 
    
    if ((is.null(min_share) && is.null(nb_components)) || (!is.null(min_share) && !is.null(nb_components))) {
      cli::cli_abort(
        "You must specify either {.field nb_components} or {.field min_share}."
      )
    }
    
    
    graph <- graph %N>%
      dplyr::mutate(
        components_att = tidygraph::group_components(type = "weak")
      ) %>%
      dplyr::group_by(components_att) %>%
      dplyr::mutate(size_components = dplyr::n()) %>%
      dplyr::ungroup()
    
    # Summarize component sizes
    component_sizes <- graph %N>%
      as.data.frame() %>%
      dplyr::count(components_att, name = "size") %>%
      dplyr::mutate(share = size / sum(size)) %>%
      dplyr::arrange(desc(size)) %>%
      dplyr::mutate(cum_share = cumsum(share),
                    rank = dplyr::row_number())
    
    # Decide how many components to keep
    if (!is.null(min_share)) {
      selected_components <- component_sizes %>%
        dplyr::filter(share >= min_share) %>%
        dplyr::pull(components_att)
      
      if (verbose) {
        cli::cli_alert_info(
          "Keeping components with share of at least {min_share}."
        )
      }
      
    } else if (!is.null(nb_components)) {
      selected_components <- component_sizes %>%
        dplyr::slice_head(n = nb_components) %>%
        dplyr::pull(components_att)
      
      if (verbose) {
        cli::cli_alert_info(
          "Keeping top {nb_components} largest component(s)."
        )
      }
    } else {
      cli::cli_abort("You must specify either {.field nb_components} or {.field min_share}.")
    }
    
    # Filter graph
    graph <- graph %N>%
      dplyr::filter(components_att %in% selected_components)
    
    # Clean up columns if needed
    if (!keep_component_columns) {
      graph <- graph %>% dplyr::select(-components_att, -size_components)
    }
    
    return(graph)
  }
  
  # Apply to list or single graph
  if (inherits(graphs, "list")) {
    graphs <- lapply(graphs, filter_single_graph)
  } else if (inherits(graphs, "tbl_graph")) {
    graphs <- filter_single_graph(graphs)
  } else {
    cli::cli_abort("Your {.field graphs} object must be a {.cls tbl_graph} or a list of {.cls tbl_graph}.")
  }
  
  return(graphs)
}





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
  
  color_sym   <- rlang::sym(color)
  cluster_sym <- rlang::sym(cluster_id)
  id_sym      <- rlang::sym(node_id)
  tooltip_sym <- if (!is.null(node_tooltip)) rlang::sym(node_tooltip) else NULL
  
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
        shiny::sliderInput("min_edge_width", "Min Edge Width:", min = 0.01, max = 5, value = 0.01, step = 0.01),
        shiny::sliderInput("max_edge_width", "Max Edge Width:", min = 0.01, max = 5, value = 1, step = 0.01),
        shiny::sliderInput("min_node_size", "Min Node Size:", min = 0.1, max = 5, value = 0.5, step = 0.01),
        shiny::sliderInput("max_node_size", "Max Node Size:", min = 0.1, max = 5, value = 2, step = 0.01)
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
  
  server <- function(input, output, session) {
    selected_cluster <- shiny::reactiveVal(NULL)
    
    active_graph <- shiny::reactive({
      if (is_list_graph) {
        graph_tbl[[input$selected_graph]]
      } else {
        graph_tbl
      }
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
      
      nodes_df <- tidygraph::activate(g_tbl, "nodes") %>% as.data.frame()
      all_req <- c(cluster_id, node_id, color, "size", "x", "y")
      missing_main <- setdiff(all_req, names(nodes_df))
      missing_info <- setdiff(cluster_information, names(nodes_df))
      if (length(missing_main) > 0 || length(missing_info) > 0) {
        cli::cli_abort("Missing required columns in nodes: {paste(c(missing_main, missing_info), collapse = ', ')}")
      }
      
      aes_args <- list(x = quote(x), y = quote(y), fill = color_sym, size = quote(size))
      if (!is.null(tooltip_sym)) {
        aes_args$tooltip <- tooltip_sym
        aes_args$data_id <- tooltip_sym
      }
      
      edge_width_range <- c(input$min_edge_width, input$max_edge_width)
      node_size_range  <- c(input$min_node_size, input$max_node_size)
      
      g <- ggraph::ggraph(g_tbl, layout = "manual", x = x, y = y) +
        ggraph::geom_edge_arc0(
          ggplot2::aes(color = !!color_sym, width = weight),
          alpha = 0.3, strength = 0.2, show.legend = FALSE
        ) +
        ggiraph::geom_point_interactive(
          do.call(ggplot2::aes, aes_args),
          shape = 21, alpha = 0.8, show.legend = FALSE
        ) +
        ggiraph::geom_label_repel_interactive(
          data = nodes_df %>%
            dplyr::group_by(!!cluster_sym) %>%
            dplyr::summarise(
              label_x = mean(x),
              label_y = mean(y),
              color = first(!!color_sym),
              cluster_label = first(!!cluster_sym),
              .groups = "drop"
            ),
          ggplot2::aes(
            x = label_x, y = label_y,
            label = cluster_label,
            data_id = cluster_label,
            fill = color
          ) %>%
            { if (!is.null(cluster_tooltip)) . + ggplot2::aes(tooltip = cluster_tooltip) else . },
          alpha = 0.9, size = 4, fontface = "bold", show.legend = FALSE
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

























