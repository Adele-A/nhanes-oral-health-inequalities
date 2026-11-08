# 01_download.R ----------------------------------------------------------------
# Download the NHANES 2017-2018 public-use XPT files from CDC/NCHS and record a
# reproducibility manifest (URL, download date, sha256, row/col counts).
# Idempotent: skips files already present unless force = TRUE.
# If the network/CDC is unreachable, stops with a clear message asking the user
# to place the XPT files in data/raw/ manually (never fabricates data).

suppressPackageStartupMessages({
  library(here); library(haven); library(digest); library(jsonlite)
})
source(here::here("R", "config.R"))

# SAS transport (XPT) files begin with this ASCII magic; a redirected HTML page
# (e.g. the CDC homepage) does not, so this guards against silent bad downloads.
is_xpt <- function(path) {
  con <- file(path, "rb"); on.exit(close(con))
  magic <- rawToChar(readBin(con, "raw", n = 40L))
  grepl("HEADER RECORD", magic, fixed = TRUE)
}

download_nhanes <- function(force = FALSE, timeout = 300) {
  ensure_dirs()
  old_to <- getOption("timeout"); on.exit(options(timeout = old_to), add = TRUE)
  options(timeout = timeout)

  manifest <- list()
  for (key in names(NHANES_FILES)) {
    fname <- NHANES_FILES[[key]]
    url   <- paste(NHANES_BASE, fname, sep = "/")
    dest  <- file.path(PATHS$data_raw, fname)

    if (!file.exists(dest) || force) {
      message(sprintf("Downloading %s ...", fname))
      ok <- tryCatch({
        utils::download.file(url, dest, mode = "wb", quiet = TRUE); TRUE
      }, error = function(e) FALSE, warning = function(w) FALSE)
      if (!ok || !file.exists(dest) || file.size(dest) < 1000 || !is_xpt(dest)) {
        if (file.exists(dest) && !is_xpt(dest)) unlink(dest)  # drop redirected HTML page
        stop(sprintf(paste0(
          "Could not download a valid XPT for %s from CDC (%s).\n",
          "Network/CDC may be unreachable or the file has moved. Place the NHANES ",
          "2017-2018 XPT files manually in %s and re-run. Files needed: %s"),
          fname, url, PATHS$data_raw,
          paste(unname(NHANES_FILES), collapse = ", ")), call. = FALSE)
      }
    } else {
      message(sprintf("Using cached %s", fname))
    }

    dat <- haven::read_xpt(dest)
    manifest[[key]] <- list(
      file          = fname,
      url           = url,
      source        = "CDC/NCHS, National Health and Nutrition Examination Survey (NHANES) 2017-2018",
      license       = "U.S. public domain",
      download_date = as.character(Sys.Date()),
      sha256        = digest::digest(dest, algo = "sha256", file = TRUE),
      bytes         = as.integer(file.size(dest)),
      n_rows        = nrow(dat),
      n_cols        = ncol(dat)
    )
  }

  manifest_path <- file.path(PATHS$data_raw, "MANIFEST.json")
  jsonlite::write_json(
    list(
      dataset      = "NHANES 2017-2018 (cycle J)",
      cycle        = NHANES_CYCLE,
      retrieved_by = "R/01_download.R",
      ohq_codebook = OHQ_CODEBOOK_URL,
      note         = "Public-domain CDC/NCHS data; files not committed to git (see .gitignore).",
      files        = manifest
    ),
    manifest_path, pretty = TRUE, auto_unbox = TRUE
  )
  message(sprintf("Wrote %s", manifest_path))
  invisible(file.path(PATHS$data_raw, unname(NHANES_FILES)))
}
