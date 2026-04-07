# ============================================================
# Script: inspect_data.R
# Purpose: Summarize project data files.
#          RDS inspection fully loads each object into memory before reporting.
# ============================================================

get_script_path <- function() {
  cmd_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", cmd_args, value = TRUE)
  if (length(file_arg) > 0) {
    return(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE))
  }
  for (i in rev(seq_along(sys.frames()))) {
    if (!is.null(sys.frames()[[i]]$ofile)) {
      return(normalizePath(sys.frames()[[i]]$ofile, winslash = "/", mustWork = TRUE))
    }
  }
  stop("Unable to resolve script path for inspect_data.R")
}

project_root <- dirname(dirname(get_script_path()))
rm(get_script_path)

cat("=== DATA FILE INSPECTION (RDS objects are fully loaded for inspection) ===\n\n")

# --- Check data/raw/ ---
cat("--- data/raw/ ---\n")
raw_files <- list.files(file.path(project_root, "data", "raw"), full.names = TRUE, recursive = TRUE)
raw_files <- raw_files[!grepl("\\.gitkeep$", raw_files)]
if (length(raw_files) == 0) {
  cat("  NO DATA FILES in data/raw/ (only .gitkeep)\n")
} else {
  for (f in raw_files) {
    cat(sprintf("  %s  (%.1f MB)\n", basename(f), file.size(f) / 1e6))
  }
}

# --- Check data/cleaned/ ---
cat("\n--- data/cleaned/ ---\n")
cleaned_files <- list.files(file.path(project_root, "data", "cleaned"), full.names = TRUE, recursive = TRUE)
cleaned_files <- cleaned_files[!grepl("\\.gitkeep$", cleaned_files)]
if (length(cleaned_files) == 0) {
  cat("  NO DATA FILES in data/cleaned/\n")
} else {
  for (f in cleaned_files) {
    size_mb <- file.size(f) / 1e6
    cat(sprintf("  %s  (%.1f MB)\n", basename(f), size_mb))

    ext <- tolower(tools::file_ext(f))

    if (ext == "rds") {
      # readRDS() fully loads the object into memory before we inspect it.
      tryCatch({
        d <- readRDS(f)
        cat(sprintf("    Class: %s\n", paste(class(d), collapse=", ")))
        if (is.data.frame(d)) {
          cat(sprintf("    Dimensions: %d rows x %d cols\n", nrow(d), ncol(d)))
          cat(sprintf("    Column names: %s\n", paste(names(d), collapse=", ")))
          cat("    str() output (compact):\n")
          str(d, max.level = 1, give.attr = FALSE, vec.len = 3)
        }
      }, error = function(e) cat("    Error reading:", conditionMessage(e), "\n"))

    } else if (ext %in% c("txt", "csv", "tsv")) {
      # For large text files: read ONLY first 5 rows
      cat(sprintf("    File size: %.1f MB (%.1f GB)\n", size_mb, size_mb / 1000))

      # Count lines WITHOUT loading the whole file
      tryCatch({
        con <- file(f, "r")
        header <- readLines(con, n = 1)
        close(con)
        n_cols <- length(strsplit(header, "\t")[[1]])
        cat(sprintf("    Detected delimiter: tab (TSV)\n"))
        cat(sprintf("    Number of columns (from header): %d\n", n_cols))
        cat(sprintf("    Header fields: %s\n",
            paste(head(strsplit(header, "\t")[[1]], 30), collapse=", ")))
        if (n_cols > 30) cat(sprintf("    ... and %d more columns\n", n_cols - 30))
      }, error = function(e) cat("    Error reading header:", conditionMessage(e), "\n"))

      # Read first 5 data rows
      tryCatch({
        d_head <- read.delim(f, nrows = 5, header = TRUE, sep = "\t",
                             stringsAsFactors = FALSE)
        cat(sprintf("    First 5 rows: %d rows x %d cols\n", nrow(d_head), ncol(d_head)))
        cat("    Column types:\n")
        for (nm in names(d_head)) {
          cat(sprintf("      %-20s %s  [sample: %s]\n",
              nm, class(d_head[[nm]]),
              paste(head(d_head[[nm]], 2), collapse=", ")))
        }
      }, error = function(e) cat("    Error reading rows:", conditionMessage(e), "\n"))

      # Approximate row count via file size (avoid wc -l on 2GB file)
      cat(sprintf("    (Full row count not computed - file is %.1f GB)\n", size_mb / 1000))
    }
  }
}

# --- Check for .rds files in project root (InterimScript saves there) ---
cat("\n--- .rds files in project root ---\n")
root_rds <- list.files(project_root, pattern = "\\.rds$", full.names = TRUE)
if (length(root_rds) == 0) {
  cat("  No .rds files in project root\n")
} else {
  for (f in root_rds) {
    cat(sprintf("  %s (%.1f MB)\n", basename(f), file.size(f) / 1e6))
  }
}

# --- Check for saved analysis RDS anywhere ---
cat("\n--- .rds files anywhere in project ---\n")
all_rds <- list.files(project_root, pattern = "\\.rds$", recursive = TRUE, full.names = TRUE)
if (length(all_rds) == 0) {
  cat("  No .rds files found anywhere\n")
} else {
  for (f in all_rds) {
    rel_f <- sub(paste0("^", project_root, "/"), "", f)
    cat(sprintf("  %s (%.1f MB)\n", rel_f, file.size(f) / 1e6))
  }
}

cat("\n=== INSPECTION COMPLETE ===\n")
