# Population curves use the fitted model's P50 and full-distribution SD.
trajectory_ui <- bslib::nav_panel(
  shiny::textOutput("nav_trajectory", inline = TRUE),
  value = "trajectories",
  bslib::layout_sidebar(
    sidebar = bslib::sidebar(
      title = shiny::textOutput("trajectory_sidebar_title", inline = TRUE),
      shiny::radioButtons(
        "trajectory_sex", "性别组",
        choices = c("男性" = "Male", "女性" = "Female"),
        selected = "Male", inline = TRUE
      ),
      shiny::radioButtons(
        "trajectory_kind", "显示内容",
        choices = c("常模水平" = "p50", "个体差异" = "sd", "增长率" = "growth"),
        selected = "p50"
      ),
      shiny::sliderInput(
        "trajectory_age", "查看年龄（岁）",
        min = 9, max = 18, value = 14, step = 0.01, round = FALSE
      ),
      shiny::helpText(shiny::textOutput("trajectory_help", inline = TRUE))
    ),
    bslib::card(
      bslib::card_header(shiny::textOutput("trajectory_card_title", inline = TRUE)),
      shiny::tags$div(
        role = "group", `aria-labelledby` = "trajectory_card_title",
        `aria-describedby` = "trajectory_value trajectory_interpretation",
        plotly::plotlyOutput("trajectory_plot", height = "390px")
      ),
      shiny::textOutput("trajectory_value"),
      shiny::textOutput("trajectory_interpretation")
    ),
    bslib::card(
      bslib::card_header(shiny::textOutput("trajectory_explanation_title", inline = TRUE)),
      shiny::tags$p(shiny::textOutput("trajectory_explanation_p50", inline = TRUE)),
      shiny::tags$p(shiny::textOutput("trajectory_explanation_scale", inline = TRUE))
    )
  )
)
