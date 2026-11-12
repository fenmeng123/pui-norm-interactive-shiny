# One synthetic check per fresh R process, with production font setup.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L || !file.exists(args[1])) stop("Supply one check script.")
source("app/R/report_fonts.R", encoding = "UTF-8")
configure_pui_fonts("app/fonts")
options(pui.report.family = pui_report_family())
source(args[1], encoding = "UTF-8")
