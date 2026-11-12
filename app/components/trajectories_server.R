# Labels update in place so changing languages retains the selected age and view.
output$nav_trajectory <- shiny::renderText(if (language() == "en") "Reference curves" else "常模轨迹")
output$trajectory_sidebar_title <- shiny::renderText(if (language() == "en") "Choose a reference curve" else "选择参考轨迹")
output$trajectory_help <- shiny::renderText(if (language() == "en")
  "Hover to read values. Drag a box or scroll to zoom, use the toolbar to pan, and double-click to reset. The slider marks an age."
else "悬停查看读数，拖框或滚轮缩放。选择图上方的平移工具可拖动视野，双击恢复全图。滑块用于标记年龄。")
output$trajectory_card_title <- shiny::renderText(if (language() == "en") "PUI reference curves: ages 9–18" else "9–18 岁 PUI 人群参考轨迹")
output$trajectory_explanation_title <- shiny::renderText(if (language() == "en") "How to read these curves" else "如何理解这些轨迹")
output$trajectory_explanation_p50 <- shiny::renderText(if (language() == "en") {
  "P50 is the median score for each age in the selected sex group. The shaded band extends from the 25th to the 75th percentile of the modelled score distribution."
} else {
  "P50 是所选性别组在各年龄的模型中位数。阴影的下界和上界分别是参考分布的第 25 和第 75 百分位。"
})
output$trajectory_explanation_scale <- shiny::renderText(if (language() == "en") {
  "The graph rescales raw totals of 17–85 to a severity scale of 0–100. Individual variation is the standard deviation on this scale. Growth rate is the change in P50 per year of age. For a person’s percentile, use Individual score."
} else {
  "绘图时将 17–85 的原始总分线性换算为 0–100 的严重程度分。个体差异用该量尺上的标准差表示，增长率是 P50 随年龄每年的变化率。个人百分位可在“个人评分”页查看。"
})
shiny::observe({
  english <- language() == "en"
  selected_sex <- shiny::isolate(input$trajectory_sex)
  selected_kind <- shiny::isolate(input$trajectory_kind)
  if (is.null(selected_sex)) selected_sex <- "Male"
  if (is.null(selected_kind)) selected_kind <- "p50"
  shiny::updateRadioButtons(session, "trajectory_sex", label = if (english) "Sex group" else "性别组",
    choices = if (english) c("Male" = "Male", "Female" = "Female") else c("男性" = "Male", "女性" = "Female"),
    selected = selected_sex, inline = TRUE)
  shiny::updateRadioButtons(session, "trajectory_kind", label = if (english) "View" else "显示内容",
    choices = if (english) c("Median and centiles" = "p50", "Individual variation" = "sd", "Growth rate" = "growth") else c("常模水平" = "p50", "个体差异" = "sd", "增长率" = "growth"),
    selected = selected_kind)
  shiny::updateSliderInput(session, "trajectory_age", label = if (english) "Age (years)" else "查看年龄（岁）")
})

# All curves are calculated from the same prediction asset used for scoring.
# A score is required by the shared predictor, but does not affect its four
# distribution parameters; the lower endpoint is used here.
trajectory_data <- shiny::reactive({
  shiny::req(consent_granted())
  shiny::req(input$trajectory_sex)
  ages <- seq(9, 18, by = 0.01)
  parameters <- predict_pui(model_asset, age = ages, sex = input$trajectory_sex, raw_score = 17L)

  # Full BEINF quantiles and moments include the probability masses at 0 and 1.
  p25 <- 100 * gamlss.dist::qBEINF(0.25, mu = parameters$mu, sigma = parameters$sigma, nu = parameters$nu, tau = parameters$tau)
  p50 <- 100 * gamlss.dist::qBEINF(0.50, mu = parameters$mu, sigma = parameters$sigma, nu = parameters$nu, tau = parameters$tau)
  p75 <- 100 * gamlss.dist::qBEINF(0.75, mu = parameters$mu, sigma = parameters$sigma, nu = parameters$nu, tau = parameters$tau)
  denominator <- 1 + parameters$nu + parameters$tau
  mean_y <- (parameters$mu + parameters$tau) / denominator
  second_moment <- (parameters$mu^2 + parameters$mu * (1 - parameters$mu) * parameters$sigma^2 + parameters$tau) / denominator
  variance_y <- second_moment - mean_y^2
  if (any(variance_y < -1e-12)) stop("Model-implied variance is negative.")
  sd <- 100 * sqrt(pmax(variance_y, 0))

  # The five-point interior, central near-boundary and one-sided boundary
  # differences reproduce the upstream S3.9 growth-rate calculation.
  n <- length(ages)
  growth <- numeric(n)
  middle <- 3:(n - 2L)
  growth[middle] <- (p50[middle - 2L] - 8 * p50[middle - 1L] + 8 * p50[middle + 1L] - p50[middle + 2L]) / 0.12
  growth[2] <- (p50[3] - p50[1]) / 0.02
  growth[n - 1L] <- (p50[n] - p50[n - 2L]) / 0.02
  growth[1] <- (-3 * p50[1] + 4 * p50[2] - p50[3]) / 0.02
  growth[n] <- (3 * p50[n] - 4 * p50[n - 1L] + p50[n - 2L]) / 0.02

  data.frame(age = ages, p25 = p25, p50 = p50, p75 = p75, sd = sd, growth = growth)
})

