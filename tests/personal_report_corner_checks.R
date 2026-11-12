# Synthetic endpoint cases; run from the project root with PUI_PERSONAL_QA_DIR.
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
  for (lang in c("zh", "en")) {
    for (sex in c("Female", "Male")) {
      for (age in c(9, 18)) {
        for (score in c(17, 85)) {
          session$setInputs(app_language = lang, individual_mode = "total", individual_age = age,
                            individual_sex = sex, individual_score = score)
          result <- individual_result()
          reference <- predict_pui(model_asset, age, sex, score)
          stopifnot(isTRUE(all.equal(result$percentile, reference$percentile)))
          if (age == 9 && sex == "Female" && score == 17) {
            # In this synthetic example both lower centiles coincide at the
            # minimum, while the full CDF includes the endpoint probability.
            curve <- individual_plot_data()
            stopifnot(curve$p05[1] == 17, curve$p25[1] == 17, result$percentile > 25)
          }
          stopifnot(grepl(if (lang == "en") "Centiles can coincide" else "曲线可能", output$individual_plot_description))
          figure_data <- ggplot2::ggplot_build(individual_figure())$data
          stopifnot(identical(figure_data[[3]]$x, as.numeric(age)),
                    identical(figure_data[[3]]$y, as.numeric(score)))
          filename <- sprintf("corner_%s_%s_%d_%d.pdf", lang, sex, age, score)
          stopifnot(file.copy(output$individual_pdf, file.path(output_dir, filename), overwrite = TRUE))
        }
      }
    }
  }
})
cat("Endpoint scores, exact marker coordinates and bilingual PDF generation: PASS\n")
