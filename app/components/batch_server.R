# Objects below are created inside each Shiny session; no upload or result is
# placed in an application-wide cache or written to the project directory.
output$nav_batch <- shiny::renderText(if (language() == "en") "Batch scoring" else "批量评分")
output$batch_upload_title <- shiny::renderText(if (language() == "en") "Upload Excel" else "上传 Excel")
output$batch_input_description <- shiny::renderText({
  if (language() == "en") "Upload one .xlsx file (up to 5 MiB, 10,000 data rows and 100 columns), with age, sex and score in the first row."
  else "请上传一个 .xlsx 文件（最多 5 MiB、10,000 行数据、100 列），首行必须包含 age、sex、score 三列。"
})
output$batch_input_requirements <- shiny::renderText({
  if (language() == "en") "age: 9–18 years (decimals allowed); sex: Male or Female; score: integer 17-item total from 17 to 85."
  else "age：9–18 岁（可带小数）；sex：Male 或 Female；score：17 题总分，须为 17–85 的整数。"
})
output$batch_template_label <- shiny::renderText(if (language() == "en") "Download example template" else "下载示例模板")
output$batch_file_label <- shiny::renderText(if (language() == "en") "Select Excel file" else "选择 Excel 文件")
output$batch_browse_label <- shiny::renderText(if (language() == "en") "Browse..." else "选择文件…")
output$batch_check_title <- shiny::renderText(if (language() == "en") "Check and download" else "检查与下载")
output$batch_workbook_requirements <- shiny::renderText({
  if (language() == "en") "Use one visible worksheet with one participant per row. If your workbook uses formulas, merged cells, hidden rows or columns, charts, filters or data validation, paste the cell values into the example template."
  else "使用一个可见工作表，每位参与者占一行。如果原表含有公式、合并单元格、隐藏行列、图表、筛选或数据验证，请将数据以“粘贴值”方式放入示例模板。"
})
output$batch_output_description <- shiny::renderText({
  if (language() == "en") "Once all rows pass the checks, download a copy with a Normative percentile column after your original columns."
  else "所有行通过检查后，即可下载结果副本。新增的“百分位常模分”列位于原有各列之后。"
})

