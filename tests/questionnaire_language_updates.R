# Inspect the actual Shiny input update messages, including unanswered items.
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

testServer(server, {
  messages <- list()
  session$sendInputMessage <- function(inputId, message) {
    messages[[inputId]] <<- message
  }
  session$setInputs(app_language = "zh", individual_mode = "items",
                    individual_age = 14.5, individual_sex = "Female",
                    yiat_item_1 = "3")
  stopifnot(grepl("Hou, Y. (2013)", output$questionnaire_source$html, fixed = TRUE))
  messages <- list()
  session$setInputs(app_language = "en")
  first <- messages[["yiat_item_1"]]
  second <- messages[["yiat_item_2"]]
  stopifnot(grepl("Mak and Young (2020)", output$questionnaire_version_note, fixed = TRUE),
            grepl("differs from the Chinese Y-IAT", output$questionnaire_version_note, fixed = TRUE),
            grepl("10.1089/cyber.2019.0468", output$questionnaire_source$html, fixed = TRUE))
  for (i in seq_len(nrow(yiat17_items))) {
    id <- paste0("yiat_item_", yiat17_items$original_number[i])
    stopifnot(identical(as.character(messages[[id]]$label$html), paste0(i, ". ", yiat17_items$wording_en[i])))
  }
  stopifnot(identical(first$value, "3"), length(second$value) == 0L,
            grepl('class="radio-inline"', first$options, fixed = TRUE),
            grepl('class="radio-inline"', second$options, fixed = TRUE),
            grepl('value="3" checked="checked"', first$options, fixed = TRUE),
            !grepl('checked="checked"', second$options, fixed = TRUE),
            grepl("Completed 1 / 17", output$questionnaire_progress, fixed = TRUE),
            is.na(questionnaire_answers()[2]))
  stopifnot(inherits(try(individual_result(), silent = TRUE), "try-error"))
})
cat("Language updates preserve answered and unanswered radio states and inline layout: PASS\n")
