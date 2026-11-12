# Both input methods lead to the same individual scoring workflow.
individual_ui <- bslib::nav_panel(
  title = shiny::textOutput("nav_individual", inline = TRUE),
  value = "individual",
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = shiny::textOutput("individual_sidebar_title", inline = TRUE),
      shiny::numericInput("individual_age", "年龄（岁）", value = NA, min = 9, max = 18, step = 0.01),
      shiny::selectInput("individual_sex", shiny::textOutput("individual_sex_label", inline = TRUE),
        choices = c("请选择 / Select" = "", "男 / Male" = "Male", "女 / Female" = "Female")),
      shiny::radioButtons("individual_mode", "选择输入方式",
        choices = c("输入 17 题总分" = "total", "在线回答 17 题" = "items"), selected = "total"),
      shiny::conditionalPanel(
        condition = "input.individual_mode === 'total'",
        shiny::numericInput("individual_score", "Y-IAT 17 题总分", value = NA, min = 17, max = 85, step = 1),
        shiny::helpText(shiny::textOutput("individual_score_help", inline = TRUE))
      ),
      shiny::helpText(shiny::textOutput("individual_input_help", inline = TRUE))
    ),
    shiny::conditionalPanel(
      condition = "input.individual_mode === 'items'",
      bslib::card(
        bslib::card_header(shiny::textOutput("questionnaire_title", inline = TRUE)),
        shiny::p(shiny::textOutput("questionnaire_instruction", inline = TRUE)),
        shiny::p(shiny::textOutput("questionnaire_version_note", inline = TRUE)),
        shiny::uiOutput("questionnaire_source"),
        shiny::textOutput("questionnaire_progress"),
        lapply(seq_len(nrow(yiat17_items)), function(i) {
          shiny::radioButtons(
            inputId = paste0("yiat_item_", yiat17_items$original_number[i]),
            label = paste0(i, ". ", yiat17_items$wording[i]),
            choices = yiat17_choices, selected = character(0), inline = TRUE
          )
        })
      )
    ),
    bslib::card(
      bslib::card_header(shiny::textOutput("individual_result_title", inline = TRUE)),
      shiny::uiOutput("individual_summary"),
      shiny::tags$div(
        role = "img", `aria-labelledby` = "individual_result_title", `aria-describedby` = "individual_plot_description",
        shiny::plotOutput("individual_plot", height = "390px")
      ),
      shiny::textOutput("individual_plot_description"),
      shiny::uiOutput("individual_pdf_button")
    )
  )
)
