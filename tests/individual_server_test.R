# Synthetic data only. Run from the project root in a fresh R session.
library(shiny)
if (.Platform$OS.type == "windows") Sys.setlocale("LC_CTYPE", ".UTF-8")
source("app/R/predict_pui.R", encoding = "UTF-8")
source("app/components/yiat17_items.R", encoding = "UTF-8")
model_asset <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")
server <- function(input, output, session) {
  language <- reactive(if (identical(input$app_language, "en")) "en" else "zh")
  consent_granted <- reactiveVal(TRUE)
  source("app/components/individual_server.R", local = TRUE, encoding = "UTF-8")
}

testServer(server, {
  session$setInputs(individual_age = 14.5, individual_sex = "Female", individual_score = 36)
  result <- individual_result()
  reference <- predict_pui(model_asset, 14.5, "Female", 36)
  stopifnot(isTRUE(all.equal(result$percentile, reference$percentile)))
  stopifnot(nrow(individual_plot_data()) == 181L, inherits(individual_figure(), "ggplot"))

  # The downloadable file and screen share the same reactive result.
  pdf_path <- output$individual_pdf
  stopifnot(file.exists(pdf_path), file.info(pdf_path)$size > 1000)
  pdf_copy <- Sys.getenv("PUI_INDIVIDUAL_TEST_PDF", unset = "")
  if (nzchar(pdf_copy)) {
    stopifnot(file.copy(pdf_path, pdf_copy, overwrite = TRUE))
    cat("Synthetic PDF:", pdf_copy, "\n")
  }

  session$setInputs(individual_score = 50)
  updated <- individual_result()
  stopifnot(updated$raw_score == 50, updated$percentile != result$percentile)
  stopifnot(isTRUE(all.equal(updated$percentile, predict_pui(model_asset, 14.5, "Female", 50)$percentile)))
  session$setInputs(individual_age = 18.001)
  stopifnot(!is.null(individual_error()))
  stopifnot(inherits(try(individual_result(), silent = TRUE), "try-error"))
  session$setInputs(individual_age = 9, individual_score = 17)
  stopifnot(is.null(individual_error()), is.finite(individual_result()$percentile))
})
cat("Individual scoring, stale-result and PDF checks passed.\n")
