# The upload control stays in the DOM when language changes, preserving the
# selected file. Text labels update separately through Shiny outputs.
batch_ui <- bslib::nav_panel(
  title = shiny::textOutput("nav_batch", inline = TRUE),
  value = "batch",
  bslib::layout_columns(
    col_widths = c(5, 7),
    bslib::card(
      bslib::card_header(shiny::textOutput("batch_upload_title", inline = TRUE)),
      shiny::textOutput("batch_input_description"),
      shiny::textOutput("batch_input_requirements"),
      shiny::downloadButton("batch_template", shiny::textOutput("batch_template_label", inline = TRUE)),
      shiny::br(), shiny::br(),
      shiny::fileInput("batch_file", shiny::textOutput("batch_file_label", inline = TRUE),
                       accept = ".xlsx", multiple = FALSE,
                       buttonLabel = shiny::textOutput("batch_browse_label", inline = TRUE),
                       placeholder = "")
    ),
    bslib::card(
      bslib::card_header(shiny::textOutput("batch_check_title", inline = TRUE)),
      shiny::textOutput("batch_workbook_requirements"),
      shiny::textOutput("batch_output_description"),
      shiny::textOutput("batch_status"),
      shiny::uiOutput("batch_download_ui")
    )
  )
)
