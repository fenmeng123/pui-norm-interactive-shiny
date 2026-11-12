# PUI Norms

PUI Norms is a Shiny app in Chinese and English for interpreting scores on a 17-item measure of problematic usage of the internet (PUI) at ages 9–18. A fitted generalized additive model for location, scale and shape (GAMLSS) estimates where a person's total score falls in the reference distribution for their age and sex. A percentile of 75 means the model estimates that 75% of that reference group would score at or below the person's total.

## Explore the norms

* **Reference curves** show the median and the 25th–75th percentile band, the change in the median per year of age, and the within-group standard deviation. Hover to read values, drag or scroll to zoom, and double-click to reset. The curves use a 0–100 severity scale.

* **Individual score** accepts a total or responses to all 17 items. The result shows the person's percentile and their raw score against five reference curves. Download the report in Chinese or English.

* **Batch scoring** adds a percentile column to a single-sheet Excel workbook. Download the example template from the app. Enter age in years (9–18, decimals accepted), sex as `Male` or `Female`, and the integer total (17–85) in the columns `age`, `sex`, and `score`.

The norms come from the Chinese Y-IAT (Hou, 2013). The English interface uses the corresponding IAT-R items (Mak & Young, 2020), whose wording differs from the Chinese version. Both forms omit original items 4, 7, and 9 because of concerns on their content validity.

## Run locally

Open R in the repository root. The app was tested with R 4.5.2. To set up a fresh R library, install the runtime packages from CRAN. The [lockfile](app/renv.lock) records the versions used for testing.

```r
install.packages(c(
  "shiny", "bslib", "plotly", "ggplot2", "gamlss.dist",
  "openxlsx", "xml2", "systemfonts", "htmltools"
), repos = "https://cloud.r-project.org")
```

Start the app and open the local address printed in the R console. With this setup, your computer processes questionnaire responses and uploaded workbooks.

```r
shiny::runApp("app")
```

## Score a record in R

The Shiny app and the R function use the same fitted model. From the repository root, try this synthetic example.

```r
source("app/R/predict_pui.R", encoding = "UTF-8")
model <- load_pui_prediction_asset("app/models/pui_prediction_v1.rds")
result <- predict_pui(model, age = 14.5, sex = "Female", raw_score = 36)
round(result$percentile, 2)
# [1] 50.75
```

For a sample, pass one vector per input. The app's **About** page walks through importing a CSV file, scoring each row, and exporting the results.

## Checks and deployment

With the recorded package versions installed, run the following commands from the repository root. The synthetic checks also use the R packages `readxl` and `testthat`.

```sh
Rscript --vanilla scripts/preflight.R
Rscript --vanilla scripts/check_app.R
```

## License and materials

Copyright © 2026 Kunru Song. The application source code, scripts, and tests are licensed under the GNU General Public License, version 3 only (`GPL-3.0-only`). [Full license](LICENSE)

For redistribution of the fitted prediction asset, please contact me. The questionnaire authors retain copyright in their respective items, which appear here for research demonstration. [Model and questionnaire rights](app/RIGHTS_NOTICE.md#release-terms)

The bundled Noto font uses the SIL Open Font License 1.1. R packages retain their respective licenses. [Font license](app/fonts/OFL.txt) · [R package licenses](docs/DEPENDENCY_LICENSES.md)
