#!/usr/bin/env Rscript

usage <- function() {
  cat(
    paste(
      "Usage:",
      "  Rscript scripts/convert_xcms_to_lamp.R --values=feature_values_into.csv",
      "                                         --features=feature_definitions.csv",
      "                                         [--output=lamp_input.tsv]",
      "                                         [--sep=tab|comma]",
      "                                         [--mz-col=mzmed]",
      "                                         [--rt-col=rtmed]",
      "",
      "Writes a LAMP-compatible peak table with columns:",
      "  name, mz, rt, <sample intensities...>",
      "",
      "This matches LAMP's expected input layout where the first three columns",
      "are feature name, m/z, and retention time, followed by the intensity matrix.",
      sep = "\n"
    )
  )
}

parse_args <- function(args) {
  opts <- list(
    values = NULL,
    features = NULL,
    output = "lamp_input.tsv",
    sep = "tab",
    mz_col = "mzmed",
    rt_col = "rtmed"
  )

  for (arg in args) {
    if (identical(arg, "--help") || identical(arg, "-h")) {
      usage()
      quit(save = "no", status = 0L)
    } else if (startsWith(arg, "--values=")) {
      opts$values <- sub("^--values=", "", arg)
    } else if (startsWith(arg, "--features=")) {
      opts$features <- sub("^--features=", "", arg)
    } else if (startsWith(arg, "--output=")) {
      opts$output <- sub("^--output=", "", arg)
    } else if (startsWith(arg, "--sep=")) {
      opts$sep <- sub("^--sep=", "", arg)
    } else if (startsWith(arg, "--mz-col=")) {
      opts$mz_col <- sub("^--mz-col=", "", arg)
    } else if (startsWith(arg, "--rt-col=")) {
      opts$rt_col <- sub("^--rt-col=", "", arg)
    } else {
      stop("Unknown argument: ", arg, call. = FALSE)
    }
  }

  if (is.null(opts$values) || !nzchar(opts$values)) {
    stop("--values is required", call. = FALSE)
  }
  if (is.null(opts$features) || !nzchar(opts$features)) {
    stop("--features is required", call. = FALSE)
  }
  if (!opts$sep %in% c("tab", "comma")) {
    stop("--sep must be 'tab' or 'comma'", call. = FALSE)
  }

  opts
}

check_file_exists <- function(path, label) {
  if (!file.exists(path)) {
    stop(label, " file not found: ", path, call. = FALSE)
  }
}

normalise_feature_names <- function(values) {
  name_col <- values[[1L]]
  values <- values[-1L]

  if (is.null(name_col) || all(is.na(name_col) | name_col == "")) {
    feature_names <- sprintf("FT%04d", seq_len(nrow(values)))
  } else {
    feature_names <- as.character(name_col)
  }

  feature_names
}

coerce_intensity_matrix <- function(values) {
  if (ncol(values) < 2L) {
    stop(
      "Feature values table must contain a feature name column followed by one or more sample intensity columns.",
      call. = FALSE
    )
  }

  intensity_matrix <- values[-1L]
  metadata_cols <- intersect(colnames(intensity_matrix), c("peakidx", "ms_level"))
  if (length(metadata_cols) > 0L) {
    intensity_matrix <- intensity_matrix[setdiff(colnames(intensity_matrix), metadata_cols)]
  }

  if (ncol(intensity_matrix) < 1L) {
    stop(
      "Feature values table has no sample intensity columns after removing metadata columns peakidx and ms_level.",
      call. = FALSE
    )
  }

  invalid_cols <- character()
  invalid_examples <- character()

  for (col_name in colnames(intensity_matrix)) {
    original <- intensity_matrix[[col_name]]
    numeric_values <- suppressWarnings(as.numeric(original))
    non_missing <- !(is.na(original) | original == "")
    invalid <- non_missing & is.na(numeric_values)

    if (any(invalid)) {
      invalid_cols <- c(invalid_cols, col_name)
      example <- as.character(original[which(invalid)[1L]])
      if (nchar(example) > 80L) {
        example <- paste0(substr(example, 1L, 80L), "...")
      }
      invalid_examples <- c(invalid_examples, example)
    } else {
      intensity_matrix[[col_name]] <- numeric_values
    }
  }

  if (length(invalid_cols) > 0L) {
    examples <- paste(
      sprintf("%s=%s", invalid_cols, invalid_examples),
      collapse = "; "
    )
    stop(
      "Feature values table contains non-numeric sample intensity columns. ",
      "Check that --values points to the intensity matrix and --features points to the feature definitions table. ",
      "Invalid column examples: ", examples,
      call. = FALSE
    )
  }

  intensity_matrix
}

main <- function() {
  opts <- parse_args(commandArgs(trailingOnly = TRUE))

  check_file_exists(opts$values, "Values")
  check_file_exists(opts$features, "Features")

  values <- utils::read.csv(opts$values, check.names = FALSE, stringsAsFactors = FALSE)
  features <- utils::read.csv(opts$features, check.names = FALSE, stringsAsFactors = FALSE)

  if (nrow(values) != nrow(features)) {
    stop(
      "Row count mismatch: feature values has ", nrow(values),
      " rows but feature definitions has ", nrow(features), " rows.",
      call. = FALSE
    )
  }

  if (!opts$mz_col %in% colnames(features)) {
    stop("Requested m/z column not found in feature definitions: ", opts$mz_col, call. = FALSE)
  }
  if (!opts$rt_col %in% colnames(features)) {
    stop("Requested RT column not found in feature definitions: ", opts$rt_col, call. = FALSE)
  }

  feature_names <- normalise_feature_names(values)
  intensity_matrix <- coerce_intensity_matrix(values)

  lamp_table <- data.frame(
    name = feature_names,
    mz = features[[opts$mz_col]],
    rt = features[[opts$rt_col]],
    intensity_matrix,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )

  sep_char <- if (identical(opts$sep, "tab")) "\t" else ","
  utils::write.table(
    lamp_table,
    file = opts$output,
    sep = sep_char,
    row.names = FALSE,
    col.names = TRUE,
    quote = FALSE,
    na = ""
  )

  message("Wrote LAMP input table to ", normalizePath(opts$output, winslash = "/", mustWork = FALSE))
  message("LAMP column index argument for this file is: --col-idx \"1,2,3,4\"")
}

main()
