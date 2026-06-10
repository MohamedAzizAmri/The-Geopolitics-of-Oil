required_packages <- c(
  "tidyverse", "readxl", "writexl", "forecast", "zoo", "plm", "lmtest",
  "sandwich", "stargazer", "broom", "car", "ggplot2"
)
new_packages <- required_packages[!(required_packages %in% installed.packages()[, "Package"])]
if (length(new_packages) > 0) install.packages(new_packages, dependencies = TRUE)
invisible(lapply(required_packages, library, character.only = TRUE))

input_file <- "panel_data_oil_crisis_final_v2 (1).xlsx"
out_dir <- "oil_crisis_outputs_final_R"
fig_dir <- file.path(out_dir, "figures")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

# 1. Load data ----------------------------------------------------------------
data_raw <- readxl::read_excel(input_file) %>%
  mutate(date = as.Date(date),
         post_crisis = ifelse(date >= as.Date("2026-03-01"), 1, 0)) %>%
  arrange(country, date)

# 2. Prepare external regressors ---------------------------------------------
data_x <- data_raw %>%
  group_by(country) %>%
  arrange(date, .by_group = TRUE) %>%
  mutate(
    policy_rate_original = policy_rate,
    policy_rate = zoo::na.approx(policy_rate, na.rm = FALSE),
    policy_rate = zoo::na.locf(policy_rate, na.rm = FALSE),
    policy_rate = zoo::na.locf(policy_rate, na.rm = FALSE, fromLast = TRUE),
    ln_neer = log(neer),
    oil_l1 = lag(oil_pct_change, 1, default = 0),
    oil_l2 = lag(oil_pct_change, 2, default = 0)
  ) %>%
  ungroup()

xreg_cols <- c("oil_pct_change", "oil_l1", "oil_l2", "ln_neer", "policy_rate", "vix")
for (v in xreg_cols) data_x[[v]][is.na(data_x[[v]])] <- mean(data_x[[v]], na.rm = TRUE)
xreg_center <- sapply(data_x[xreg_cols], mean, na.rm = TRUE)
xreg_scale <- sapply(data_x[xreg_cols], sd, na.rm = TRUE)
xreg_scale[xreg_scale == 0] <- 1

# 3. Forecast adjustment function ----------------------------------------------
cap_bounds <- function(x, outcome, country) {
  d <- diff(log(x[!is.na(x)]))
  d <- d[is.finite(d)]
  if (length(d) >= 5) {
    qs <- quantile(d, c(0.01, 0.99), na.rm = TRUE)
    iqr <- IQR(d, na.rm = TRUE)
    lo <- as.numeric(qs[1] - 0.5 * iqr)
    hi <- as.numeric(qs[2] + 0.5 * iqr)
  } else {
    lo <- ifelse(outcome == "cpi", -0.03, -0.12)
    hi <- ifelse(outcome == "cpi",  0.03,  0.12)
  }
  if (outcome == "cpi") {
    lo <- min(lo, -0.01); hi <- max(hi, 0.01)
    if (country == "TUR") hi <- max(hi, 0.08)
  } else {
    lo <- min(lo, -0.08); hi <- max(hi, 0.08)
  }
  c(lo, hi)
}

correct_one_outcome <- function(df, outcome) {
  df[[paste0(outcome, "_original")]] <- df[[outcome]]
  df[[paste0(outcome, "_was_missing")]] <- is.na(df[[outcome]])
  df[[paste0(outcome, "_arimax_raw")]] <- df[[outcome]]
  df[[paste0(outcome, "_arimax")]] <- df[[outcome]]
  df[[paste0(outcome, "_source")]] <- "actual"

  for (cc in unique(df$country)) {
    ix <- which(df$country == cc)
    sub <- df[ix, ]
    y <- log(sub[[outcome]])
    y[sub$is_forecast == TRUE] <- NA  # do not train on original forecast rows
    X <- as.matrix(scale(sub[xreg_cols], center = xreg_center, scale = xreg_scale))

    fit_ok <- TRUE
    fit <- tryCatch(
      forecast::Arima(y, order = c(1,1,0), xreg = X, include.drift = TRUE),
      error = function(e) { fit_ok <<- FALSE; return(NULL) }
    )
    if (fit_ok) {
      pred <- fitted(fit)
      # Fill early fitted NA values conservatively with observed/fitted interpolation.
      pred_full <- as.numeric(pred)
      pred_full[is.na(pred_full)] <- zoo::na.approx(pred_full, na.rm = FALSE)[is.na(pred_full)]
      pred_full <- zoo::na.locf(pred_full, na.rm = FALSE)
      pred_full <- zoo::na.locf(pred_full, na.rm = FALSE, fromLast = TRUE)
      raw <- exp(pred_full)
    } else {
      raw <- exp(zoo::na.approx(log(sub[[outcome]]), na.rm = FALSE))
      raw <- zoo::na.locf(raw, na.rm = FALSE)
      raw <- zoo::na.locf(raw, na.rm = FALSE, fromLast = TRUE)
    }
    replace <- is.na(sub[[outcome]]) | sub$is_forecast == TRUE
    df[ix[replace], paste0(outcome, "_arimax_raw")] <- raw[replace]

    bounds <- cap_bounds(sub[[outcome]], outcome, cc)
    prev_log <- NA_real_
    for (j in seq_along(ix)) {
      row_ix <- ix[j]
      raw_val <- df[[paste0(outcome, "_arimax_raw")]][row_ix]
      original_val <- df[[outcome]][row_ix]
      replace_j <- is.na(original_val) | isTRUE(df$is_forecast[row_ix])
      if (!replace_j) {
        val <- original_val; src <- "actual"
      } else {
        raw_log <- log(raw_val)
        if (!is.na(prev_log)) {
          d <- raw_log - prev_log
          dcap <- max(min(d, bounds[2]), bounds[1])
          val <- exp(prev_log + dcap)
          src <- ifelse(abs(d - dcap) > 1e-12, "arimax_capped", "arimax")
        } else {
          val <- raw_val; src <- "arimax"
        }
      }
      df[[paste0(outcome, "_arimax")]][row_ix] <- val
      df[[paste0(outcome, "_source")]][row_ix] <- src
      prev_log <- log(val)
    }
  }
  df
}