batch_review <- shiny::reactive({
  shiny::req(consent_granted())
  shiny::req(input$batch_file)
  upload <- input$batch_file

  # Shiny owns uploaded copies under tempdir()/24-hex-job-id/. Never delete a
  # caller's original workbook (including synthetic test fixtures elsewhere).
  on.exit({
    if (is.data.frame(upload) && nrow(upload) == 1L && file.exists(upload$datapath)) {
      parent <- normalizePath(dirname(upload$datapath), winslash = "/", mustWork = TRUE)
      root <- normalizePath(tempdir(), winslash = "/", mustWork = TRUE)
      if (identical(dirname(parent), root) && grepl("^[[:xdigit:]]{24}$", basename(parent))) {
        unlink(upload$datapath)
      }
    }
  }, add = TRUE)

  # Parser warnings can contain user strings; expose only fixed messages.
  tryCatch(withCallingHandlers({
    if (nrow(upload) != 1L || !grepl("\\.xlsx$", upload$name, ignore.case = TRUE)) {
      return(list(ok = FALSE, message = "请上传一个 .xlsx 文件。", message_en = "Upload one .xlsx file."))
    }
    file_size <- file.info(upload$datapath)$size
    if (length(file_size) != 1L || is.na(file_size) || file_size > 5 * 1024^2) {
      return(list(ok = FALSE, message = "请选择大小在 5 MiB 以内的文件。", message_en = "Choose a file of 5 MiB or less."))
    }
    archive <- utils::unzip(upload$datapath, list = TRUE)
    allowed_parts <- paste0("^(\\[Content_Types\\]\\.xml|_rels/\\.rels|docProps/(core|app)\\.xml|",
      "xl/(workbook\\.xml|_rels/workbook\\.xml\\.rels|styles\\.xml|sharedStrings\\.xml|",
      "theme/theme[0-9]+\\.xml|worksheets/sheet[0-9]+\\.xml|",
      "worksheets/_rels/sheet[0-9]+\\.xml\\.rels|printerSettings/printerSettings[0-9]+\\.bin))$")
    entries <- archive$Name[!grepl("/$", archive$Name)]
    if (!nrow(archive) || nrow(archive) > 100L || anyNA(archive$Length) ||
        any(archive$Length < 0) || sum(archive$Length) > 50 * 1024^2 ||
        anyDuplicated(tolower(archive$Name)) || any(!grepl(allowed_parts, entries)) ||
        any(grepl("(^/|:|\\\\|(^|/)\\.\\.?(/|$))", archive$Name))) {
      return(list(ok = FALSE, message = "请将数据以值粘贴到示例模板，保存为 .xlsx 后重新上传。", message_en = "Paste the values into the example template, save it as an .xlsx file and upload it again."))
    }
    # Read bounded XML without extracting it, closing every connection. DTDs
    # are unnecessary in XLSX and are rejected before either XML parser runs.
    read_workbook_xml <- function(entry) {
      con <- unz(upload$datapath, entry, open = "rb")
      on.exit(close(con), add = TRUE)
      expected_size <- archive$Length[match(entry, archive$Name)]
      bytes <- readBin(con, "raw", n = expected_size + 1L)
      if (length(bytes) != expected_size ||
          grepl("<!DOCTYPE|<!ENTITY", rawToChar(bytes), ignore.case = TRUE)) stop("Unsupported XML.")
      xml2::read_xml(bytes, options = "NONET")
    }
    xml_entries <- entries[grepl("\\.(xml|rels)$", entries)]
    xml <- setNames(lapply(xml_entries, read_workbook_xml), xml_entries)
    # Ordinary openxlsx templates contain a printer-settings binary. It is
    # never executed; bound and check its bytes before extraction too.
    for (entry in entries[grepl("\\.bin$", entries)]) {
      expected_size <- archive$Length[match(entry, archive$Name)]
      if (expected_size > 65536L) stop("Oversized printer settings.")
      con <- unz(upload$datapath, entry, open = "rb")
      bytes <- tryCatch(readBin(con, "raw", n = expected_size + 1L), finally = close(con))
      if (length(bytes) != expected_size) stop("Invalid archive size.")
    }
    # Reject external targets in every relationship file, not just the sheet.
    for (entry in grep("\\.rels$", names(xml), value = TRUE)) {
      nodes <- xml2::xml_find_all(xml[[entry]], "//*[local-name()='Relationship']")
      modes <- xml2::xml_attr(nodes, "TargetMode")
      targets <- xml2::xml_attr(nodes, "Target")
      if (any(!is.na(modes) & tolower(modes) == "external") || anyNA(targets) ||
          any(grepl("^[a-zA-Z]+:|^/|\\\\", targets))) stop("Unsupported relationship.")
    }
    # Reject advanced features rather than silently losing them when rewriting.
    advanced_parts <- "^xl/(drawings/|charts/|tables/|pivotTables/|pivotCache/|externalLinks/|embeddings/|comments|threadedComments/|vbaProject)"
    sheet_entries <- grep("^xl/worksheets/sheet[0-9]+\\.xml$", archive$Name, value = TRUE)
    if (length(xml2::xml_find_all(xml[["xl/workbook.xml"]], "//*[local-name()='sheet']")) != 1L ||
        length(sheet_entries) != 1L || any(grepl(advanced_parts, archive$Name, ignore.case = TRUE))) {
      return(list(ok = FALSE, message = "请将待评分数据单独保存为只含一个工作表的 .xlsx 文件。", message_en = "Save the scoring data in an .xlsx file containing one plain worksheet."))
    }
    # openxlsx can create unused drawing relationships for ordinary sheets;
    # the actual drawing parts are rejected above.
    sheet_rels <- grep("^xl/worksheets/_rels/.*\\.rels$", archive$Name, value = TRUE)
    for (entry in sheet_rels) {
      rel_xml <- xml[[entry]]
      rel_nodes <- xml2::xml_find_all(rel_xml, "//*[local-name()='Relationship']")
      rel_types <- xml2::xml_attr(rel_nodes, "Type")
      rel_mode <- xml2::xml_attr(rel_nodes, "TargetMode")
      if (anyNA(rel_types) || any(!grepl("/(drawing|vmlDrawing|printerSettings)$", rel_types)) ||
          any(!is.na(rel_mode) & rel_mode == "External")) {
        return(list(ok = FALSE, message = "请将单元格以值粘贴到模板，以移除链接和嵌入对象。", message_en = "Paste the cell values into the template to remove links and embedded objects."))
      }
    }
    sheet_xml <- xml[[sheet_entries]]
    cells <- xml2::xml_find_all(sheet_xml, "//*[local-name()='sheetData']/*[local-name()='row']/*[local-name()='c']")
    refs <- xml2::xml_attr(cells, "r")
    row_refs <- xml2::xml_attr(xml2::xml_find_all(sheet_xml, "//*[local-name()='sheetData']/*[local-name()='row']"), "r")
    if (!length(refs) || anyNA(refs) || any(!grepl("^[A-Z]{1,3}[1-9][0-9]{0,6}$", refs)) ||
        anyDuplicated(refs) || anyNA(row_refs) || any(!grepl("^[1-9][0-9]{0,6}$", row_refs))) stop("Invalid cell references.")
    cell_rows <- as.integer(sub("^[A-Z]+", "", refs))
    cell_cols <- openxlsx::convertFromExcelRef(refs)
    if (max(c(cell_rows, as.integer(row_refs))) > 10001L || max(cell_cols) > 100L ||
        max(cell_rows) * max(cell_cols) > 500000L) {
      return(list(ok = FALSE, message = "最多支持 10,000 行数据、100 列及 500,000 个矩形区域单元格。",
        message_en = "The limit is 10,000 data rows, 100 columns and 500,000 cells in the rectangular data area."))
    }
    unsupported <- paste0(
      "//*[local-name()='f' or local-name()='mergeCells' or local-name()='drawing' or ",
      "local-name()='legacyDrawing' or local-name()='tableParts' or ",
      "local-name()='hyperlinks' or local-name()='conditionalFormatting' or ",
      "local-name()='dataValidations' or local-name()='autoFilter' or ",
      "local-name()='sheetProtection' or local-name()='extLst'] | ",
      "//*[local-name()='row' or local-name()='col'][@hidden='1' or @hidden='true'] | ",
      "//*[local-name()='row'][@ht and number(@ht)=0] | ",
      "//*[local-name()='col'][@width and number(@width)=0]"
    )
    if (length(xml2::xml_find_all(sheet_xml, unsupported)) > 0L) {
      return(list(ok = FALSE, message = "请将数据以值粘贴到示例模板，每个单元格填写一个值。", message_en = "Paste the data into the example template as values, one value per cell."))
    }
    workbook_xml <- xml[["xl/workbook.xml"]]
    if (length(xml2::xml_find_all(workbook_xml,
        "//*[local-name()='definedName' or local-name()='workbookProtection']"))) stop("Unsupported workbook feature.")
    hidden_sheet <- xml2::xml_find_all(workbook_xml, "//*[local-name()='sheet'][@state='hidden' or @state='veryHidden']")
    if (length(hidden_sheet) > 0L) {
      return(list(ok = FALSE, message = "请将工作表设为可见后重新上传。", message_en = "Unhide the worksheet and upload the file again."))
    }

    # Own the extraction directory so success AND failure remove all parts.
    extraction <- tempfile("pui-workbook-")
    dir.create(extraction)
    on.exit(unlink(extraction, recursive = TRUE), add = TRUE)
    utils::unzip(upload$datapath, exdir = extraction)
    workbook <- openxlsx::loadWorkbook(extraction, isUnzipped = TRUE)
    header_row <- suppressWarnings(openxlsx::read.xlsx(
      workbook, sheet = 1, rows = 1, colNames = FALSE, skipEmptyCols = FALSE,
      skipEmptyRows = FALSE, na.strings = character(0)
    ))
    if (nrow(header_row) != 1L || ncol(header_row) == 0L) {
      return(list(ok = FALSE, message = "首行须为非空列名。", message_en = "The first row must contain non-empty column names."))
    }
    headers <- as.character(unlist(header_row[1, ], use.names = FALSE))
    data <- suppressWarnings(openxlsx::read.xlsx(
      workbook, sheet = 1, colNames = TRUE, check.names = FALSE,
      skipEmptyRows = FALSE, skipEmptyCols = FALSE, na.strings = character(0),
      sep.names = " "
    ))
    if (anyNA(headers) || any(!nzchar(trimws(headers))) || anyDuplicated(headers) ||
        !identical(headers, names(data))) {
      return(list(ok = FALSE, message = "请在首行为每一列填写唯一的列名。", message_en = "Give each column a unique name in the first row."))
    }
    if (!all(c("age", "sex", "score") %in% headers)) {
      return(list(ok = FALSE, message = "缺少必要列：age、sex 和 score。", message_en = "Required columns are missing: age, sex and score."))
    }
    required_numeric <- cell_rows > 1L & cell_cols %in% match(c("age", "score"), headers)
    cell_types <- xml2::xml_attr(cells, "t")
    if (any(required_numeric & !is.na(cell_types) & cell_types != "n")) {
      return(list(ok = FALSE, message = "请将 age 和 score 列中的单元格转换为 Excel 数值。",
        message_en = "Convert the cells in age and score to numeric Excel values."))
    }
    if (any(tolower(trimws(headers)) %in% c("percentile", "百分位常模分", "normative percentile"))) {
      return(list(ok = FALSE, message = "文件已含常模分列，请先移除该列以避免重复。", message_en = "A normative percentile column already exists. Remove it before scoring again."))
    }
    if (nrow(data) == 0L) return(list(ok = FALSE, message = "表格没有可评分的数据行。", message_en = "The worksheet has no data rows to score."))
    if (!is.numeric(data$age) || !is.numeric(data$score)) {
      return(list(ok = FALSE, message = "请在每行 age 和 score 单元格中填写数值。", message_en = "Enter numeric values for age and score in every row."))
    }
    invalid <- is.na(data$age) | !is.finite(data$age) | data$age < 9 | data$age > 18 |
      is.na(data$sex) | !as.character(data$sex) %in% c("Male", "Female") |
      is.na(data$score) | !is.finite(data$score) | data$score < 17 | data$score > 85 |
      data$score != round(data$score)
    if (any(invalid)) {
      bad_rows <- which(invalid) + 1L  # Excel row numbers include the header.
      listed_rows <- paste(utils::head(bad_rows, 12L), collapse = ", ")
      suffix <- if (length(bad_rows) > 12L) " 等" else ""
      return(list(ok = FALSE, message = paste0(
        "发现 ", length(bad_rows), " 行输入无效（Excel 行号：", listed_rows, suffix,
        "）。请检查年龄、性别和总分；全部修正后重新上传。"
      ), message_en = paste0("Invalid input in ", length(bad_rows), " row(s) (Excel row numbers: ",
                             listed_rows, if (length(bad_rows) > 12L) ", ..." else "",
                             "). Check age, sex and score, then correct and re-upload the file.")))
    }
    predictions <- predict_pui(model_asset, age = data$age, sex = as.character(data$sex), raw_score = data$score)
    list(ok = TRUE, message = paste0("已检查并计算 ", nrow(data), " 行。"),
         message_en = paste0("Checked and scored ", nrow(data), " row(s)."),
         last_column = ncol(data), percentile = predictions$percentile, workbook = workbook)
  }, warning = function(w) stop("Workbook parsing failed.", call. = FALSE)), error = function(e) {
    # Do not put paths, participant data or parser exception text into logs.
    list(ok = FALSE, message = "读取或计算失败。请确认文件是受支持的 .xlsx 普通数据表。",
         message_en = "Reading or scoring failed. Check that the file is a supported ordinary .xlsx data table.")
  })
})

