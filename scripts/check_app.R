# Run the local app's synthetic checks in separate, clean R sessions.
# Start from the project root. No real participant data or private model is used.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))

checks <- c(
  "batch_checks.R", "excel_extra_checks.R", "excel_preservation_checks.R",
  "bilingual_excel_checks.R", "questionnaire_checks.R", "questionnaire_language_updates.R",
  "individual_server_test.R", "personal_bilingual_checks.R", "personal_report_corner_checks.R",
  "pdf_extra_checks.R", "cross_workflow_checks.R", "trajectory_checks.R",
  "shell_consent_checks.R", "shell_audit_checks.R", "shell_session_isolation.R",
  "upload_hardening_checks.R"
)
if (!file.exists("app/app.R") || !all(file.exists(file.path("tests", checks)))) {
  stop("Run this script from the project root; all app files and checks must be present.")
}

# Test reports are synthetic and live in this R session's temporary directory.
# The operating system/R temporary-directory lifecycle removes them afterwards.
Sys.setenv(PUI_PDF_QA_DIR = tempdir(), PUI_PERSONAL_QA_DIR = tempdir())
rscript <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
failed <- character()
for (check in checks) {
  cat("\n--- ", check, " ---\n", sep = "")
  status <- system2(rscript, args = c("--vanilla", shQuote(file.path("scripts", "run_check.R")),
    shQuote(file.path("tests", check))))
  if (!identical(status, 0L)) failed <- c(failed, check)
}

cat("\n--- Standalone prediction asset ---\n")
status <- system2(rscript, args = c("--vanilla", shQuote(file.path("tests", "check_standalone.R")),
  shQuote(file.path("app", "models", "pui_prediction_v1.rds")),
  shQuote(file.path("app", "R", "predict_pui.R"))))
if (!identical(status, 0L)) failed <- c(failed, "check_standalone.R")

if (length(failed)) stop("Checks failed: ", paste(failed, collapse = ", "))
cat("\nAll synthetic application checks passed. Browser and deployment testing remain separate.\n")
