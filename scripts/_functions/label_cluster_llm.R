#: Functions for network analysis-------------------------

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
label_cluster_llm <- function(
  graph_tbl,
  cluster_id,
  cluster_information,
  model = "llama3.1",
  max_words = 5
) {
  library(dplyr)
  library(tidygraph)
  library(data.table)
  library(ollamar)
  library(jsonlite)
  library(rlang)

  label_one_graph <- function(g) {
    g_df <- activate(g, "nodes") %>% as_tibble()

    if (!cluster_id %in% colnames(g_df)) {
      stop("cluster_id not found in node data.")
    }
    if (!all(cluster_information %in% colnames(g_df))) {
      stop("Some cluster_information columns are missing.")
    }

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

      prompt <- paste0(
        "Here is a cluster or scientific articles in economics made using bibliographic coupling.
                       Each article is described by its metadada.
                       Using this information to name cluster using no more than 5 words.
                       Your output should start with the name of the cluster followed by a full stop.
                       Your output should only be the name of the cluster, nothing else. I insist: output only the name of the cluster.
                       Here is the data: ",
        json_input
      )

      label <- ollamar::generate(
        model = model,
        prompt = prompt,
        output = "text"
      )

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
