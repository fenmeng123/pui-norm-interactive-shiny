# Load once per R process. The RDS stores only data, not a serialized function.
# Rebuilding the spline at runtime avoids serializing version-specific closures.
load_pui_prediction_asset <- function(path) {
  asset <- readRDS(path)
  if (!identical(asset$format_version, "pui_prediction_v1")) {
    stop("Unsupported PUI prediction asset version.")
  }
  grid_age <- seq(asset$age_min, asset$age_max, length.out = asset$smooth_grid_n)
  asset$smooth <- stats::splinefun(grid_age, asset$smooth_values, method = "natural")
  asset$smooth_values <- NULL
  asset
}

# Shared calculation for single records, batches and model-based plots.
# Inputs may have a common length or length one; the historical period is fixed.
predict_pui <- function(asset, age, sex, raw_score) {
  input_lengths <- c(length(age), length(sex), length(raw_score))
  n <- max(input_lengths)
  if (n < 1L || any(!input_lengths %in% c(1L, n))) {
    stop("Each input must have length one or the common maximum length.")
  }
  if (!is.numeric(age) || !is.numeric(raw_score)) stop("Age and score must be numeric.")
  age <- rep(age, length.out = n)
  sex <- rep(as.character(sex), length.out = n)
  raw_score <- rep(raw_score, length.out = n)
  if (anyNA(age) || any(!is.finite(age)) || any(age < asset$age_min | age > asset$age_max)) {
    stop("Age must be between 9 and 18 years inclusive.")
  }
  if (anyNA(sex) || any(!sex %in% asset$sex_levels)) stop("Sex must be Male or Female.")
  if (anyNA(raw_score) || any(!is.finite(raw_score)) ||
      any(raw_score < asset$score_min | raw_score > asset$score_max) ||
      any(raw_score != round(raw_score))) {
    stop("The 17-item total score must be an integer from 17 to 85.")
  }

  age_basis <- stats::poly(age, degree = 6L, coefs = asset$age_basis_coefs)
  newdata <- data.frame(Sex_for_GAMLSS = factor(sex, levels = asset$sex_levels))
  for (j in seq_len(6L)) newdata[[paste0("Age_OP", j)]] <- as.numeric(age_basis[, j])
  design <- stats::model.matrix(
    ~ Age_OP1 + Age_OP2 + Age_OP3 + Age_OP4 + Age_OP5 + Age_OP6 + Sex_for_GAMLSS,
    data = newdata,
    contrasts.arg = list(Sex_for_GAMLSS = stats::contr.treatment(asset$sex_levels, base = 1L))
  )
  mu <- stats::plogis(as.numeric(design[, names(asset$mu_coefficients), drop = FALSE] %*% asset$mu_coefficients))
  sigma <- stats::plogis(as.numeric(design[, names(asset$sigma_coefficients), drop = FALSE] %*% asset$sigma_coefficients))
  nu <- exp(asset$nu_coefficients[1] + asset$nu_coefficients[2] * age + asset$smooth(age))
  tau <- rep(exp(asset$tau_coefficients[1]), n)
  y <- (raw_score - asset$score_min) / (asset$score_max - asset$score_min)
  percentile <- 100 * gamlss.dist::pBEINF(y, mu = mu, sigma = sigma, nu = nu, tau = tau)

  data.frame(
    age = age, sex = sex, raw_score = as.integer(round(raw_score)),
    mu = mu, sigma = sigma, nu = nu, tau = tau, percentile = percentile
  )
}
