# PUI Norms. Copyright (c) 2026 Kunru Song.
# SPDX-License-Identifier: GPL-3.0-only
# The model is loaded once per R process; user inputs remain in each session.
if (.Platform$OS.type == "windows" && !grepl("UTF-8", Sys.getlocale("LC_CTYPE"), ignore.case = TRUE)) {
  try(Sys.setlocale("LC_CTYPE", ".UTF-8"), silent = TRUE)
}
library(shiny)
library(bslib)
options(shiny.maxRequestSize = 5 * 1024^2, shiny.sanitize.errors = TRUE)

source("R/predict_pui.R", encoding = "UTF-8")
source("R/report_fonts.R", encoding = "UTF-8")
configure_pui_fonts()
options(pui.report.family = pui_report_family())
model_asset <- load_pui_prediction_asset("models/pui_prediction_v1.rds")
source("components/trajectories_ui.R", encoding = "UTF-8")
source("components/yiat17_items.R", encoding = "UTF-8")
source("components/individual_ui.R", encoding = "UTF-8")
source("components/batch_ui.R", encoding = "UTF-8")

# Browsers permit window.close() only in certain contexts. If it is blocked,
# the server-rendered exit page remains in place and no function is activated.
ui <- htmltools::attachDependencies(tagList(
  tags$head(tags$script(HTML(
    "document.addEventListener('DOMContentLoaded', function() { Shiny.addCustomMessageHandler('closeDeclinedPage', function(message) { window.close(); }); });"
  ))),
  uiOutput("main_app")
), bslib::bs_theme_dependencies(bslib::bs_theme(version = 5)))

