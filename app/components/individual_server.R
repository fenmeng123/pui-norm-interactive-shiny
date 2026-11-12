# Per-session individual scoring. The original model, questionnaire items,
# response coding and fixed historical-period setting are not changed here.
output$nav_individual <- shiny::renderText(if (language() == "en") "Individual score" else "个人评分")
output$individual_sidebar_title <- shiny::renderText(if (language() == "en") "Your information" else "输入资料")
output$individual_sex_label <- shiny::renderText(if (language() == "en") "Model sex group" else "模型性别组")
output$individual_score_help <- shiny::renderText(if (language() == "en") "Enter an integer total from 17 to 85." else "请输入 17–85 的整数总分。")
output$individual_input_help <- shiny::renderText(if (language() == "en") {
  "Ages 9–18; the 17-item version excludes original items 4, 7 and 9."
} else {
  "年龄范围为 9–18 岁；17 题版本不含原 20 题中的第 4、7、9 题。"
})
output$questionnaire_title <- shiny::renderText(if (language() == "en") "17 items from the Internet Addiction Test-Revised (IAT-R)" else "Y-IAT 17 题在线作答")
output$questionnaire_instruction <- shiny::renderText(if (language() == "en") {
  "Select the answer that best describes your experience for each item. All 17 answers are required to calculate your score."
} else {
  "请选择每一题最符合您情况的选项。17 题均需作答，完成后自动计算总分与常模分。"
})
output$questionnaire_version_note <- shiny::renderText(if (language() == "en") {
  "Note. These 17 items come from the IAT-R published by Mak and Young (2020). Their wording differs from the Chinese Y-IAT used to develop this project’s reference norms."
} else {
  "本项目使用中文版 Y-IAT（Hou，2013）建立常模。"
})
output$questionnaire_source <- shiny::renderUI({
  citation_style <- "padding-inline-start: 0.5in; text-indent: -0.5in; line-height: 2; margin: 0; overflow-wrap: anywhere;"
  shiny::tags$section(`aria-labelledby` = "questionnaire_references_heading",
    shiny::tags$h3(id = "questionnaire_references_heading", class = "h6 fw-bold text-center",
      if (language() == "en") "References" else "参考文献"),
    shiny::p(lang = "en", style = citation_style,
      "Hou, Y. (2013). Young wangluo chengyin liangbiao [Young’s Internet Addiction Test]. In C. Wan & W. Jiang (Eds.),",
      shiny::tags$em("Zhonghua yixue tongji baike quanshu: Jiankang celiang fence"),
      "[Encyclopedia of Chinese medical statistics: Health measurement volume] (pp. 297–298). China Statistics Press."),
    shiny::p(lang = "en", style = citation_style,
      "Mak, K. K., & Young, K. S. (2020). Development and differential item functioning of the Internet Addiction Test-Revised (IAT-R): An item response theory approach.",
      shiny::tags$em("Cyberpsychology, Behavior, and Social Networking", .noWS = "after"), ", ",
      shiny::tags$em("23", .noWS = "after"), "(5), 312–328.",
      shiny::a("https://doi.org/10.1089/cyber.2019.0468", href = "https://doi.org/10.1089/cyber.2019.0468")),
    shiny::p(class = "mt-2", if (language() == "en")
      "The Chinese Y-IAT and the English IAT-R are copyrighted by their respective authors. The 17 items are shown here for research demonstration."
    else "中文版 Y-IAT 与英文版 IAT-R 的版权归各自作者所有。本应用呈现其中 17 题，供研究展示。")
  )
})
output$individual_result_title <- shiny::renderText(if (language() == "en") "Your reference result" else "个人常模结果")
output$individual_plot_description <- shiny::renderText(if (language() == "en") {
  "The orange point is the individual total; the five lines are reference centiles for the selected sex group. Centiles can coincide at the score endpoints because the model includes probability masses there."
} else {
  "橙色点表示个人总分，五条曲线为所选性别组的参考百分位。模型包含端点概率质量，因此部分曲线可能在最低分或最高分处重合。"
})

