# Synthetic inputs only. Run from the project root; PDFs are temporary QA files.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
library(shiny)
source("app/R/predict_pui.R", encoding = "UTF-8")
source("app/components/yiat17_items.R", encoding = "UTF-8")
model_asset <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")
server <- function(input, output, session) {
  language <- reactive(if (identical(input$app_language, "en")) "en" else "zh")
  consent_granted <- reactiveVal(TRUE)
  source("app/components/individual_server.R", local = TRUE, encoding = "UTF-8")
}

output_dir <- Sys.getenv("PUI_PDF_QA_DIR", unset = "")
if (!nzchar(output_dir) || !dir.exists(output_dir)) stop("PUI_PDF_QA_DIR must identify an existing temporary directory.")
testServer(server, {
  session$setInputs(individual_age = 14.5, individual_sex = "Female", individual_score = 36)
  first <- individual_result()
  first_file <- output$individual_pdf
  stopifnot(file.copy(first_file, file.path(output_dir, "first.pdf"), overwrite = TRUE))

  # Every changed field must be reflected in the next report and prediction.
  session$setInputs(individual_age = 17.987654321, individual_sex = "Male", individual_score = 85)
  second <- individual_result()
  second_file <- output$individual_pdf
  stopifnot(file.copy(second_file, file.path(output_dir, "second.pdf"), overwrite = TRUE))
  stopifnot(second$age == 17.987654321, second$sex == "Male", second$raw_score == 85L)
  stopifnot(isTRUE(all.equal(second$percentile, predict_pui(model_asset, 17.987654321, "Male", 85)$percentile)))
  stopifnot(!identical(first$raw_score, second$raw_score))
  writeLines(c(sprintf("first_percentile=%.2f", first$percentile), sprintf("second_percentile=%.2f", second$percentile)),
             file.path(output_dir, "expected.txt"), useBytes = TRUE)

  # Invalid inputs must block generating or retaining a downloadable result.
  session$setInputs(individual_age = 18.001)
  stopifnot(!is.null(individual_error()))
  stopifnot(inherits(try(individual_result(), silent = TRUE), "try-error"))
  stopifnot(inherits(try(output$individual_pdf, silent = TRUE), "try-error"))
})
cat("Synthetic PDF generation, changed-input result, and invalid-input blocking: PASS\n")
