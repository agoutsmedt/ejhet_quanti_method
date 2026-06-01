#' @title Process multiple year-centroid matrices to rank sentence drivers
#' @description
#' Run `rank_drivers_for_year_pair()` over a set of named year-by-dimension matrices,
#' persist per-year results to disk, and combine per-matrix outputs into a single
#' data.table per matrix. This function is resume-friendly: it skips years already
#' processed on disk.
#' @param matrices named list of numeric matrices. Each matrix must have rownames
#'   that represent years (e.g., `"1900"`, `"1901"`). Rows are years, columns are
#'   embedding dimensions. NA rownames or non-integer year names are ignored.
#' @param data_path character scalar. Base path where per-matrix output directories
#'   and combined RDS files are written. Must be writable. NA not allowed.
#' @param jstor_data_path character scalar. Path forwarded to
#'   `rank_drivers_for_year_pair()` via `data_path` argument; typically the dataset
#'   root. NA not allowed.
#' @param years_range integer vector. Years to consider for processing (default
#'   1900:2008). Years are intersected with matrix rownames and with already
#'   processed years on disk.
#' @return
#' Invisibly returns a named list (same names as `matrices`) of length equal to
#' `length(matrices)`. Each element is either:
#' - a `data.table` containing the combined per-year driver results for that matrix
#'   (with a column `year_pair_start` and `sentence_id`), or
#' - `NULL` if no per-year results were available to combine.
#' The function also writes per-year files named `drivers_<YEAR>.rds` inside
#' `file.path(data_path, paste0("top_sentence_drivers_year_pairs_", <name>))`
#' and a combined RDS `top_sentence_drivers_all_years_<name>.rds` in `data_path`.
#' @details
#' This helper automates running `rank_drivers_for_year_pair()` across several
#' year-centroid matrices and persists intermediate and combined results. It is
#' intentionally conservative: it checks for existing per-year and combined files
#' and skips work already done to support resumable long-running workflows.
#'
#' Side-effects:
#' - creates per-matrix directories under `data_path` (if missing),
#' - writes per-year RDS files (`drivers_<YEAR>.rds`),
#' - writes one combined RDS per matrix (`top_sentence_drivers_all_years_<name>.rds`).
#'
#' Implementation notes:
#' - High-level algorithm:
#'   1. Validate inputs and iterate over named matrices.
#'   2. For each matrix, determine available years from `rownames(mat)`.
#'   3. Determine which years still need processing by comparing `years_range`,
#'      available years, and already written per-year files in the output directory.
#'   4. For each year to process, call `rank_drivers_for_year_pair()` and write
#'      the result to `drivers_<YEAR>.rds`. Errors from the ranking function are
#'      caught and logged; processing continues.
#'   5. After per-year files are present, read them all, bind into a single
#'      `data.table` (with `idcol = "year_pair_start"`), assign `sentence_id`
#'      and save the combined file.
#' - Assumptions and preconditions:
#'   - `matrices` is a named list and each matrix rownames (if present) are parseable
#'     as integers representing years.
#'   - `rank_drivers_for_year_pair()` exists in the environment and returns an
#'     object coercible to a `data.table`/data.frame.
#' - Edge-case handling and failure modes:
#'   - If `rank_drivers_for_year_pair()` errors for a year, the error is logged
#'     and processing continues; that year is not saved.
#'   - If no per-year files are present for a matrix, the function returns `NULL`
#'     for that matrix and logs a warning.
#' - Trade-offs:
#'   - The function writes per-year outputs to disk to enable resuming and avoid
#'     re-running expensive work; this increases I/O but improves robustness.
#' - Dependencies:
#'   - Relies on `glue`, `stringr`, `purrr`, `data.table`, and `cli` for logging and
#'     file handling; these packages must be available at runtime.
#' - Global state mutated:
#'   - Creates directories and writes RDS files under `data_path`.
#' @implementation
#' The implementation favors simplicity and resumability: file-existence checks
#' are used to skip work, `tryCatch()` isolates failures per-year, and results
#' are combined with `data.table::rbindlist()` for performance.
#' @examples
#' # Minimal example: create two tiny matrices for two years and a mock ranker.
#' rank_drivers_for_year_pair <- function(mat, year_t, ..., top_n = 10L) {
#'   # return a small data.frame resembling a driver result
#'   data.frame(
#'     token = paste0("tok_", seq_len(3)),
#'     projection_score = runif(3),
#'     stringsAsFactors = FALSE
#'   )
#' }
#'
#' m1 <- matrix(runif(4), nrow = 2, dimnames = list(c("2000", "2001"), NULL))
#' m2 <- matrix(runif(4), nrow = 2, dimnames = list(c("2000", "2001"), NULL))
#' tmp <- tempdir()
#' res <- process_matrices_for_drivers(
#'   matrices = list(a = m1, b = m2),
#'   data_path = tmp,
#'   jstor_data_path = tmp,
#'   years_range = 2000:2001
#' )
#' str(res)
#' @seealso rank_drivers_for_year_pair, readRDS, saveRDS, data.table::rbindlist
#' @family drivers
#' @keywords internal
process_matrices_for_drivers <- function(
  matrices,
  data_path,
  jstor_data_path,
  years_range = 1900:2008
) {
  stopifnot(is.list(matrices), length(matrices) > 0)
  combined_results <- list()

  for (nm in names(matrices)) {
    mat_i <- matrices[[nm]]

    # create a per-matrix output directory (idempotent)
    output_dir <- file.path(
      data_path,
      glue::glue("top_sentence_drivers_year_pairs_{nm}")
    )
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

    # extract available years from matrix rownames; ignore NA or missing rownames
    years_available <- if (!is.null(rownames(mat_i))) {
      as.integer(rownames(mat_i))
    } else {
      integer(0)
    }
    years_available <- years_available[!is.na(years_available)]

    # determine years already processed by reading filenames in output_dir
    years_already_processed <- list.files(
      output_dir,
      pattern = "^drivers_\\d{4}\\.rds$",
      full.names = FALSE
    ) %>%
      stringr::str_extract("\\d{4}") %>%
      as.integer()

    # years to process = intersection of requested range and available years,
    # excluding years already processed
    years_to_process <- intersect(years_range, years_available) |>
      setdiff(years_already_processed)
    processed_files <- character(0)

    for (yr in years_to_process) {
      cli::cli_inform(glue::glue("[{nm}] Starting year {yr}"))
      out_path <- file.path(output_dir, glue::glue("drivers_{yr}.rds"))

      if (file.exists(out_path)) {
        # redundant check to avoid race-conditions if a file appeared between listing and loop
        cli::cli_inform(glue::glue(
          "[{nm}] Skipping {yr} — output exists at {out_path}"
        ))
        processed_files <- c(processed_files, out_path)
        next
      }

      # isolate errors/warnings from the ranking function so processing can continue
      res <- tryCatch(
        {
          rank_drivers_for_year_pair(
            mat = mat_i,
            year_t = yr,
            year_col = "year",
            embedding_col = "embedding",
            top_n = 200L,
            normalize_rows = TRUE,
            chunk_threshold = 100000L,
            data_path = jstor_data_path
          )
        },
        error = function(e) {
          cli::cli_alert_danger(glue::glue(
            "[{nm}] Error processing {yr}: {e$message}"
          ))
          NULL
        },
        warning = function(w) {
          cli::cli_alert_warning(glue::glue(
            "[{nm}] Warning processing {yr}: {w$message}"
          ))
          invokeRestart("muffleWarning")
        }
      )

      if (is.null(res)) {
        next
      }

      saveRDS(res, out_path)
      processed_files <- c(processed_files, out_path)

      # free memory promptly for long loops
      rm(res)
      gc()
      cli::cli_inform(glue::glue("[{nm}] Saved results for {yr} → {out_path}"))
    }

    # combine per-year files into single RDS for this matrix if not already combined
    combined_path <- file.path(
      data_path,
      glue::glue("top_sentence_drivers_all_years_{nm}.rds")
    )
    if (!file.exists(combined_path) && length(processed_files) > 0) {
      all_processed_files <- list.files(
        output_dir,
        pattern = "^drivers_\\d{4}\\.rds$",
        full.names = TRUE
      )

      # extract years from filenames to use as names when binding
      years_processed <- all_processed_files %>%
        stringr::str_extract("\\d{4}") %>%
        as.integer()

      # read all per-year RDS files into a list
      all_list <- purrr::map(all_processed_files, readRDS)
      names(all_list) <- paste0(years_processed)

      # bind into a single data.table with an id column 'year_pair_start'
      all_list <- data.table::rbindlist(all_list, idcol = "year_pair_start")
      all_list[, sentence_id := .I]
      data.table::setDT(all_list, key = "sentence_id")

      saveRDS(all_list, combined_path)
      cli::cli_inform(glue::glue(
        "[{nm}] Combined file written to {combined_path}"
      ))
      combined_results[[nm]] <- all_list
    } else if (file.exists(combined_path)) {
      # load existing combined file to return
      combined_results[[nm]] <- readRDS(combined_path)
      cli::cli_inform(glue::glue(
        "[{nm}] Loaded combined file from {combined_path}"
      ))
    } else {
      cli::cli_alert_warning(glue::glue(
        "[{nm}] No processed files found to combine."
      ))
      combined_results[[nm]] <- NULL
    }
  }

  invisible(combined_results)
}
