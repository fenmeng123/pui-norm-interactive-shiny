# Run from the repository root with renv >= 1.1 in the maintainer's library.
# Use the installed packages without activating renv or updating the app library.
if (!file.exists("app/app.R")) stop("Run from the repository root.")
if (!requireNamespace("renv", quietly = TRUE) || packageVersion("renv") < "1.1.0") {
  stop("Generating the Connect Cloud lockfile requires renv 1.1.0 or later.")
}

runtime <- c("shiny", "bslib", "ggplot2", "plotly", "gamlss.dist", "openxlsx", "xml2", "systemfonts", "htmltools")
packages <- c(runtime, "renv")
missing <- setdiff(packages, rownames(installed.packages()))
if (length(missing)) stop("Missing packages: ", paste(missing, collapse = ", "))

lock <- renv::snapshot(
  project = "app",
  library = .libPaths(),
  packages = packages,
  repos = c(CRAN = "https://cloud.r-project.org"),
  lockfile = NULL,
  prompt = FALSE
)
stopifnot(all(packages %in% names(lock$Packages)))
for (record in lock$Packages) {
  if (!identical(record$Source, "Repository") || !identical(record$Repository, "CRAN")) {
    stop("Review package provenance before recording: ", record$Package)
  }
  if (!all(c("Title", "Description", "License") %in% names(record))) {
    stop("Snapshot lacks full DESCRIPTION metadata for ", record$Package)
  }
}
renv::lockfile_write(lock, "app/renv.lock")
cat("Recorded", length(lock$Packages), "packages with renv", as.character(packageVersion("renv")), "\n")