server <- function(input, output, session) {
  # Both values are per session; checking the box alone does not enable access.
  consent_granted <- reactiveVal(FALSE)
  consent_declined <- reactiveVal(FALSE)
  language <- reactive({ if (identical(input$app_language, "en")) "en" else "zh" })

  session$onFlushed(function() {
    showModal(modalDialog(
      title = "使用说明 / Using PUI Norms",
      size = "l", easyClose = FALSE,
      tags$p(tags$strong("中文")),
      tags$p("输入年龄、性别组和 17 题总分，可查看该分数在同年龄、同性别参考人群中的百分位。常模适用于 9–18 岁。临床判断需由专业人员结合其他评估资料作出。"),
      tags$p("输入和上传的数据由运行应用的服务器处理。预览时请使用合成数据，省去姓名等身份信息。要在自己的电脑上为研究样本评分，请参阅“关于”页的 R 教程。"),
      tags$hr(),
      tags$p(tags$strong("English")),
      tags$p("Enter age, sex group and the 17-item total to see where the score falls among people of the same age and sex in the reference population. The norms cover ages 9–18. Clinical judgments require a qualified professional to consider other assessment information."),
      tags$p("The server running this app processes entries and uploads. Use synthetic data in this preview and omit identifying information such as names. To score your study sample on your own computer, follow the R tutorial on the About page."),
      checkboxInput("disclaimer_ack",
        "我已阅读并同意以上使用说明。 / I have read and agree to these terms.",
        value = FALSE),
      footer = tagList(
        actionButton("disclaimer_decline", "不同意并退出 / Decline and exit"),
        actionButton("disclaimer_continue", "同意并继续 / Agree and continue", class = "btn-primary")
      )
    ))
  }, once = TRUE)

  observeEvent(input$disclaimer_continue, {
    if (!isTRUE(input$disclaimer_ack)) {
      showNotification("请先勾选同意。 / Please check the agreement box first.", type = "warning")
      return()
    }
    if (isTRUE(consent_declined()) || isTRUE(consent_granted())) return()
    consent_granted(TRUE)
    removeModal()
    # Register session functionality only after explicit agreement. Component
    # reactives and downloads also check consent_granted() before processing.
    source("components/trajectories_server.R", local = TRUE, encoding = "UTF-8")
    source("components/individual_server.R", local = TRUE, encoding = "UTF-8")
    source("components/batch_server.R", local = TRUE, encoding = "UTF-8")
  }, ignoreInit = TRUE)

  observeEvent(input$disclaimer_decline, {
    consent_granted(FALSE)
    consent_declined(TRUE)
    removeModal()
    session$sendCustomMessage("closeDeclinedPage", list())
  }, ignoreInit = TRUE)

  output$main_app <- renderUI({
    if (isTRUE(consent_declined())) {
      return(div(style = "max-width: 52rem; margin: 6rem auto; padding: 1.5rem;",
        h2("已退出 / You have exited"),
        p("您可以关闭此标签页。"),
        p("You can close this tab.")
      ))
    }
    req(isTRUE(consent_granted()))
    page_navbar(
      window_title = "PUI Norms",
      title = textOutput("app_title", inline = TRUE),
      id = "section", fillable = FALSE,
      trajectory_ui,
      individual_ui,
      batch_ui,
      nav_panel(
        title = textOutput("nav_about", inline = TRUE), value = "about",
        card(div(style = "width: 100%; max-width: 80ch; margin-inline: auto;", uiOutput("about_content")))
      ),
      nav_spacer(),
      nav_item(div(style = "min-width: 155px; padding: 8px 12px 0;",
        selectInput("app_language", label = "Language / 语言",
          choices = c("简体中文" = "zh", "English" = "en"), selected = "zh", width = "155px")
      ))
    )
  })

  output$app_title <- renderText({
    req(consent_granted())
    if (language() == "en") "PUI Norms" else "PUI 常模"
  })
  output$nav_about <- renderText({
    req(consent_granted())
    if (language() == "en") "About" else "关于"
  })
  output$about_content <- renderUI({
    req(consent_granted())
    english <- language() == "en"
    tagList(
      h2(if (english) "How the PUI norms work" else "PUI 常模的建模原理"),
      p(if (english)
        "We used generalized additive models for location, scale and shape (GAMLSS) to estimate the distribution of Chinese Y-IAT total scores by age and sex. A beta distribution with probability masses at both endpoints (BEINF) represents the lowest and highest possible totals as well as the scores between them. The model allows the location and spread of the interior scores to vary with age and sex, including nonlinear age trends. A person’s percentile is the estimated percentage of their reference group scoring at or below their total."
      else
        "本研究使用位置、尺度和形状的广义可加模型（GAMLSS），估计中文版 Y-IAT 总分在不同年龄和性别组中的分布。模型采用两端膨胀的贝塔分布（BEINF），分别描述取得最低分、最高分的概率以及两者之间的分数分布。中间分数的位置和离散程度可随年龄和性别组而变化，年龄趋势可以是非线性的。个人百分位表示模型估计的同年龄、同性别参考人群中，总分小于或等于个人得分的百分比。"),
      h2(if (english) "Score your own sample in R" else "用 R 在本地计算自己样本的 PUI 常模分"),
      tags$ol(
        tags$li(h3(class = "h5", if (english) "Open the project and load the model" else "打开项目并加载模型"),
          p(if (english)
            "Unzip the project package and open R in the folder containing app/. You can request the package from the app author using the email below. The scoring function reads the saved model parameters. This example uses R 4.5.2 and the project records gamlss.dist 6.1-1 in app/renv.lock."
          else
            "解压项目包，在含有 app/ 的目录中打开 R。可通过本页末尾的邮箱向应用作者索取项目包。评分函数直接读取已拟合的模型参数。本例使用 R 4.5.2，项目在 app/renv.lock 中记录的 gamlss.dist 版本为 6.1-1。"),
          tags$pre(tags$code('if (!requireNamespace("gamlss.dist", quietly = TRUE)) {
  install.packages("gamlss.dist", repos = "https://cloud.r-project.org")
}
source("app/R/predict_pui.R", encoding = "UTF-8")
model <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")'))),
        tags$li(h3(class = "h5", if (english) "Prepare one row per participant" else "按每位参与者一行整理数据"),
          p(if (english)
            "Use age in years from 9 to 18 inclusive (decimals allowed), sex coded Male or Female, and score as the integer sum of all 17 responses (17–85). Omit original items 4, 7 and 9 and sum the remaining responses, each scored 1–5. A missing answer leaves the total missing. Start with these synthetic rows."
          else
            "age 填周岁，范围为 9–18 岁，含两端，可用小数。sex 填 Male 或 Female。score 填 17 题原始总分：剔除原第 4、7、9 题，将其余各题的 1–5 分直接相加，得到 17–85 的整数。缺答时总分记为缺失。先用以下合成数据试算。"),
          tags$pre(tags$code('dat <- data.frame(
  age = c(14.5, 12), sex = c("Female", "Male"), score = c(36L, 45L)
)')),
          p(if (english)
            "For your sample, replace the data.frame() block with the CSV import below. Keep additional columns as needed. Check the three required fields for missing or out-of-range values before scoring."
          else
            "使用自己的样本时，用下面的 CSV 导入语句替换上面的 data.frame() 示例。可保留其他列。评分前请核对三个必需字段的缺失值和取值范围。"),
          tags$pre(tags$code('dat <- read.csv("my_sample.csv", colClasses = "character", check.names = FALSE)
stopifnot(all(c("age", "sex", "score") %in% names(dat)))
dat$age <- as.numeric(dat$age)
dat$score <- as.numeric(dat$score)'))),
        tags$li(h3(class = "h5", if (english) "Calculate each person’s percentile" else "逐行计算百分位"),
          p(if (english)
            "Pass the three columns to predict_pui(). The function applies the same reference model as the app, with the period fixed at Post-pandemic. Append the percentile in the original row order."
          else
            "将三列数据传给 predict_pui()。函数与应用使用同一个参考模型，预测时期统一固定为 Post-pandemic。将返回的百分位按原行序添加到样本表中。"),
          tags$pre(tags$code('stopifnot(nrow(dat) > 0, all(c("age", "sex", "score") %in% names(dat)))
result <- predict_pui(model, age = dat$age, sex = dat$sex, raw_score = dat$score)
dat$pui_percentile <- result$percentile
head(dat)'))),
        tags$li(h3(class = "h5", if (english) "Read and save the results" else "解读并保存结果"),
          p(if (english)
            "The first synthetic row gives a percentile of 50.75 when rounded to two decimals. The model estimates that 50.75% of the reference group of the same age and sex would score at or below that total. Export the table with the computed precision for further analysis."
          else
            "合成示例第一行的百分位保留两位小数为 50.75，即模型估计同年龄、同性别参考人群中约 50.75% 的人总分小于或等于该行总分。下列代码将原始计算结果写入新文件，供后续分析使用。"),
          tags$pre(tags$code('write.csv(dat, "pui_scored.csv", row.names = FALSE, fileEncoding = "UTF-8")')))
      ),
      p(strong(if (english) "App author" else "应用作者"), " · Kunru Song · ",
        a("Kunrusong97@gmail.com", href = "mailto:Kunrusong97@gmail.com")),
      p(paste(if (english) "App copyright ©" else "应用版权 ©", format(Sys.Date(), "%Y"), "Kunru Song"),
        if (english) " · Source code license" else " · 源码许可证",
        a("GNU GPL v3 (GPL-3.0-only)", href = "https://www.gnu.org/licenses/gpl-3.0.html"))
    )
  })
}

shinyApp(ui = ui, server = server)