# Update labels and choices in place; input values and completed answers are
# passed back unchanged when a user switches languages.
shiny::observe({
  english <- language() == "en"
  mode <- shiny::isolate(input$individual_mode)
  if (is.null(mode) || length(mode) != 1L || is.na(mode)) mode <- "total"
  shiny::updateNumericInput(session, "individual_age", label = if (english) "Age (years)" else "年龄（岁）")
  shiny::updateRadioButtons(session, "individual_mode", label = if (english) "Input method" else "选择输入方式",
    choices = if (english) c("Enter total score" = "total", "Answer 17 items" = "items") else c("输入 17 题总分" = "total", "在线回答 17 题" = "items"), selected = mode)
  shiny::updateNumericInput(session, "individual_score", label = if (english) "Y-IAT 17-item total" else "Y-IAT 17 题总分")
  for (i in seq_len(nrow(yiat17_items))) {
    id <- paste0("yiat_item_", yiat17_items$original_number[i])
    selected <- shiny::isolate(input[[id]])
    if (is.null(selected) || length(selected) != 1L || is.na(selected)) selected <- character(0)
    wording <- if (english) yiat17_items$wording_en[i] else yiat17_items$wording[i]
    shiny::updateRadioButtons(session, id, label = paste0(i, ". ", wording),
      choices = if (english) yiat17_choices_en else yiat17_choices,
      selected = selected, inline = TRUE)
  }
})

individual_mode <- shiny::reactive({
  if (is.null(input$individual_mode)) "total" else input$individual_mode
})
questionnaire_answers <- shiny::reactive({
  vapply(yiat17_items$original_number, function(item) {
    answer <- input[[paste0("yiat_item_", item)]]
    if (length(answer) != 1L || is.na(answer) || !answer %in% as.character(1:5)) return(NA_integer_)
    as.integer(answer)
  }, integer(1))
})
output$questionnaire_progress <- shiny::renderText({
  count <- sum(!is.na(questionnaire_answers()))
  if (language() == "en") {
    if (count == nrow(yiat17_items)) return(sprintf("Completed %d / %d items. Total score: %d.", count, nrow(yiat17_items), sum(questionnaire_answers())))
    return(sprintf("Completed %d / %d items. Please answer all items.", count, nrow(yiat17_items)))
  }
  if (count == nrow(yiat17_items)) sprintf("已完成 %d / %d 题，总分为 %d。", count, nrow(yiat17_items), sum(questionnaire_answers())) else sprintf("已完成 %d / %d 题。请回答全部题目。", count, nrow(yiat17_items))
})

individual_error <- shiny::reactive({
  english <- language() == "en"
  if (is.null(input$individual_age) || length(input$individual_age) != 1L || !is.numeric(input$individual_age) || !is.finite(input$individual_age)) {
    return(if (english) "Please enter age." else "请填写年龄。")
  }
  if (input$individual_age < 9 || input$individual_age > 18) return(if (english) "Age must be between 9 and 18 years." else "年龄须在 9–18 岁之间。")
  if (is.null(input$individual_sex) || length(input$individual_sex) != 1L || is.na(input$individual_sex) || !input$individual_sex %in% c("Male", "Female")) {
    return(if (english) "Please select a model sex group." else "请选择模型性别组。")
  }
  if (identical(individual_mode(), "items")) {
    if (anyNA(questionnaire_answers())) return(if (english) "Please answer all 17 items." else "请回答全部 17 道题目。")
  } else if (identical(individual_mode(), "total")) {
    if (is.null(input$individual_score) || length(input$individual_score) != 1L || !is.numeric(input$individual_score) || !is.finite(input$individual_score)) {
      return(if (english) "Please enter the 17-item total." else "请填写 17 题总分。")
    }
    if (input$individual_score < 17 || input$individual_score > 85 || input$individual_score != round(input$individual_score)) {
      return(if (english) "The total must be an integer from 17 to 85." else "总分须为 17–85 的整数。")
    }
  } else return(if (english) "Please choose an input method." else "请选择有效的输入方式。")
  NULL
})

# Both entry methods use the same CDF predictor. Invalid/missing answers never
# fall back to a previously entered total or previously generated report.
individual_result <- shiny::reactive({
  shiny::req(consent_granted(), is.null(individual_error()))
  score <- if (identical(individual_mode(), "items")) sum(questionnaire_answers()) else input$individual_score
  predict_pui(model_asset, input$individual_age, input$individual_sex, score)
})

# Calculate reference quantiles on the same raw-score scale as the person.
individual_plot_data <- shiny::reactive({
  result <- individual_result()
  ages <- seq(9, 18, length.out = 181L)
  parameters <- predict_pui(model_asset, age = ages, sex = result$sex, raw_score = 17L)
  quantiles <- vapply(c(0.05, 0.25, 0.50, 0.75, 0.95), function(prob) {
    17 + 68 * gamlss.dist::qBEINF(prob, parameters$mu, parameters$sigma, parameters$nu, parameters$tau)
  }, numeric(length(ages)))
  data.frame(age = ages, p05 = quantiles[, 1], p25 = quantiles[, 2], p50 = quantiles[, 3], p75 = quantiles[, 4], p95 = quantiles[, 5])
})

