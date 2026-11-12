# Synthetic-only additional workbook contract and preservation checks.
local({
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
library(shiny)
source("app/R/predict_pui.R", encoding = "UTF-8")
model_asset <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")
server <- function(input, output, session) {
  language <- reactive(if (identical(input$app_language, "en")) "en" else "zh")
  consent_granted <- reactiveVal(TRUE)
  source("app/components/batch_server.R", local = TRUE, encoding = "UTF-8")
}

test_dir <- tempfile("pui_excel_tests_")
dir.create(test_dir)
on.exit(unlink(test_dir, recursive = TRUE), add = TRUE)

# The first and third rows intentionally duplicate: duplicates are observations,
# not errors, and must remain in their original positions.
valid <- data.frame(
  person = c("A", "B", "A"), age = c(10.125, 18, 10.125),
  sex = c("Female", "Male", "Female"), score = c(36, 85, 36),
  note = c("same", "other", "same"), stringsAsFactors = FALSE
)
input_path <- file.path(test_dir, "valid.xlsx")
book <- openxlsx::createWorkbook()
openxlsx::addWorksheet(book, "Data")
openxlsx::writeData(book, "Data", valid)
special_style <- openxlsx::createStyle(fontColour = "#FF0000", textDecoration = "bold")
openxlsx::addStyle(book, "Data", special_style, rows = 2, cols = 1, stack = TRUE)
openxlsx::setColWidths(book, "Data", cols = 1, widths = 22)
openxlsx::saveWorkbook(book, input_path)
input_hash <- digest::digest(file = input_path, algo = "sha256", serialize = FALSE)
invalid_path <- file.path(test_dir, "invalid_after_valid.xlsx")
invalid_after_valid <- valid
invalid_after_valid$age[1] <- 19
openxlsx::write.xlsx(invalid_after_valid, invalid_path)

shiny::testServer(server, {
  session$setInputs(batch_file = data.frame(name = "synthetic.xlsx", size = file.info(input_path)$size,
                                            type = "", datapath = input_path))
  stopifnot(isTRUE(batch_review()$ok))
  expected <- predict_pui(model_asset, valid$age, valid$sex, valid$score)$percentile
  output_path <- output$batch_download
  result <- openxlsx::read.xlsx(output_path, check.names = FALSE)
  stopifnot(identical(names(result), c(names(valid), "百分位常模分")))
  stopifnot(isTRUE(all.equal(result[names(valid)], valid, check.attributes = FALSE)))
  stopifnot(isTRUE(all.equal(result[["百分位常模分"]], expected, tolerance = 1e-12)))
  stopifnot(result[["百分位常模分"]][1] == result[["百分位常模分"]][3])
  stopifnot(identical(digest::digest(file = input_path, algo = "sha256", serialize = FALSE), input_hash))
  repeat_result <- openxlsx::read.xlsx(output$batch_download, check.names = FALSE)
  stopifnot(isTRUE(all.equal(result, repeat_result, check.attributes = FALSE)))

  # Compare workbook cell style and width of a pre-existing column after rewrite.
  saved <- openxlsx::loadWorkbook(output_path)
  styles <- saved$styleObjects
  style_match <- vapply(styles, function(s) identical(s$sheet, "Data") &&
                          2L %in% s$rows && 1L %in% s$cols &&
                          "BOLD" %in% s$style$fontDecoration, logical(1))
  stopifnot(any(style_match))
  original_width <- openxlsx::loadWorkbook(input_path)$colWidths[[1]][1]
  output_width <- saved$colWidths[[1]][1]
  stopifnot(identical(original_width, output_width))
  cat("Valid rows, duplicates, original file, extra columns and selected style/width: PASS\n")

  session$setInputs(batch_file = data.frame(name = "invalid.xlsx", size = file.info(invalid_path)$size,
                                            type = "", datapath = invalid_path))
  stopifnot(!isTRUE(batch_review()$ok))
  stopifnot(inherits(try(output$batch_download, silent = TRUE), "try-error"))
  cat("Repeated download and replacement by invalid workbook: PASS\n")
})

check_rejected <- function(label, workbook) {
  path <- file.path(test_dir, paste0(label, ".xlsx"))
  openxlsx::saveWorkbook(workbook, path, overwrite = TRUE)
  shiny::testServer(server, {
    session$setInputs(batch_file = data.frame(name = "synthetic.xlsx", size = file.info(path)$size,
                                              type = "", datapath = path))
    if (isTRUE(batch_review()$ok)) stop(paste("Expected rejection:", label))
    cat(label, ": PASS\n")
  })
}

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
openxlsx::writeData(book, "Data", valid)
openxlsx::writeData(book, "Data", "percentile", startCol = 6, startRow = 1)
check_rejected("existing_percentile", book)

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
openxlsx::writeData(book, "Data", valid)
openxlsx::writeData(book, "Data", "age", startCol = 5, startRow = 1)
check_rejected("duplicate_header", book)

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
openxlsx::writeData(book, "Data", valid[1, ], startRow = 1)
openxlsx::writeData(book, "Data", valid[2, ], startRow = 4, colNames = FALSE)
check_rejected("blank_internal_row", book)

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
invalid <- valid; invalid$age[2] <- 8.999
openxlsx::writeData(book, "Data", invalid)
check_rejected("out_of_range_age", book)

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
invalid <- valid; invalid$score[2] <- 36.5
openxlsx::writeData(book, "Data", invalid)
check_rejected("non_integer_score", book)

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
invalid <- valid; invalid$sex[2] <- "Unknown"
openxlsx::writeData(book, "Data", invalid)
check_rejected("unsupported_sex", book)

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
openxlsx::writeData(book, "Data", valid)
openxlsx::addWorksheet(book, "Second")
check_rejected("multiple_sheets", book)

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
openxlsx::writeData(book, "Data", valid)
openxlsx::mergeCells(book, "Data", cols = 6:7, rows = 1)
check_rejected("merged_cells", book)

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
openxlsx::writeData(book, "Data", valid)
openxlsx::setColWidths(book, "Data", cols = 5, widths = 10, hidden = TRUE)
check_rejected("hidden_column", book)

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
openxlsx::writeData(book, "Data", valid)
openxlsx::writeFormula(book, "Data", "17+19", startCol = 4, startRow = 2)
check_rejected("formula", book)

book <- openxlsx::createWorkbook(); openxlsx::addWorksheet(book, "Data")
openxlsx::writeData(book, "Data", valid)
openxlsx::setRowHeights(book, "Data", rows = 2, heights = 0)
check_rejected("zero_height_row", book)
})

