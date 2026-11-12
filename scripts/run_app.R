# Run from the project root. Set the locale before Shiny reads the app files.
if (.Platform$OS.type == "windows") {
  invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
}
if (!file.exists("app/app.R")) stop("Run this script from the project root.")

# The optional flag is useful for local smoke checks without opening a browser.
open_browser <- !("--no-browser" %in% commandArgs(trailingOnly = TRUE))
shiny::runApp("app", host = "127.0.0.1", launch.browser = open_browser)