# A high-contrast point and value label identify the person's position; these
# curves are descriptive reference centiles, not clinical thresholds.
individual_figure <- shiny::reactive({
  result <- individual_result()
  curve <- individual_plot_data()
  english <- language() == "en"
  long <- data.frame(
    age = rep(curve$age, 5),
    score = c(curve$p05, curve$p25, curve$p50, curve$p75, curve$p95),
    centile = factor(rep(c("P5", "P25", "P50", "P75", "P95"), each = nrow(curve)), levels = c("P5", "P25", "P50", "P75", "P95"))
  )
  label <- if (english) sprintf("Your score: %d\nPercentile: %.2f", result$raw_score, result$percentile) else sprintf("个人总分：%d\n百分位：%.2f", result$raw_score, result$percentile)
  ggplot2::ggplot(long, ggplot2::aes(x = age, y = score, colour = centile, linetype = centile)) +
    ggplot2::geom_line(linewidth = 0.65) +
    ggplot2::geom_vline(xintercept = result$age, colour = "#B45309", linetype = "dotted", linewidth = 0.5) +
    ggplot2::geom_point(data = result, ggplot2::aes(x = age, y = raw_score), inherit.aes = FALSE,
                        shape = 21, size = 4.5, stroke = 1, colour = "#7C2D12", fill = "#F97316") +
    ggplot2::annotate("label", x = result$age, y = result$raw_score, label = label,
      hjust = if (result$age > 14) 1.05 else -0.05,
      vjust = if (result$raw_score > 65) 1.1 else -0.1,
      colour = "#7C2D12", fill = "#FFF7ED", size = 3.2) +
    ggplot2::scale_colour_manual(values = c(P5 = "#64748B", P25 = "#0E7490", P50 = "#1D4ED8", P75 = "#0E7490", P95 = "#64748B"), name = if (english) "Reference centile" else "参考百分位") +
    ggplot2::scale_linetype_manual(values = c(P5 = "dotted", P25 = "dashed", P50 = "solid", P75 = "solid", P95 = "solid"), name = if (english) "Reference centile" else "参考百分位") +
    ggplot2::scale_x_continuous(breaks = 9:18, limits = c(9, 18)) +
    ggplot2::scale_y_continuous(limits = c(17, 85), breaks = seq(20, 80, 10)) +
    ggplot2::labs(x = if (english) "Age (years)" else "年龄（岁）", y = if (english) "Y-IAT 17-item total" else "Y-IAT 17 题总分",
      subtitle = if (english) "Curves: model reference centiles; orange point: your score" else "曲线：模型参考百分位；橙色点：个人总分") +
    ggplot2::theme_minimal(base_size = 11, base_family = getOption("pui.report.family", "sans")) +
    ggplot2::theme(legend.position = "bottom", plot.subtitle = ggplot2::element_text(size = 9))
})

output$individual_summary <- shiny::renderUI({
  shiny::req(consent_granted())
  error <- individual_error()
  if (!is.null(error)) return(shiny::tags$p(class = "text-muted", error))
  result <- individual_result()
  if (language() == "en") {
    shiny::tagList(shiny::tags$h2(sprintf("Percentile %.2f", result$percentile)),
      shiny::p(sprintf("The model estimates that %.2f%% of the reference group of the same age and sex would score at or below your total of %d.", result$percentile, result$raw_score)))
  } else {
    shiny::tagList(shiny::tags$h2(sprintf("%.2f 百分位", result$percentile)),
      shiny::p(sprintf("模型估计，同年龄、同性别参考人群中，约 %.2f%% 的人总分小于或等于您的 %d 分。", result$percentile, result$raw_score)))
  }
})
output$individual_plot <- shiny::renderPlot({ individual_figure() }, res = 110)
output$individual_pdf_button <- shiny::renderUI({
  shiny::req(consent_granted(), is.null(individual_error()))
  shiny::downloadButton("individual_pdf", if (language() == "en") "Download personal PDF" else "下载个人 PDF 报告")
})

