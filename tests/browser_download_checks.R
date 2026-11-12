# Check actual browser downloads, not just in-memory server return values.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
root <- args[1]
source("app/R/predict_pui.R", encoding = "UTF-8")
asset <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")
original <- readxl::read_xlsx(file.path(root, "template.xlsx"))
expected <- predict_pui(asset, original$age, original$sex, original$score)$percentile
for (name in c("batch-zh.xlsx", "batch-en.xlsx", "batch-en-repeat.xlsx")) {
  result <- readxl::read_xlsx(file.path(root, name))
  column <- if (name == "batch-zh.xlsx") "百分位常模分" else "Normative percentile"
  stopifnot(identical(names(result), c(names(original), column)),
    identical(result[names(original)], original), max(abs(result[[column]] - expected)) < 1e-12)
}
cat("Actual browser Excel downloads: rows, columns, values, bilingual headers and unrounded percentiles PASS\n")