data_corr <- data_x %>% correct_one_outcome("cpi") %>% correct_one_outcome("ipi") %>%
  group_by(country) %>% arrange(date, .by_group = TRUE) %>%
  mutate(
    ln_cpi = log(cpi_arimax),
    ln_ipi = log(ipi_arimax),
    dln_cpi = 100 * (ln_cpi - lag(ln_cpi)),
    dln_ipi = 100 * (ln_ipi - lag(ln_ipi)),
    dev_group = ifelse(str_detect(group, "Advanced"), "Advanced", "Emerging")
  ) %>% ungroup()

write.csv(data_corr, file.path(out_dir, "final_estimation_panel.csv"), row.names = FALSE)
writexl::write_xlsx(list(Corrected_Panel = data_corr), file.path(out_dir, "final_estimation_panel.xlsx"))

# 4. Exploratory figures ------------------------------------------------------
oil_ts <- data_corr %>% distinct(date, brent, oil_pct_change, vix)

ggplot(oil_ts, aes(date, brent)) +
  geom_line(linewidth = 1, color = "darkred") +
  geom_vline(xintercept = as.Date("2026-03-01"), linetype = "dashed") +
  annotate("rect", xmin = as.Date("2026-03-01"), xmax = max(oil_ts$date), ymin = -Inf, ymax = Inf, alpha = .12, fill = "red") +
  labs(title = "Brent crude oil around the 2026 Gulf crisis", x = "Month", y = "USD per barrel") +
  theme_minimal()
ggsave(file.path(fig_dir, "fig1_brent.png"), width = 8, height = 4.5, dpi = 300)

ggplot(data_corr, aes(date, ln_cpi, color = group)) +
  stat_summary(fun = mean, geom = "line", linewidth = 1) +
  geom_vline(xintercept = as.Date("2026-03-01"), linetype = "dashed") +
  labs(title = "forecast-adjusted log(CPI) by country group", x = "Month", y = "log(CPI)") +
  theme_minimal()
ggsave(file.path(fig_dir, "fig2_log_cpi_by_group.png"), width = 8, height = 4.5, dpi = 300)

ggplot(data_corr, aes(date, ln_ipi, color = group)) +
  stat_summary(fun = mean, geom = "line", linewidth = 1) +
  geom_vline(xintercept = as.Date("2026-03-01"), linetype = "dashed") +
  labs(title = "forecast-adjusted log(IPI) by country group", x = "Month", y = "log(IPI)") +
  theme_minimal()
ggsave(file.path(fig_dir, "fig3_log_ipi_by_group.png"), width = 8, height = 4.5, dpi = 300)

# 5. Panel estimation ---------------------------------------------------------
pdata <- pdata.frame(data_corr, index = c("country", "date"))
base_cpi <- ln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis
base_ipi <- ln_ipi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis

run_models <- function(formula, pdata_obj) {
  pols <- plm(formula, data = pdata_obj, model = "pooling")
  fe <- plm(formula, data = pdata_obj, model = "within")
  re <- plm(formula, data = pdata_obj, model = "random")
  list(
    pols = pols,
    fe = fe,
    re = re,
    pols_robust = coeftest(pols, vcov = vcovHC(pols, method = "arellano", type = "HC3", cluster = "group")),
    fe_robust = coeftest(fe, vcov = vcovHC(fe, method = "arellano", type = "HC3", cluster = "group")),
    re_robust = coeftest(re, vcov = vcovHC(re, method = "arellano", type = "HC3", cluster = "group")),
    hausman = phtest(fe, re),
    bp_panel = plmtest(pols, effect = "individual", type = "bp"),
    serial = pbgtest(fe),
    hetero = bptest(formula, data = pdata_obj)
  )
}

models_cpi <- run_models(base_cpi, pdata)
models_ipi <- run_models(base_ipi, pdata)

