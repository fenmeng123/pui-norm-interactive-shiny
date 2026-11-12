# Verify the plotted scientific quantities with synthetic age/sex inputs.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
library(shiny)
source("app/R/predict_pui.R", encoding = "UTF-8")
model_asset <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")
server <- function(input, output, session) {
  language <- shiny::reactive(if (identical(input$app_language, "en")) "en" else "zh")
  consent_granted <- shiny::reactiveVal(TRUE)
  source("app/components/trajectories_server.R", local = TRUE, encoding = "UTF-8")
}

shiny::testServer(server, {
  messages <- list()
  session$sendInputMessage <- function(inputId, message) messages[[inputId]] <<- message
  for (sex in c("Male", "Female")) {
    session$setInputs(app_language = "zh", trajectory_sex = sex, trajectory_kind = "p50", trajectory_age = 9)
    curve <- trajectory_data()
    stopifnot(nrow(curve) == 901L, curve$age[1] == 9, tail(curve$age, 1) == 18)
    parameters <- predict_pui(model_asset, age = curve$age, sex = sex, raw_score = 17L)
    p50 <- 100 * gamlss.dist::qBEINF(0.5, parameters$mu, parameters$sigma, parameters$nu, parameters$tau)
    stopifnot(max(abs(curve$p50 - p50)) < 1e-10)
    stopifnot(all(curve$p25 <= curve$p50 & curve$p50 <= curve$p75), all(curve$sd >= 0))
    stopifnot(grepl("9.00", output$trajectory_value, fixed = TRUE))
    for (kind in c("sd", "growth")) {
      session$setInputs(trajectory_kind = kind, trajectory_age = 18)
      stopifnot(grepl("18.00", output$trajectory_value, fixed = TRUE))
      stopifnot(nzchar(output$trajectory_interpretation))
    }
    session$setInputs(app_language = "en")
    sex_update <- messages[["trajectory_sex"]]
    stopifnot(identical(sex_update$value, sex),
              grepl('class="radio-inline"', sex_update$options, fixed = TRUE))
    stopifnot(grepl("growth", output$trajectory_value, ignore.case = TRUE))
    stopifnot(identical(output$nav_trajectory, "Reference curves"))
    stopifnot(identical(input$trajectory_sex, sex), identical(input$trajectory_kind, "growth"))
  }
  for (sex in c("Female", "Male")) {
    session$setInputs(trajectory_sex = sex, trajectory_age = 14.5)
    curve <- trajectory_data()
    for (kind in c("p50", "sd", "growth")) {
      session$setInputs(trajectory_kind = kind)
      figure <- plotly::plotly_build(trajectory_figure())$x
      line <- tail(figure$data, 1L)[[1]]
      stopifnot(identical(as.numeric(line$x), curve$age), identical(as.numeric(line$y), curve[[kind]]),
                figure$config$scrollZoom, figure$config$doubleClick == "reset",
                figure$layout$dragmode == "zoom", figure$layout$hovermode == "x",
                identical(as.numeric(figure$layout$xaxis$range), c(9, 18)),
                trajectory_marker()$value == curve[[kind]][curve$age == 14.5])
      if (kind == "p50") {
        band <- figure$data[[1]]
        stopifnot(identical(as.numeric(band$y), c(curve$p25, rev(curve$p75))),
                  identical(as.numeric(band$x), c(curve$age, rev(curve$age))),
                  band$hoverinfo == "skip", grepl("%{text}", line$hovertemplate[1], fixed = TRUE))
        for (column in c("p25", "p50", "p75")) {
          displayed <- sprintf("%s　%.2f", toupper(column), curve[[column]])
          stopifnot(all(mapply(grepl, displayed, as.character(line$text), MoreArgs = list(fixed = TRUE))))
        }
      } else {
        stopifnot(length(figure$data) == 1L, grepl("%{y:.2f}", line$hovertemplate[1], fixed = TRUE))
      }
    }
  }
})
cat("Trajectory model quantities, sex groups, view switches and boundaries: PASS\n")
