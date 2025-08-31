#' Compute Term Frequency-Inverse Document Frequency (TF-IDF)
#'
#' This function computes the Term Frequency (TF), Inverse Document Frequency (IDF),
#' and TF-IDF score for tokens within documents in a data.table.
#'
#' @param dt A `data.table` containing at least two columns: one for tokens (e.g., words)
#' and one for documents (e.g., time windows, article IDs, etc.).
#' @param token_col A string indicating the name of the column containing tokens. Default is `"token"`.
#' @param document_col A string indicating the name of the column containing document identifiers. Default is `"document"`.
#'
#' @return A `data.table` with one row per unique token-document pair, including the following columns:
#' \describe{
#'   \item{absolute_tf}{Total frequency of each token across all documents.}
#'   \item{nb_word}{Total number of tokens in each document.}
#'   \item{tf}{Term frequency of each token within each document.}
#'   \item{df}{Document frequency — the number of documents in which each token appears.}
#'   \item{idf}{Inverse document frequency: \code{log(total_docs / df)}.}
#'   \item{tf_idf}{TF-IDF score: \code{tf * idf}.}
#' }
#'
#' @examples
#' library(data.table)
#' dt <- data.table(doc = c(1, 1, 2, 2, 2, 3), word = c("apple", "banana", "apple", "apple", "kiwi", "banana"))
#' result <- compute_tf_idf(dt, token_col = "word", document_col = "doc")
#' print(result)
#'
#' @import data.table
#' @export
compute_tf_idf <- function(dt, token_col = "token", document_col = "document") {
  
  # Make a copy to avoid modifying in-place
  dt <- copy(dt)
  
  # Convert column names to symbols
  token_sym <- as.name(token_col)
  time_sym <- as.name(document_col)
  
  # Standardize names temporarily for easier handling
  setnames(dt, c(document_col, token_col), c("document", "token"))
  
  # Calculate absolute term frequency
  dt[, absolute_tf := .N, by = token]
  dt[, nb_word := .N, by = document]
  dt[, tf := .N / nb_word, by = .(document, token)]
  
  # Make unique for TF-IDF calculation
  tokens_count <- unique(dt)
  
  # TF table
  tf_dt <- dt[, .N, by = .(document, token)]
  setnames(tf_dt, "N", "tf")
  
  # DF table
  df_dt <- tokens_count[, .N, by = token]
  setnames(df_dt, "N", "df")
  
  # Merge and compute IDF and TF-IDF
  total_docs <- uniqueN(tokens_count$document)
  tokens_count <- merge(tokens_count, df_dt, by = "token", all.x = TRUE)
  tokens_count[, idf := log(total_docs / df)]
  tokens_count[, tf_idf := tf * idf]
  
  # Rename back to original column names
  setnames(tokens_count, c("document", "token"), c(document_col, token_col))
  
  return(tokens_count[])
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
    cluster_sentences,
    top_references,
    top_references_without_id,
    cluster_origins,
    cluster_destinies,
    tf_idf_data,
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
    requireNamespace("purrr"),
    requireNamespace("shinycssloaders"),
    requireNamespace("tidygraph"),
    requireNamespace("networkflow"),
    requireNamespace("cli"),
    requireNamespace("htmltools"),
    requireNamespace("jsonlite")# add
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
  id_chr      <- rlang::as_name(id_sym)
  cluster_chr <- rlang::as_name(cluster_sym)
  
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
 #       shiny::sliderInput("min_edge_width", "Min Edge Width:", min = 0.1, max = 10, value = 1, step = 0.1),
  #      shiny::sliderInput("max_edge_width", "Max Edge Width:", min = 0.1, max = 10, value = 3, step = 0.1),
        shiny::sliderInput("min_node_size", "Min Node Size:", min = 0.1, max = 10, value = 1, step = 0.1),
        shiny::sliderInput("max_node_size", "Max Node Size:", min = 0.1, max = 10, value = 5, step = 0.1),
        shiny::sliderInput("label_size", "Label size", min = 0.5, max = 5, value = 2.5, step = 0.1),
        
        # shiny::hr(),
        # shiny::h5("Cluster composition"),
        DT::DTOutput("cluster_share") 
      ),
      mainPanel = shiny::mainPanel(
        shiny::div(
          style = "border: 1px solid #ccc; padding: 10px; border-radius: 5px;",
          shinycssloaders::withSpinner(
            ggiraph::girafeOutput("network_plot", width = "100%", height = "600px")
          )
        ),
        shiny::hr(),
        shiny::uiOutput("info_panel")
      )
    )
  )
  
  # Server
  server <- function(input, output, session) {
    selected_cluster <- shiny::reactiveVal(NULL)
    selected_node_id <- shiny::reactiveVal(NULL)
    
    all_nodes_df <- shiny::reactive({
      if (is_list_graph) {
        purrr::imap_dfr(graph_tbl, function(g, nm) {
          df <- tidygraph::activate(g, "nodes") |> as.data.frame()
          df$.graph <- nm
          if (!"time_window" %in% names(df)) df$time_window <- nm
          df
        })
      } else {
        df <- tidygraph::activate(graph_tbl, "nodes") |> as.data.frame()
        df$.graph <- "graph"
        if (!"time_window" %in% names(df)) df$time_window <- NA_character_
        df
      }
    })
    
    active_graph <- shiny::reactive({
      if (is_list_graph) graph_tbl[[input$selected_graph]] else graph_tbl
    })
    
    cluster_nodes_raw <- shiny::reactive({
      req(selected_cluster())
      g_tbl <- active_graph()
      tidygraph::activate(g_tbl, "nodes") |>
        as.data.frame() |>
        dplyr::filter(!!cluster_sym == selected_cluster())
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
        size = quote(size),
        data_id = id_sym                         # <— was tooltip_sym
      )
      if (!is.null(tooltip_sym)) {
        node_aes$tooltip <- tooltip_sym
    #    node_aes$data_id <- tooltip_sym
      } else {
        node_aes$tooltip <- id_sym               # fallback tooltip
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
      
   #   edge_width_range <- c(input$min_edge_width, input$max_edge_width)
      node_size_range  <- c(input$min_node_size, input$max_node_size)
      label_size <- input$label_size


      g <- ggraph::ggraph(g_tbl, layout = "manual", x = x, y = y) +
        # ggraph::geom_edge_arc0(
        #   ggplot2::aes(color = !!color_sym, width = weight),
        #   alpha = 0.3, strength = 0.2, show.legend = FALSE
        # ) +
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
        # ggraph::scale_edge_width_continuous(range = edge_width_range) +
        ggplot2::scale_size_continuous(range = node_size_range) +
        # ggraph::scale_edge_colour_identity() +
        ggplot2::scale_fill_identity() +
        ggplot2::theme_void()
      
      ggiraph::girafe(
        ggobj = g,
        width_svg = 10,
        height_svg = 6,
        options = list(ggiraph::opts_selection(type = "single"),
                       ggiraph::opts_zoom(min = 1, max = 12),        # wheel to zoom, drag to pan
                       ggiraph::opts_toolbar(position = "topright")  # gives reset zoom button)
        )
      )
    })

    shiny::observeEvent(input$network_plot_selected, {
      sel <- input$network_plot_selected
      nodes_all  <- all_nodes_df()
      nodes_here <- tidygraph::activate(active_graph(), "nodes") |> as.data.frame()
      
      if (!is.null(sel) && sel %in% nodes_all[[id_chr]]) {
        # clicked a node -> show ONLY node info
        selected_node_id(sel)
        selected_cluster(NULL)
      } else if (!is.null(sel) && sel %in% nodes_here[[cluster_chr]]) {
        # clicked a cluster label -> show ONLY cluster info
        selected_cluster(sel)
        selected_node_id(NULL)
      } else {
        selected_node_id(NULL)
        selected_cluster(NULL)
      }
    })
    
    output$info_panel <- shiny::renderUI({
      if (!is.null(selected_node_id())) {
        tagList(
          shiny::h4("Selected node"),
          DT::DTOutput("node_info")
        )
      } else if (!is.null(selected_cluster())) {
        cl <- if (is_list_graph) paste0(selected_cluster(), " — ", input$selected_graph)
              else as.character(selected_cluster())
        tagList(
          shiny::h4(paste0("Documents in ", cl)),
          shiny::uiOutput("role_filter_ui"),
          DT::DTOutput("cluster_docs"),
          shiny::h4(paste0("Closest sentences for ", cl)),
          DT::DTOutput("cluster_sentences"),
          shiny::h4(paste0("Top References of ", cl)),
          DT::DTOutput("cluster_refs"),
          shiny::h4(paste0("Top References (without ID) of ", cl)),
          DT::DTOutput("cluster_refs_without_id"),
          shiny::h4(paste0("Cluster tf-idf for ", cl)),
          DT::DTOutput("cluster_tf_idf"),
          shiny::h4(paste0("Cluster origins for ", cl, " (t-1 → t)")),
          DT::DTOutput("cluster_origins_table"),
          shiny::h4(paste0("Cluster destinies for ", cl, " (t → t+1)")),
          DT::DTOutput("cluster_destinies_table")
        )
      } else {
        NULL
      }
    })
    
    output$cluster_share <- DT::renderDT({
      g_tbl <- active_graph()
      nodes <- tidygraph::activate(g_tbl, "nodes") %>% as.data.frame()
      
      tab <- nodes %>%
        dplyr::count(!!cluster_sym, name = "n") %>%
        dplyr::mutate(prop = n / sum(n),
                      pct  = sprintf("%.1f%%", 100 * prop)) %>%
        dplyr::arrange(dplyr::desc(prop)) %>%
        dplyr::rename(Cluster = !!cluster_sym) %>%
        dplyr::select(Cluster, n, pct)
      
      DT::datatable(tab,
                    options = list(dom = 't', paging = FALSE),
                    rownames = FALSE
      )
    })
    
    output$node_info <- DT::renderDT({
      req(selected_node_id())
      nodes_all <- all_nodes_df()
      
      out <- nodes_all |>
        dplyr::filter(.data[[id_chr]] == selected_node_id()) |>
        dplyr::arrange(.graph) |>
        dplyr::select(dplyr::any_of(c("time_window", cluster_id, cluster_information, node_size)), -sentence)
      
      tbl <- DT::datatable(out, options = list(pageLength = 10), escape = FALSE, rownames = FALSE)
      
      if (is_list_graph && "time_window" %in% names(out)) {
        lv  <- unique(out$time_window)
        year <- lv %>% str_extract("^\\d+")
        col <- ifelse(year == input$selected_graph, "#fff3cd", "")  # pale yellow
        tbl <- DT::formatStyle(
          tbl, "time_window",
          target = "row",
          backgroundColor = DT::styleEqual(lv, col)
        )
      }
      
      tbl
    })
    
    
    
    output$cluster_docs <- DT::renderDT({
      df <- cluster_nodes_raw()
      
      # role filter
      if (!is.null(input$role_filter) && input$role_filter != "All" && "role" %in% names(df)) {
        df <- dplyr::filter(df, .data$role == input$role_filter)
      }
      
      # role tooltips (HTML)
      role_expl <- c(
        R1="Ultra-peripheral node: z low, P < 0.05. Almost all links within its cluster.",
        R2="Peripheral node: z low, 0.05 ≤ P < 0.62. Mostly within-cluster links.",
        R3="Connector node: z low, 0.62 ≤ P < 0.80. Many links to other clusters.",
        R4="Kinless node: z low, P ≥ 0.80. Links spread across clusters.",
        R5="Provincial hub: z high, P < 0.30. Hub inside its cluster.",
        R6="Connector hub: z high, 0.30 ≤ P < 0.75. Hub bridging clusters.",
        R7="Kinless hub: z high, P ≥ 0.75. Hub linked broadly across clusters."
      )
      role_alias <- c(
        "ultra-peripheral"="R1","peripheral"="R2","connector"="R3","kinless"="R4",
        "provincial hub"="R5","connector hub"="R6","kinless hub"="R7"
      )
      norm_label <- function(x) {
        x <- trimws(as.character(x))
        x <- gsub("[\u2010-\u2015]", "-", x); x <- gsub("\\s+", " ", x)
        tolower(x)
      }
      if ("role" %in% names(df)) {
        df$role <- vapply(df$role, function(val) {
          key  <- role_alias[[ norm_label(val) ]]
          desc <- if (!is.null(key)) role_expl[[key]] else "Role description unavailable"
          sprintf('<span title="%s">%s</span>',
                  htmltools::htmlEscape(desc),
                  htmltools::htmlEscape(as.character(val)))
        }, FUN.VALUE = character(1))
      }
      
      shown_cols <- intersect(cluster_information, names(df))
      if (!length(shown_cols)) shown_cols <- setdiff(names(df), c("x","y",".graph"))
      shown <- df |> dplyr::select(dplyr::all_of(shown_cols))
      
      # indices of numeric columns to tooltip (0-based for DataTables)
      cols <- colnames(shown)
      # indices (0-based)
      cols <- colnames(shown)
      z_idx <- match("z_within", cols) - 1L
      p_idx <- match("participation_coefficient", cols) - 1L
      
      # detailed tooltips
      z_expl <- paste(
        "Within-cluster degree z (standardized).",
        "Formula: z = (k_iC - mean(k_C)) / sd(k_C),",
        "  k_iC = links/weight from node i to nodes in its cluster C.",
        "Interpretation: higher = more hub-like inside its cluster; ~0 = average.",
        "Rule of thumb: z > 2.5 → hub.",
        sep = "\n"
      )
      p_expl <- paste(
        "Participation coefficient P ∈ [0,1].",
        "Formula: P = 1 - Σ_C (k_iC / k_i)^2,",
        "  k_iC = links/weight from i to cluster C; k_i = total links/weight of i.",
        "Interpretation: 0 = all links in one cluster; 1 = evenly spread across clusters.",
        "Typical cutoffs: ~0.05 local, ~0.30 local hub, ~0.62 connector, ≥0.80 kinless-like.",
        sep = "\n"
      )
      
      # JS callback to add title=... without changing data types
      
      js_row_cb <- DT::JS(paste0(
        "function(row,data){",
        if (!is.na(z_idx))
          paste0("$('td:eq(", z_idx, ")', row).attr('title', ",
                 jsonlite::toJSON(z_expl, auto_unbox = TRUE), ");")
        else "",
        if (!is.na(p_idx))
          paste0("$('td:eq(", p_idx, ")', row).attr('title', ",
                 jsonlite::toJSON(p_expl, auto_unbox = TRUE), ");")
        else "",
        "}"
      ))
      
      # format numbers for display only; keep raw for sort/filter
      num_renderer <- DT::JS(
        "function(data,type,row,meta){ if(type === 'display'){ if(data == null) return ''; return Number(data).toFixed(3);} return data; }"
      )
      col_defs <- list()
      if (!is.na(z_idx)) col_defs <- c(col_defs, list(list(targets = z_idx, render = num_renderer)))
      if (!is.na(p_idx)) col_defs <- c(col_defs, list(list(targets = p_idx, render = num_renderer)))
      
      DT::datatable(
        shown,
        filter = "top",
        escape = -which(cols == "role"),  # do not escape role HTML; escape others
        rownames = FALSE,
        options = list(
          dom = "lfrtip",
          searchHighlight = TRUE,
          rowCallback = js_row_cb,
          columnDefs = col_defs
        )
      )
    })
    
    
    
    output$role_filter_ui <- shiny::renderUI({
      df <- cluster_nodes_raw()
      roles <- sort(unique(as.character(df$role)))
      if (!length(roles)) return(NULL)
      shiny::selectInput(
        "role_filter", "Filter by role:",
        choices = c("All", roles), selected = "All"
      )
    })
    
    output$cluster_sentences <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      
      # join on (time_window, cluster_id) exactly like top_references
      sentences <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        dplyr::distinct(!!cluster_sym, time_window) %>%
        dplyr::left_join(cluster_sentences)
      
      tab <- sentences %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        # pick reasonable columns if present
        dplyr::select(dplyr::any_of(c(
          cluster_information, "sentence", "similarity"
        )))
      DT::datatable(tab, escape = FALSE, options = list(pageLength = 10), rownames = FALSE)
    })
    
    output$cluster_refs <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      main_refs_cluster <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>% 
        dplyr::left_join(top_references)
        main_refs_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(Nom, Annee, Revue_Abbrege, nb_cit) %>%
        DT::datatable(options = list(pageLength = 20))
    })
    
    output$cluster_refs_without_id <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      main_refs_cluster <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>% 
        dplyr::left_join(top_references_without_id)
      main_refs_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(Nom, Annee, Revue_Abbrege, nb_cit) %>%
        DT::datatable(options = list(pageLength = 10))
    })
    
    output$cluster_tf_idf <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      tf_idf_for_cluster <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>% 
        dplyr::left_join(tf_idf_data) %>% 
        filter(!is.na(term))
      tf_idf_for_cluster %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(term, tf_idf) %>%
        mutate(tf_idf = round(tf_idf, 4)) %>%
        DT::datatable(options = list(pageLength = 20))
    })
    
    output$cluster_origins_table <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      origins <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>% 
        dplyr::left_join(cluster_origins)
      origins %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(previous_cluster, origin_percent) %>%
        mutate(origin_percent = sprintf("%.1f%%", 100 * origin_percent)) %>%
        DT::datatable(options = list(pageLength = 10))
    })
    
    output$cluster_destinies_table <- DT::renderDT({
      req(selected_cluster())
      g_tbl <- active_graph()
      destinies <- g_tbl %>%
        tidygraph::activate("nodes") %>%
        as.data.frame() %>%
        distinct(!!cluster_sym, time_window) %>% 
        dplyr::left_join(cluster_destinies)
      destinies %>%
        dplyr::filter(!!cluster_sym == selected_cluster()) %>%
        dplyr::select(forward_cluster, destiny_percent) %>%
        mutate(destiny_percent = sprintf("%.1f%%", 100 * destiny_percent)) %>%
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