output$batch_status <- shiny::renderText({
  shiny::req(consent_granted())
  if (is.null(input$batch_file)) {
    return(if (language() == "en") "Upload a file, or download the example template to check the format."
           else "请先上传文件；也可以下载示例模板查看格式。")
  }
  review <- batch_review()
  if (language() == "en") review$message_en else review$message
})

output$batch_download_ui <- shiny::renderUI({
  shiny::req(consent_granted())
  shiny::req(input$batch_file)
  shiny::req(isTRUE(batch_review()$ok))
  shiny::downloadButton("batch_download", if (language() == "en") "Download scored workbook" else "下载评分结果")
})

output$batch_template <- shiny::downloadHandler(
  filename = function() "PUI_scoring_template.xlsx",
  content = function(file) {
    shiny::req(consent_granted())
    example <- data.frame(age = c(10.5, 15), sex = c("Female", "Male"), score = c(30L, 45L))
    openxlsx::write.xlsx(example, file)
  },
  contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
)

output$batch_download <- shiny::downloadHandler(
  filename = function() "PUI_percentiles.xlsx",
  content = function(file) {
    shiny::req(consent_granted())
    review <- batch_review()
    shiny::req(isTRUE(review$ok))
    # A fresh copy avoids mutating the cached workbook across repeated downloads.
    workbook <- openxlsx::copyWorkbook(review$workbook)
    output_column <- data.frame(review$percentile, check.names = FALSE)
    names(output_column) <- if (language() == "en") "Normative percentile" else "百分位常模分"
    openxlsx::writeData(workbook, sheet = 1, x = output_column,
                        startCol = review$last_column + 1L, startRow = 1L)
    openxlsx::saveWorkbook(workbook, file, overwrite = TRUE)
  },
  contentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
)
