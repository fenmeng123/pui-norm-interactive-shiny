# Synthetic inputs only. Run from the project root with PUI_PERSONAL_QA_DIR set.
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
output_dir <- Sys.getenv("PUI_PERSONAL_QA_DIR", unset = "")
if (!nzchar(output_dir) || !dir.exists(output_dir)) stop("PUI_PERSONAL_QA_DIR must be an existing temporary directory.")

testServer(server, {
  session$setInputs(app_language = "zh", individual_mode = "total", individual_age = 14.5, individual_sex = "Female", individual_score = 36)
  result_zh <- individual_result()
  reference <- predict_pui(model_asset, 14.5, "Female", 36)
  stopifnot(isTRUE(all.equal(result_zh$percentile, reference$percentile)))
  curves <- individual_plot_data()
  stopifnot(nrow(curves) == 181L, all(curves$p05 <= curves$p25 & curves$p25 <= curves$p50 & curves$p50 <= curves$p75 & curves$p75 <= curves$p95))
  p05 <- 17 + 68 * gamlss.dist::qBEINF(.05, reference$mu, reference$sigma, reference$nu, reference$tau)
  p95 <- 17 + 68 * gamlss.dist::qBEINF(.95, reference$mu, reference$sigma, reference$nu, reference$tau)
  stopifnot(abs(curves$p05[which(curves$age == 14.5)] - p05) < 1e-10, abs(curves$p95[which(curves$age == 14.5)] - p95) < 1e-10)
  # Every centile line has its own colour/linetype pair in both plot and PDF.
  line_data <- ggplot2::ggplot_build(individual_figure())$data[[1]]
  stopifnot(nrow(unique(line_data[, c("colour", "linetype")])) == 5L)
  stopifnot(file.copy(output$individual_pdf, file.path(output_dir, "zh.pdf"), overwrite = TRUE))

  session$setInputs(app_language = "en")
  result_en <- individual_result()
  stopifnot(identical(result_zh, result_en), identical(output$nav_individual, "Individual score"))
  stopifnot(file.copy(output$individual_pdf, file.path(output_dir, "en.pdf"), overwrite = TRUE))

  # Switching language after questionnaire completion retains all responses.
  answers <- setNames(as.list(as.character(rep(1:5, length.out = 17))), paste0("yiat_item_", yiat17_items$original_number))
  session$setInputs(individual_mode = "items")
  stopifnot(inherits(try(individual_result(), silent = TRUE), "try-error"))
  do.call(session$setInputs, answers)
  total <- sum(as.integer(unlist(answers)))
  stopifnot(individual_result()$raw_score == total)
  session$setInputs(app_language = "zh")
  stopifnot(individual_result()$raw_score == total, identical(questionnaire_answers(), as.integer(unlist(answers))))
  stopifnot(isTRUE(all.equal(individual_result()$percentile, predict_pui(model_asset, 14.5, "Female", total)$percentile)))

  session$setInputs(individual_age = 17.987654321, individual_mode = "total", individual_score = 85, individual_sex = "Male", app_language = "en")
  stopifnot(file.copy(output$individual_pdf, file.path(output_dir, "precise_age.pdf"), overwrite = TRUE))
  session$setInputs(individual_age = 9, individual_mode = "total", individual_score = 17, individual_sex = "Female", app_language = "zh")
  stopifnot(file.copy(output$individual_pdf, file.path(output_dir, "lower_corner.pdf"), overwrite = TRUE))
  session$setInputs(individual_age = 18.001)
  stopifnot(inherits(try(individual_result(), silent = TRUE), "try-error"))
  stopifnot(inherits(try(output$individual_pdf, silent = TRUE), "try-error"))
  consent_granted(FALSE)
  session$setInputs(individual_age = 14.5)
  stopifnot(inherits(try(individual_result(), silent = TRUE), "try-error"))
})
cat("Bilingual personal result, five centiles, input retention, PDF and consent checks: PASS\n")