output$individual_pdf <- shiny::downloadHandler(
  filename = function() if (language() == "en") "pui-reference-report-en.pdf" else "pui-reference-report-zh.pdf",
  contentType = "application/pdf",
  content = function(file) {
    shiny::req(consent_granted())
    result <- individual_result()
    figure <- individual_figure()
    english <- language() == "en"

    # Use an installed CJK font for the Chinese PDF; do not silently emit
    # missing glyphs on systems without a suitable Cairo device/font.
    family <- "sans"
    if (!english) {
      if (!capabilities("cairo") || !requireNamespace("systemfonts", quietly = TRUE)) stop("Chinese PDF requires Cairo and an installed Chinese font.")
      available <- unique(systemfonts::system_fonts()$family)
      preferred <- c("Microsoft YaHei", "Noto Sans CJK SC", "Noto Sans SC", "WenQuanYi Zen Hei", "SimHei", "STHeiti")
      found <- preferred[preferred %in% available]
      family <- getOption("pui.report.family", if (length(found)) found[1] else NULL)
      if (is.null(family)) stop("Chinese PDF requires a configured Chinese font.")
    }
    if (capabilities("cairo")) grDevices::cairo_pdf(filename = file, width = 8.27, height = 11.69, onefile = TRUE, family = family) else grDevices::pdf(file = file, width = 8.27, height = 11.69, onefile = TRUE)
    on.exit(grDevices::dev.off(), add = TRUE)
    figure <- figure + ggplot2::theme(text = ggplot2::element_text(family = family))
    grid::grid.newpage()
    grid::pushViewport(grid::viewport(layout = grid::grid.layout(4, 1, heights = grid::unit(c(0.08, 0.14, 0.59, 0.19), "npc"))))
    grid::pushViewport(grid::viewport(layout.pos.row = 1))
    grid::grid.text(if (english) "PUI PERSONAL REFERENCE REPORT" else "PUI 个人常模参考报告", x = 0.06, y = 0.5, just = "left", gp = grid::gpar(fontsize = 18, fontface = "bold", fontfamily = family))
    grid::popViewport()
    grid::pushViewport(grid::viewport(layout.pos.row = 2))
    age_text <- format(result$age, digits = 15, scientific = FALSE, trim = TRUE)
    summary <- if (english) {
      paste0("Age: ", age_text, " years    Sex group: ", result$sex,
        "\nY-IAT 17-item total: ", result$raw_score, "    Percentile: ", sprintf("%.2f", result$percentile),
        "\nGenerated: ", format(Sys.Date(), "%Y-%m-%d"))
    } else {
      paste0("年龄：", age_text, " 岁    性别组：", if (result$sex == "Male") "男" else "女",
        "\nY-IAT 17 题总分：", result$raw_score, "    常模百分位：", sprintf("%.2f", result$percentile),
        "\n生成日期：", format(Sys.Date(), "%Y-%m-%d"))
    }
    grid::grid.text(summary, x = 0.06, y = 0.9, just = c("left", "top"), gp = grid::gpar(fontsize = 11, lineheight = 1.5, fontfamily = family))
    grid::popViewport()
    print(figure, vp = grid::viewport(layout.pos.row = 3), newpage = FALSE)
    grid::pushViewport(grid::viewport(layout.pos.row = 4))
    note <- if (english) {
      paste0("The percentile is the estimated percentage of the reference group of the same age and sex\n",
        "who would score at or below this total. Clinical interpretation requires a professional assessment.\n",
        "The norms cover ages 9–18 and use the 17 items remaining after items 4, 7 and 9 are removed.\n",
        "Centiles can coincide at the lowest and highest scores because each has its own probability mass.\n",
        "Model: ", model_asset$source_model_id, "\nAsset: ", model_asset$format_version, "\nSource model SHA-256: ", model_asset$source_sha256)
    } else {
      paste0("百分位表示模型估计的同年龄、同性别参考人群中，总分小于或等于个人得分的百分比。\n",
        "临床解读需结合专业人员的综合评估。\n",
        "常模适用于 9–18 岁，使用剔除原第 4、7、9 题后保留的 17 题。\n",
        "模型包含端点概率质量，部分曲线可能在最低分或最高分处重合。\n",
        "模型：", model_asset$source_model_id, "\n预测资产：", model_asset$format_version,
        "\n源模型 SHA-256：", model_asset$source_sha256)
    }
    grid::grid.text(note, x = 0.06, y = 0.96, just = c("left", "top"), gp = grid::gpar(fontsize = 8.5, lineheight = 1.25, fontfamily = family))
    grid::popViewport(2)
  }
)
