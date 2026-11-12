# Run in a separate clean R session from a directory containing only these
# copied files: the candidate RDS, predict_pui.R and this test script.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) stop("Supply candidate RDS and prediction script paths.")
source(args[2], encoding = "UTF-8")
asset <- load_pui_prediction_asset(args[1])
result <- predict_pui(asset, age = c(9, 9.12345, 14.5, 18), sex = c("Male", "Female", "Male", "Female"), raw_score = c(17, 18, 84, 85))
stopifnot(nrow(result) == 4L, all(is.finite(result$percentile)), all(result$percentile >= 0 & result$percentile <= 100))
single <- predict_pui(asset, age = 14.5, sex = "Male", raw_score = 84)
stopifnot(isTRUE(all.equal(single$percentile, result$percentile[3], tolerance = 1e-13)))
old_contrasts <- options(contrasts = c("contr.sum", "contr.poly"))
stopifnot(identical(predict_pui(asset, 14.5, "Male", 84)$percentile, single$percentile))
options(old_contrasts)
scores <- predict_pui(asset, age = 14.5, sex = "Female", raw_score = 17:85)$percentile
stopifnot(all(diff(scores) >= 0))
invalid <- list(
  list(8.999, "Male", 17), list(18.001, "Female", 85), list(NA_real_, "Male", 17),
  list(Inf, "Male", 17), list(12, "Unknown", 17), list(12, NA_character_, 17),
  list(12, "Male", 16), list(12, "Male", 86), list(12, "Male", 20.5), list(12, "Male", 20.000000001),
  list(12, "Male", NA_real_), list(numeric(0), character(0), numeric(0)),
  list(c(10, 11), c("Male", "Female", "Male"), 17)
)
for (item in invalid) {
  outcome <- try(predict_pui(asset, age = item[[1]], sex = item[[2]], raw_score = item[[3]]), silent = TRUE)
  stopifnot(inherits(outcome, "try-error"))
}
stopifnot(inherits(try(predict_pui(asset, 12, "Male", 36, covid_period = "First wave"), silent = TRUE), "try-error"))
cat("Clean-session valid, vectorized, boundary and invalid-input checks passed.\n")
