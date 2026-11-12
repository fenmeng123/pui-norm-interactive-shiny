# Synthetic end-to-end server check: identical individual and Excel inputs
# must use the same model and yield the same unrounded percentile.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
library(shiny)
source("app/R/predict_pui.R", encoding = "UTF-8")
source("app/components/yiat17_items.R", encoding = "UTF-8")
model_asset <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")
server <- function(input, output, session) {
  language <- reactive(if (identical(input$app_language, "en")) "en" else "zh")
  consent_granted <- reactiveVal(TRUE)
  source("app/components/individual_server.R", local = TRUE, encoding = "UTF-8")
  source("app/components/batch_server.R", local = TRUE, encoding = "UTF-8")
}
input_file <- tempfile(fileext = ".xlsx")
openxlsx::write.xlsx(data.frame(age = 14.5, sex = "Female", score = 36), input_file)
shiny::testServer(server, {
  session$setInputs(individual_age = 14.5, individual_sex = "Female", individual_score = 36,
                    batch_file = data.frame(name = "example.xlsx", size = file.info(input_file)$size,
                                            type = "", datapath = input_file))
  stopifnot(isTRUE(batch_review()$ok))
  stopifnot(isTRUE(all.equal(individual_result()$percentile, batch_review()$percentile, tolerance = 1e-13)))
  downloaded <- openxlsx::read.xlsx(output$batch_download)
  stopifnot(isTRUE(all.equal(individual_result()$percentile, downloaded[["百分位常模分"]], tolerance = 1e-12)))
})
unlink(input_file)
cat("Individual and Excel workflows give identical unrounded percentiles: PASS\n")