trajectory_marker <- shiny::reactive({
  curve <- trajectory_data()
  kind <- shiny::req(input$trajectory_kind)
  age <- if (is.null(input$trajectory_age)) 14 else input$trajectory_age
  i <- which.min(abs(curve$age - age))
  list(age = curve$age[i], value = curve[[kind]][i])
})

trajectory_figure <- shiny::reactive({
  curve <- trajectory_data()
  kind <- shiny::req(input$trajectory_kind)
  english <- language() == "en"
  male <- identical(input$trajectory_sex, "Male")
  color <- if (male) "#2878A0" else "#AD5637"
  band <- if (male) "rgba(40,120,160,0.16)" else "rgba(173,86,55,0.16)"
  group <- if (english) input$trajectory_sex else if (male) "男性" else "女性"
  header <- paste0("<b>", group, " · %{x:.2f}", if (english) " years" else " 岁", "</b><br>")
  graph <- plotly::plot_ly(source = "trajectory")
  if (kind == "p50") {
    graph <- plotly::add_trace(graph, type = "scatter", mode = "lines",
      x = c(curve$age, rev(curve$age)), y = c(curve$p25, rev(curve$p75)),
      fill = "toself", fillcolor = band, line = list(width = 0),
      hoverinfo = "skip", name = "P25–P75")
    label <- if (english) "PUI severity (0–100)" else "PUI 严重程度（0–100）"
    details <- "%{text}"
  } else if (kind == "sd") {
    label <- if (english) "Individual variation (severity SD)" else "个体差异（严重程度标准差）"
    details <- if (english) "SD　%{y:.2f} severity points" else "标准差　%{y:.2f} 严重程度分"
  } else {
    label <- if (english) "P50 growth (severity points/year)" else "P50 增长率（严重程度分/年）"
    details <- if (english) "P50 growth　%{y:.2f} points/year" else "P50 增长率　%{y:.2f} 分/年"
  }
  graph <- plotly::add_trace(graph, type = "scatter", mode = "lines",
    x = curve$age, y = curve[[kind]], name = if (kind == "p50") "P50" else label,
    text = if (kind == "p50") sprintf("P25　%.2f<br><b>P50　%.2f</b><br>P75　%.2f",
      curve$p25, curve$p50, curve$p75),
    line = list(color = color, width = 2.5, simplify = FALSE),
    hovertemplate = paste0(header, details, "<extra></extra>"))

  # Moving the age marker uses relayout below, so the browser keeps its current zoom.
  point <- shiny::isolate(trajectory_marker())
  graph <- plotly::layout(graph, showlegend = FALSE, dragmode = "zoom",
    hovermode = "x", hoverdistance = -1,
    hoverlabel = list(bgcolor = "white", bordercolor = color, align = "left"),
    margin = list(l = 66, r = 18, b = 52, t = 40),
    xaxis = list(title = if (english) "Age (years)" else "年龄（岁）", range = c(9, 18),
      hoverformat = ".2f", zeroline = FALSE, gridcolor = "#E7ECF0", automargin = TRUE),
    yaxis = list(title = label, zeroline = kind == "growth", zerolinecolor = "#94A3B8",
      rangemode = if (kind == "growth") "tozero" else "normal", gridcolor = "#E7ECF0", automargin = TRUE),
    shapes = list(
      list(type = "line", x0 = point$age, x1 = point$age, yref = "paper", y0 = 0, y1 = 1,
        line = list(color = "#94A3B8", dash = "dot", width = 1)),
      list(type = "circle", xsizemode = "pixel", ysizemode = "pixel", xanchor = point$age,
        yanchor = point$value, x0 = -4, x1 = 4, y0 = -4, y1 = 4,
        fillcolor = color, line = list(color = "white", width = 1))))
  graph <- plotly::config(graph, scrollZoom = TRUE, doubleClick = "reset", displaylogo = FALSE,
    displayModeBar = TRUE, responsive = TRUE, locale = if (english) "en" else "zh-cn",
    modeBarButtons = list(c("zoom2d", "pan2d", "zoomIn2d", "zoomOut2d", "resetScale2d")))
  for (event in c("plotly_hover", "plotly_relayout")) graph <- plotly::event_unregister(graph, event)
  graph
})
output$trajectory_plot <- plotly::renderPlotly(trajectory_figure())

