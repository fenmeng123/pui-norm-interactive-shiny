# Two synthetic Shiny sessions must retain independent consent and inputs.
if (.Platform$OS.type == "windows") invisible(Sys.setlocale("LC_CTYPE", ".UTF-8"))
library(shiny)
options(shiny.allowoutputreads = TRUE)
project_dir <- getwd()
setwd(file.path(project_dir, "app"))
app_environment <- new.env(parent = globalenv())
source("app.R", local = app_environment, encoding = "UTF-8")

first <- MockShinySession$new()
second <- MockShinySession$new()
withReactiveDomain(first, app_environment$server(first$input, first$output, first))
withReactiveDomain(second, app_environment$server(second$input, second$output, second))
withReactiveDomain(first, first$flushReact())
withReactiveDomain(second, second$flushReact())

withReactiveDomain(first, first$setInputs(disclaimer_ack = TRUE, disclaimer_continue = 1,
                individual_mode = "total", individual_age = 14.5,
                individual_sex = "Female", individual_score = 36))
first_summary <- withReactiveDomain(first, isolate(first$output$individual_summary))
stopifnot(grepl("50.75", first_summary$html),
          is.null(isolate(second$input$individual_age)),
          inherits(try(withReactiveDomain(second, isolate(second$output$main_app)), silent = TRUE), "try-error"))

withReactiveDomain(second, second$setInputs(disclaimer_ack = TRUE, disclaimer_continue = 1,
  app_language = "en", individual_mode = "total", individual_age = 17,
  individual_sex = "Male", individual_score = 70))
other_summary <- withReactiveDomain(second, isolate(second$output$individual_summary))
stopifnot(grepl("Percentile", other_summary$html),
          !grepl("50.75", other_summary$html),
          grepl("50.75", withReactiveDomain(first, isolate(first$output$individual_summary))$html))
withReactiveDomain(second, second$setInputs(disclaimer_decline = 1))
second_summary <- withReactiveDomain(second, isolate(second$output$main_app))
stopifnot(grepl("You have exited", second_summary$html, fixed = TRUE),
          grepl("50.75", withReactiveDomain(first, isolate(first$output$individual_summary))$html))

withReactiveDomain(first, first$setInputs(individual_score = 50))
stopifnot(!grepl("50.75", withReactiveDomain(first, isolate(first$output$individual_summary))$html))
first$close()
second$close()
setwd(project_dir)
cat("Two independent synthetic sessions keep consent and inputs separate: PASS\n")
