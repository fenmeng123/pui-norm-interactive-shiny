# Record installed runtime dependencies in the documented renv JSON format.
# This does not initialize/activate renv or install/upgrade any package.
if (!file.exists("app/app.R")) stop("Run from the project root.")
runtime <- c("shiny", "bslib", "ggplot2", "plotly", "gamlss.dist", "openxlsx", "xml2", "systemfonts", "htmltools")
db <- installed.packages()
if (!all(runtime %in% rownames(db))) stop("Missing runtime dependencies.")
deps <- tools::package_dependencies(runtime, db = db, which = c("Depends", "Imports", "LinkingTo"), recursive = TRUE)
packages <- sort(unique(c(runtime, unlist(deps, use.names = FALSE))))
packages <- packages[!packages %in% "R"]
if (!all(packages %in% rownames(db))) stop("Incomplete installed dependency closure.")
packages <- packages[is.na(db[packages, "Priority"]) | db[packages, "Priority"] != "base"]
records <- setNames(lapply(packages, function(package) {
  description <- packageDescription(package)
  if (!identical(description$Repository, "CRAN") ||
      (!is.null(description$RemoteType) && !identical(description$RemoteType, "standard"))) {
    stop("Review package provenance before recording: ", package)
  }
  list(Package = package, Version = description$Version, Source = "Repository", Repository = "CRAN")
}), packages)
lock <- list(R = list(Version = as.character(getRversion()),
  Repositories = list(list(Name = "CRAN", URL = "https://cloud.r-project.org"))), Packages = records)
jsonlite::write_json(lock, "app/renv.lock", auto_unbox = TRUE, pretty = TRUE)
cat("Recorded", length(packages), "installed packages for R", as.character(getRversion()), "without activating renv.\n")
