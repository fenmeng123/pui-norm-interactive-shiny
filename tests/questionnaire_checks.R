# Synthetic answers only. Optionally compare the embedded item bank with the
# upstream dictionary supplied in PUI_YIAT_DICTIONARY.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
library(shiny)
source("app/R/predict_pui.R", encoding = "UTF-8")
source("app/components/yiat17_items.R", encoding = "UTF-8")
model_asset <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")

expected_items <- setdiff(1:20, c(4, 7, 9))
stopifnot(identical(yiat17_items$original_number, expected_items))
stopifnot(identical(unname(yiat17_choices), as.character(1:5)))
stopifnot(identical(names(yiat17_choices), c("几乎没有", "偶尔", "有时", "经常", "总是")))
stopifnot(nrow(yiat17_items) == 17L, all(nzchar(yiat17_items$wording)))

dictionary_path <- Sys.getenv("PUI_YIAT_DICTIONARY", unset = "")
if (nzchar(dictionary_path)) {
  dictionary <- readxl::read_excel(dictionary_path, sheet = "Original_Dictionary")
  keys <- paste0("IAT_", expected_items)
  index <- match(keys, dictionary$Variable)
  stopifnot(!anyNA(index), !anyDuplicated(dictionary$Variable[index]))
  entries <- dictionary[index, ]
  stopifnot(identical(as.character(entries$ItemWording), yiat17_items$wording))
  stopifnot(all(entries$Reverse_Scored == FALSE), all(entries$Expected_Min == 1), all(entries$Expected_Max == 5))
  expected_coding <- "1=几乎没有;2=偶尔;3=有时;4=经常;5=总是;"
  stopifnot(all(gsub("[[:space:]]", "", entries$CodingSchem) == expected_coding))
  cat("All 17 item texts, response codes and scoring flags match the source dictionary.\n")
} else {
  cat("Source dictionary comparison skipped: PUI_YIAT_DICTIONARY not set.\n")
}

server <- function(input, output, session) {
  language <- reactive(if (identical(input$app_language, "en")) "en" else "zh")
  consent_granted <- reactiveVal(TRUE)
  source("app/components/individual_server.R", local = TRUE, encoding = "UTF-8")
}
testServer(server, {
  session$setInputs(individual_age = 14.5, individual_sex = "Female", individual_score = 36, individual_mode = "total")
  direct <- individual_result()
  stopifnot(direct$raw_score == 36L)

  # Switching modes must not reuse a stale total while the questionnaire is empty.
  session$setInputs(individual_mode = "items")
  stopifnot(inherits(try(individual_result(), silent = TRUE), "try-error"))
  stopifnot(all(is.na(questionnaire_answers())))
  stopifnot(grepl("0 / 17", output$questionnaire_progress, fixed = TRUE))

  answers <- setNames(as.list(rep("1", 17)), paste0("yiat_item_", expected_items))
  do.call(session$setInputs, answers[1:16])
  stopifnot(inherits(try(individual_result(), silent = TRUE), "try-error"))
  do.call(session$setInputs, answers[17])
  stopifnot(individual_result()$raw_score == 17L)
  stopifnot(isTRUE(all.equal(individual_result()$percentile, predict_pui(model_asset, 14.5, "Female", 17)$percentile)))

  answers[] <- "5"
  do.call(session$setInputs, answers)
  stopifnot(individual_result()$raw_score == 85L)
  stopifnot(isTRUE(all.equal(individual_result()$percentile, predict_pui(model_asset, 14.5, "Female", 85)$percentile)))

  answers[] <- as.character(rep(1:5, length.out = 17))
  do.call(session$setInputs, answers)
  expected_total <- sum(as.integer(unlist(answers)))
  stopifnot(individual_result()$raw_score == expected_total)
  stopifnot(isTRUE(all.equal(individual_result()$percentile, predict_pui(model_asset, 14.5, "Female", expected_total)$percentile)))

  session$setInputs(yiat_item_1 = "6")
  stopifnot(inherits(try(individual_result(), silent = TRUE), "try-error"))
  stopifnot(inherits(try(output$individual_pdf, silent = TRUE), "try-error"))
  session$setInputs(individual_mode = "total")
  stopifnot(individual_result()$raw_score == 36L)
  session$setInputs(individual_mode = "items")
  stopifnot(inherits(try(individual_result(), silent = TRUE), "try-error"))
})
cat("Questionnaire scoring, missing/invalid answers, mode changes and shared predictor: PASS\n")
