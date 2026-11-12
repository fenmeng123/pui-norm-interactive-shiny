# Synthetic session tests for consent and language state. Run from project root.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
library(shiny)
project_dir <- getwd()
setwd(file.path(project_dir, "app"))
app_environment <- new.env(parent = globalenv())
source("app.R", local = app_environment, encoding = "UTF-8")
synthetic_workbook <- tempfile(fileext = ".xlsx")
openxlsx::write.xlsx(data.frame(age = 14.5, sex = "Female", score = 36), synthetic_workbook)

testServer(app_environment$server, {
  session$flushReact()
  stopifnot(!consent_granted(), !consent_declined())
  stopifnot(inherits(try(output$main_app, silent = TRUE), "try-error"))
  session$setInputs(disclaimer_ack = FALSE, disclaimer_continue = 1)
  stopifnot(!consent_granted())
  session$setInputs(disclaimer_ack = TRUE)
  stopifnot(!consent_granted())
  session$setInputs(disclaimer_continue = 2)
  stopifnot(consent_granted(), !consent_declined())
  stopifnot(identical(language(), "zh"))
  # The real application server must register its components after agreement.
  session$setInputs(individual_mode = "total", individual_age = 14.5,
                    individual_sex = "Female", individual_score = 36)
  stopifnot(grepl("50.75", output$individual_summary$html))
  stopifnot(file.exists(output$individual_pdf))
  stopifnot(grepl("上传", output$batch_status))
  session$setInputs(batch_file = data.frame(name = "synthetic.xlsx", size = file.info(synthetic_workbook)$size,
                                            type = "", datapath = synthetic_workbook))
  stopifnot(grepl("1 行", output$batch_status))
  zh_workbook <- openxlsx::read.xlsx(output$batch_download, check.names = FALSE, sep.names = " ")
  stopifnot("百分位常模分" %in% names(zh_workbook),
            abs(zh_workbook[["百分位常模分"]] - predict_pui(app_environment$model_asset, 14.5, "Female", 36)$percentile) < 1e-10)
  session$setInputs(app_language = "en")
  stopifnot(identical(language(), "en"), identical(output$nav_about, "About"),
            grepl("50.75", output$individual_summary$html), grepl("scored 1", output$batch_status))
  en_workbook <- openxlsx::read.xlsx(output$batch_download, check.names = FALSE, sep.names = " ")
  stopifnot("Normative percentile" %in% names(en_workbook),
            identical(zh_workbook[["百分位常模分"]], en_workbook[["Normative percentile"]]))
  session$setInputs(app_language = "zh")
  stopifnot(identical(language(), "zh"), identical(output$nav_about, "关于"))
})

testServer(app_environment$server, {
  session$flushReact()
  session$setInputs(disclaimer_decline = 1)
  stopifnot(!consent_granted(), consent_declined())
  session$setInputs(disclaimer_ack = TRUE, disclaimer_continue = 1)
  stopifnot(!consent_granted(), consent_declined())
})
setwd(project_dir)
unlink(synthetic_workbook)
cat("Consent requires a checked box and continuation; decline blocks access; language switches: PASS\n")
