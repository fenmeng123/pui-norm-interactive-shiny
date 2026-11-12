# Synthetic workbooks only. Run from the project root.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
library(shiny)
source("app/R/predict_pui.R", encoding = "UTF-8")
model_asset <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")

server <- function(input, output, session) {
  language <- reactive(if (identical(input$app_language, "en")) "en" else "zh")
  consent_granted <- reactiveVal(TRUE)
  source("app/components/batch_server.R", local = TRUE, encoding = "UTF-8")
}

input_file <- tempfile(fileext = ".xlsx")
test_data <- data.frame(person = c("A", "B", "C"), age = c(9, 12.35, 18),
                        sex = c("Male", "Female", "Male"), score = c(17, 40, 85),
                        note = c("alpha", "beta", "gamma"))
openxlsx::write.xlsx(test_data, input_file)
shiny::testServer(server, {
  session$setInputs(batch_file = data.frame(name = "input.xlsx", size = file.info(input_file)$size,
                                            type = "", datapath = input_file))
  review <- batch_review()
  if (!isTRUE(review$ok)) stop(review$message)
  expected <- predict_pui(model_asset, test_data$age, test_data$sex, test_data$score)$percentile
  stopifnot(identical(review$last_column, ncol(test_data)))
  stopifnot(isTRUE(all.equal(review$percentile, expected)))
  downloaded <- output$batch_download
  output_data <- openxlsx::read.xlsx(downloaded, check.names = FALSE)
  stopifnot(identical(names(output_data), c(names(test_data), "百分位常模分")))
  stopifnot(isTRUE(all.equal(output_data[names(test_data)], test_data, check.attributes = FALSE)))
  stopifnot(isTRUE(all.equal(output_data[["百分位常模分"]], expected, tolerance = 1e-12)))
  cat("Synthetic Excel upload, append, download and read-back: PASS\n")
})

invalid_file <- tempfile(fileext = ".xlsx")
invalid_data <- test_data
invalid_data$age[2] <- 19
openxlsx::write.xlsx(invalid_data, invalid_file)
shiny::testServer(server, {
  session$setInputs(batch_file = data.frame(name = "bad.xlsx", size = file.info(invalid_file)$size,
                                            type = "", datapath = invalid_file))
  stopifnot(!isTRUE(batch_review()$ok), grepl("3", batch_review()$message, fixed = TRUE))
  cat("Invalid row blocks whole workbook: PASS\n")
})

formula_file <- tempfile(fileext = ".xlsx")
workbook <- openxlsx::createWorkbook()
openxlsx::addWorksheet(workbook, "Data")
openxlsx::writeData(workbook, 1, test_data)
openxlsx::writeFormula(workbook, 1, x = "1+1", startCol = 5, startRow = 2)
openxlsx::saveWorkbook(workbook, formula_file, overwrite = TRUE)
shiny::testServer(server, {
  session$setInputs(batch_file = data.frame(name = "formula.xlsx", size = file.info(formula_file)$size,
                                            type = "", datapath = formula_file))
  stopifnot(!isTRUE(batch_review()$ok))
  cat("Workbook formula rejected: PASS\n")
})