shiny::observeEvent(input$trajectory_age, {
  point <- trajectory_marker()
  plotly::plotlyProxyInvoke(plotly::plotlyProxy("trajectory_plot", session), "relayout",
    list("shapes[0].x0" = point$age, "shapes[0].x1" = point$age,
         "shapes[1].xanchor" = point$age, "shapes[1].yanchor" = point$value))
}, ignoreInit = TRUE)

trajectory_readout <- function(age) {
  shiny::req(input$trajectory_kind, age)
  curve <- trajectory_data()
  row <- curve[which.min(abs(curve$age - age)), , drop = FALSE]
  english <- language() == "en"
  if (english) {
    group <- if (identical(input$trajectory_sex, "Male")) "Male" else "Female"
    if (identical(input$trajectory_kind, "p50")) return(sprintf("%s, age %.2f years · P25 %.2f · P50 %.2f · P75 %.2f (severity points)", group, row$age, row$p25, row$p50, row$p75))
    if (identical(input$trajectory_kind, "sd")) return(sprintf("%s, age %.2f years: model-implied SD %.2f severity points.", group, row$age, row$sd))
    return(sprintf("%s, age %.2f years: P50 growth %.2f severity points/year.", group, row$age, row$growth))
  }
  group <- if (identical(input$trajectory_sex, "Male")) "男性" else "女性"
  if (identical(input$trajectory_kind, "p50")) {
    sprintf("%s，%.2f 岁 · P25 %.2f · P50 %.2f · P75 %.2f（严重程度分）", group, row$age, row$p25, row$p50, row$p75)
  } else if (identical(input$trajectory_kind, "sd")) {
    sprintf("%s，%.2f 岁：模型估计的标准差为 %.2f 严重程度分。", group, row$age, row$sd)
  } else {
    sprintf("%s，%.2f 岁：P50 增长率为 %.2f 严重程度分/年。", group, row$age, row$growth)
  }
}
output$trajectory_value <- shiny::renderText(trajectory_readout(input$trajectory_age))

output$trajectory_interpretation <- shiny::renderText({
  shiny::req(input$trajectory_kind)
  if (language() == "en") {
    if (identical(input$trajectory_kind, "growth")) return("A positive rate means the median rises with age. A negative rate means it falls. Where the median reaches a scale endpoint, the estimated rate depends on nearby ages.")
    if (identical(input$trajectory_kind, "sd")) return("Higher values indicate greater model-implied variation within the same age and sex group.")
    return("The shaded region is the P25–P75 population interval; the dotted line marks the selected age.")
  }
  if (identical(input$trajectory_kind, "growth")) {
    "正值表示中位数随年龄上升，负值表示随年龄下降。中位数触及量尺端点时，该处的变化率由邻近年龄的中位数估计。"
  } else if (identical(input$trajectory_kind, "sd")) {
    "数值越大，表示模型估计的同年龄、同性别组内个体差异越大。"
  } else {
    "阴影表示 P25–P75 人群分布区间；竖直虚线标记所选年龄。"
  }
})
