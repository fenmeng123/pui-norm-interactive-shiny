# Synthetic workbook only: preserve difficult but ordinary text and numeric
# cells while appending a language-specific percentile column.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
library(shiny)
source("app/R/predict_pui.R", encoding = "UTF-8")
model_asset <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")
server <- function(input, output, session) {
  language <- reactive(if (identical(input$app_language, "en")) "en" else "zh")
  consent_granted <- reactiveVal(TRUE)
  source("app/components/batch_server.R", local = TRUE, encoding = "UTF-8")
}

input_path <- tempfile(fileext = ".xlsx")
example <- data.frame(age = c(9, 14.125, 18), sex = c("Female", "Male", "Female"),
                      score = c(17, 44, 85), stringsAsFactors = FALSE)
example[["ID with spaces"]] <- c("00001", "中 文", "  padded  ")
example[["free text"]] <- c("quoted \"text\"", "a & b < c", "line one\nline two")
openxlsx::write.xlsx(example, input_path)
original <- as.data.frame(readxl::read_excel(input_path, .name_repair = "minimal",
                                            trim_ws = FALSE), check.names = FALSE)
stopifnot(identical(original[["ID with spaces"]], example[["ID with spaces"]]))
# Windows Excel serialization normalizes a line feed to CRLF. The scored
# workbook is compared to the actual uploaded workbook, including its CRLF.
stopifnot(identical(gsub("\r\n", "\n", original[["free text"]], fixed = TRUE), example[["free text"]]))

testServer(server, {
  session$setInputs(app_language = "en", batch_file = data.frame(name = "example.xlsx",
    size = file.info(input_path)$size, type = "", datapath = input_path))
  stopifnot(isTRUE(batch_review()$ok))
  result <- as.data.frame(readxl::read_excel(output$batch_download,
    .name_repair = "minimal", trim_ws = FALSE), check.names = FALSE)
  stopifnot(identical(names(result), c(names(example), "Normative percentile")))
  difference <- all.equal(result[names(example)], original, check.attributes = FALSE)
  if (!isTRUE(difference)) stop(paste(difference, collapse = "; "))
  stopifnot(isTRUE(all.equal(result[["Normative percentile"]],
    predict_pui(model_asset, example$age, example$sex, example$score)$percentile,
    tolerance = 1e-12)))
})
unlink(input_path)

# The documented contract requires actual Excel numbers, not numeric-looking
# text. This prevents silent coercion when values have been stored as strings.
text_path <- tempfile(fileext = ".xlsx")
text_example <- example
text_example$age <- as.character(text_example$age)
openxlsx::write.xlsx(text_example, text_path)
testServer(server, {
  session$setInputs(batch_file = data.frame(name = "text.xlsx",
    size = file.info(text_path)$size, type = "", datapath = text_path))
  stopifnot(!isTRUE(batch_review()$ok))
  stopifnot(inherits(try(output$batch_download, silent = TRUE), "try-error"))
})
unlink(text_path)
cat("Synthetic extra columns, leading zeros, Unicode, whitespace and multiline text: PASS\n")
cat("Numeric-looking text in required numeric column is rejected: PASS\n")
