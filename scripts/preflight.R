# Local, read-only technical release checks. Does not certify rights or cloud hosting.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
stopifnot(file.exists("app/app.R"), file.exists("app/renv.lock"))
files <- list.files("app", recursive = TRUE, all.files = TRUE, no.. = TRUE)
stopifnot(!any(grepl("(^|/)(private|uploads|downloads|rsconnect|\\.posit|\\.env|\\.Renviron|\\.Rprofile)(/|$)", files)))
stopifnot(identical(files[grepl("\\.[Rr][Dd][Ss]$", files)], "models/pui_prediction_v1.rds"))
hash <- digest::digest(file = "app/models/pui_prediction_v1.rds", algo = "sha256", serialize = FALSE)
stopifnot(identical(hash, "24c2013c194dfd67f9ae898fc14c31651514ff10ac96bba01c399eb225ef4538"))
font_hash <- digest::digest(file = "app/fonts/NotoSansCJKsc-Regular.otf", algo = "sha256", serialize = FALSE)
stopifnot(identical(font_hash, "2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b"))
pure_data <- function(x) {
  if (length(setdiff(names(attributes(x)), "names"))) return(FALSE)
  if (is.list(x)) return(all(vapply(x, pure_data, logical(1))))
  typeof(x) %in% c("double", "integer", "character", "logical")
}
stopifnot(pure_data(readRDS("app/models/pui_prediction_v1.rds")))
r_files <- c(list.files("app", pattern = "\\.R$", recursive = TRUE, full.names = TRUE),
  list.files("scripts", pattern = "\\.R$", full.names = TRUE), list.files("tests", pattern = "\\.R$", full.names = TRUE))
invisible(lapply(r_files, parse, encoding = "UTF-8"))
lock <- jsonlite::read_json("app/renv.lock", simplifyVector = FALSE)
stopifnot(identical(lock$R$Version, "4.5.2"))
db <- installed.packages()
for (package in names(lock$Packages)) {
  record <- lock$Packages[[package]]
  stopifnot(identical(record$Package, package), identical(record$Source, "Repository"),
    identical(record$Repository, "CRAN"), identical(record$Version, packageDescription(package)$Version))
}
deps <- tools::package_dependencies(names(lock$Packages), db = db, recursive = TRUE)
needed <- unique(unlist(deps, use.names = FALSE))
base <- rownames(db)[!is.na(db[, "Priority"]) & db[, "Priority"] == "base"]
stopifnot(all(needed %in% c("R", base, names(lock$Packages))))
stopifnot(file.exists("app/fonts/OFL.txt"), capabilities("cairo"))
cat("Syntax, frozen model/font hashes, recursive data-only asset and", length(lock$Packages), "locked dependencies: PASS\n")
cat("This is a technical check. Questionnaire rights and actual Connect Cloud deployment remain separate.\n")
