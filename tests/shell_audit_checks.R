# Inspect first-session modal, server gate, localized About content and decline
# message in separate synthetic Shiny sessions. This is not a browser test.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
library(shiny)
project_dir <- getwd()
setwd(file.path(project_dir, "app"))
app_environment <- new.env(parent = globalenv())
source("app.R", local = app_environment, encoding = "UTF-8")

server <- function(input, output, session) {
  session$userData$modal_events <- list()
  session$userData$custom_events <- list()
  session$sendModal <- function(type, message) {
    session$userData$modal_events <- c(session$userData$modal_events, list(list(type = type, message = message)))
  }
  session$sendCustomMessage <- function(type, message) {
    session$userData$custom_events <- c(session$userData$custom_events, list(type))
  }
  app_environment$server(input, output, session)
}

testServer(server, {
  session$flushReact()
  events <- session$userData$modal_events
  stopifnot(length(events) == 1L, identical(events[[1]]$type, "show"))
  modal_html <- events[[1]]$message$html
  stopifnot(grepl("disclaimer_ack", modal_html, fixed = TRUE),
            grepl("disclaimer_continue", modal_html, fixed = TRUE),
            grepl("disclaimer_decline", modal_html, fixed = TRUE),
            grepl("使用说明", modal_html, fixed = TRUE),
            grepl("Using PUI Norms", modal_html, fixed = TRUE),
            grepl("server running this app", modal_html, fixed = TRUE))
  stopifnot(inherits(try(output$main_app, silent = TRUE), "try-error"))
  stopifnot(inherits(try(output$trajectory_value, silent = TRUE), "try-error"))
  session$setInputs(disclaimer_ack = FALSE, disclaimer_continue = 1)
  stopifnot(inherits(try(output$main_app, silent = TRUE), "try-error"))
  session$setInputs(disclaimer_ack = TRUE, disclaimer_continue = 2)
  stopifnot(!inherits(try(output$main_app, silent = TRUE), "try-error"))
  session$setInputs(app_language = "zh")
  about_zh <- output$about_content$html
  stopifnot(grepl("Kunru Song", about_zh, fixed = TRUE),
            grepl("Kunrusong97@gmail.com", about_zh, fixed = TRUE),
            grepl("版权", about_zh, fixed = TRUE))
  session$setInputs(app_language = "en")
  about_en <- output$about_content$html
  stopifnot(grepl("Kunru Song", about_en, fixed = TRUE),
            grepl("Kunrusong97@gmail.com", about_en, fixed = TRUE),
            grepl("copyright", about_en, ignore.case = TRUE))

  # Execute the code users can copy from About. Exercise both the example
  # and the CSV branch in a temporary copy of the two scoring files.
  zh_code <- xml2::xml_text(xml2::xml_find_all(xml2::read_html(about_zh), "//pre/code"))
  en_code <- xml2::xml_text(xml2::xml_find_all(xml2::read_html(about_en), "//pre/code"))
  stopifnot(length(zh_code) == 5L, identical(zh_code, en_code),
            requireNamespace("gamlss.dist", quietly = TRUE))
  tutorial_dir <- tempfile("pui-tutorial-")
  for (path in c("R/predict_pui.R", "models/pui_prediction_v1.rds")) {
    target <- file.path(tutorial_dir, "app", path)
    dir.create(dirname(target), recursive = TRUE)
    stopifnot(file.copy(path, target))
  }
  old_dir <- setwd(tutorial_dir)
  tryCatch({
    example <- new.env()
    for (step in c(1, 2, 4, 5)) eval(parse(text = en_code[step]), example)
    scored <- read.csv("pui_scored.csv")
    stopifnot(nrow(scored) == 2L, round(scored$pui_percentile[1], 2) == 50.75)
    csv <- data.frame(id = c("004", "001"), age = c(18, 9),
                      sex = c("Male", "Female"), score = c(85, 17))
    write.csv(csv, "my_sample.csv", row.names = FALSE)
    for (step in c(3, 4, 5)) eval(parse(text = en_code[step]), example)
    scored <- read.csv("pui_scored.csv", colClasses = c(id = "character"))
    expected <- predict_pui(app_environment$model_asset, csv$age, csv$sex, csv$score)
    stopifnot(identical(scored$id, csv$id),
              isTRUE(all.equal(scored$pui_percentile, expected$percentile)))
  }, finally = setwd(old_dir))
})

testServer(server, {
  session$flushReact()
  stopifnot(length(session$userData$modal_events) == 1L)
  session$setInputs(disclaimer_decline = 1)
  stopifnot("closeDeclinedPage" %in% unlist(session$userData$custom_events))
  exit_html <- output$main_app$html
  stopifnot(grepl("You have exited", exit_html, fixed = TRUE),
            grepl("close this tab", exit_html, fixed = TRUE))
  session$setInputs(disclaimer_ack = TRUE, disclaimer_continue = 1)
  stopifnot(grepl("You have exited", output$main_app$html, fixed = TRUE))
})
setwd(project_dir)
cat("Modal content, session gate, decline fallback and localized author/copyright: PASS\n")