sink(file.path(out_dir, "main_regression_results.txt"))
cat("Pooled OLS, Fixed Effects, and Random Effects - final panel\n")
print(models_cpi$pols_robust); print(models_cpi$fe_robust); print(models_cpi$re_robust)
print(models_ipi$pols_robust); print(models_ipi$fe_robust); print(models_ipi$re_robust)
cat("\nDiagnostics\n")
print(models_cpi$hausman); print(models_cpi$bp_panel); print(models_cpi$serial); print(models_cpi$hetero)
print(models_ipi$hausman); print(models_ipi$bp_panel); print(models_ipi$serial); print(models_ipi$hetero)
sink()

# Heterogeneity: importers vs exporters.
run_fe_split <- function(outcome_formula, split_var, split_value) {
  dat <- pdata[data_corr[[split_var]] == split_value, ]
  plm(outcome_formula, data = dat, model = "within")
}
fe_cpi_importers <- run_fe_split(base_cpi, "oil_balance", "importer")
fe_cpi_exporters <- run_fe_split(base_cpi, "oil_balance", "exporter")
fe_ipi_importers <- run_fe_split(base_ipi, "oil_balance", "importer")
fe_ipi_exporters <- run_fe_split(base_ipi, "oil_balance", "exporter")

# Heterogeneity: Importers vs Exporters
safe_stargazer <- function(..., out_file, fallback_models, fallback_title) {
  ok <- tryCatch({
    stargazer(..., out = out_file)
    TRUE
  }, error = function(e) {
    cat("Stargazer export failed; writing fallback table instead. Reason: ",
        conditionMessage(e), "\n")
    FALSE
  })
  if (!ok) {
    sink(out_file)
    cat(fallback_title, "\n")
    cat("Generated with fallback exporter because stargazer could not parse the plm objects.\n\n")
    for (nm in names(fallback_models)) {
      cat("==============================\n")
      cat(nm, "\n")
      cat("==============================\n")
      print(summary(fallback_models[[nm]]))
      cat("\nRobust coefficient test:\n")
      print(coeftest(fallback_models[[nm]], vcov = vcovHC(fallback_models[[nm]], method = "arellano", type = "HC3", cluster = "group")))
      cat("\n")
    }
    sink()
  }
  invisible(ok)
}

main_models_for_export <- list(
  "CPI POLS" = models_cpi$pols,
  "CPI FE" = models_cpi$fe,
  "CPI RE" = models_cpi$re,
  "IPI POLS" = models_ipi$pols,
  "IPI FE" = models_ipi$fe,
  "IPI RE" = models_ipi$re
)

safe_stargazer(
  models_cpi$pols, models_cpi$fe, models_cpi$re, models_ipi$pols, models_ipi$fe, models_ipi$re,
  type = "text",
  title = "Main Panel Results: Forecast-adjusted Dataset",
  column.labels = c("CPI POLS", "CPI FE", "CPI RE", "IPI POLS", "IPI FE", "IPI RE"),
  keep.stat = c("n", "rsq"),
  out_file = file.path(out_dir, "stargazer_main_results.txt"),
  fallback_models = main_models_for_export,
  fallback_title = "Main Panel Results: Forecast-adjusted Dataset"
)

heterogeneity_models_for_export <- list(
  "CPI Importers FE" = fe_cpi_importers,
  "CPI Exporters FE" = fe_cpi_exporters,
  "IPI Importers FE" = fe_ipi_importers,
  "IPI Exporters FE" = fe_ipi_exporters
)

safe_stargazer(
  fe_cpi_importers, fe_cpi_exporters, fe_ipi_importers, fe_ipi_exporters,
  type = "text",
  title = "Fixed Effects Heterogeneity: Importers vs Exporters",
  column.labels = c("CPI Importers", "CPI Exporters", "IPI Importers", "IPI Exporters"),
  keep.stat = c("n", "rsq"),
  out_file = file.path(out_dir, "stargazer_heterogeneity.txt"),
  fallback_models = heterogeneity_models_for_export,
  fallback_title = "Fixed Effects Heterogeneity: Importers vs Exporters"
)

# Growth-rate robustness.
pdata_growth <- pdata.frame(data_corr %>% filter(!is.na(dln_cpi), !is.na(dln_ipi)), index = c("country", "date"))
fe_dln_cpi <- plm(dln_cpi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis, data = pdata_growth, model = "within")
fe_dln_ipi <- plm(dln_ipi ~ oil_pct_change + ln_neer + policy_rate + vix + post_crisis, data = pdata_growth, model = "within")
sink(file.path(out_dir, "growth_rate_robustness.txt"))
print(coeftest(fe_dln_cpi, vcov = vcovHC(fe_dln_cpi, method = "arellano", type = "HC3", cluster = "group")))
print(coeftest(fe_dln_ipi, vcov = vcovHC(fe_dln_ipi, method = "arellano", type = "HC3", cluster = "group")))
sink()

cat("Done. Outputs written to", out_dir, "\n")
