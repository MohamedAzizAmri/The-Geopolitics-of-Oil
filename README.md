# The Geopolitics of Oil

### An Econometric Analysis of Oil Price Shocks, Geopolitical Tensions, and Macroeconomic Performance

[![Language](https://img.shields.io/badge/Language-R-blue)](https://www.r-project.org/)
[![Methods](https://img.shields.io/badge/Methods-Panel%20Data%20Econometrics-green)](https://cran.r-project.org/package=plm)
[![Focus](https://img.shields.io/badge/Focus-Energy%20Economics-orange)](https://www.iea.org/)

## Overview

Oil is more than a traded commodity: its price fluctuations can influence inflation, production costs, industrial activity, and broader macroeconomic conditions. Geopolitical tensions can amplify these effects by disrupting supply expectations, increasing uncertainty, and changing conditions in global energy markets.

**The Geopolitics of Oil** is an econometric research project investigating the relationship between oil-price shocks, geopolitical tensions, and macroeconomic performance across countries. Using panel-data methods and time-series techniques in R, the project examines the relationship between oil-market developments and two key economic indicators: the Consumer Price Index (CPI) and the Industrial Production Index (IPI).

The analysis combines data preparation, exploratory visualization, panel regression, statistical diagnostics, and robustness checks to investigate how these relationships vary across economic environments.

## Research Objectives

The project aims to:

- **Examine macroeconomic responses:** Investigate the relationship between changes in oil prices and consumer prices and industrial production.
- **Assess geopolitical effects:** Examine whether the period following the designated March 2026 geopolitical crisis is associated with changes in macroeconomic outcomes.
- **Compare econometric specifications:** Estimate pooled OLS, Fixed Effects, and Random Effects models to account for different assumptions about cross-country heterogeneity.
- **Account for relevant economic factors:** Include exchange-rate conditions, monetary policy rates, and financial-market volatility as explanatory variables.
- **Investigate heterogeneous responses:** Compare results between oil-importing and oil-exporting countries.
- **Evaluate robustness:** Apply alternative growth-rate specifications and statistical diagnostics to assess the reliability of the findings.

## Methodology

The analysis follows a structured econometric workflow.

### 1. Data Preparation and Feature Engineering

The Excel dataset is imported into R and organized by country and date. The preparation stage includes:

- Handling missing observations in selected explanatory variables.
- Constructing a post-crisis indicator for observations dated March 2026 onward.
- Creating lagged oil-price changes to examine delayed associations.
- Transforming selected variables using logarithms.
- Preparing macroeconomic indicators for panel estimation.

### 2. Time-Series Adjustment

The R script uses an ARIMA model with external regressors (ARIMAX) to adjust missing or forecast-designated observations for CPI and IPI.

The procedure incorporates oil-price changes, lagged oil-price changes, the nominal effective exchange rate, policy rates, and the VIX. It also applies bounds to selected predicted changes to limit extreme adjustments.

These adjusted observations are used to construct the panel dataset for the subsequent econometric analysis. They should be distinguished from directly observed values when interpreting the results.

### 3. Exploratory Data Analysis

The project generates time-series visualizations to examine:

- Brent crude oil prices around the designated geopolitical event.
- Consumer price index trends across country groups.
- Industrial production index trends across country groups.

These visualizations provide context for the regression analysis and help illustrate differences in macroeconomic developments over time.

### 4. Panel Data Econometrics

Three panel regression specifications are estimated for both CPI and IPI.

| Model | Purpose |
|---|---|
| Pooled Ordinary Least Squares (Pooled OLS) | Estimates a common relationship across the pooled observations. |
| Fixed Effects (FE) | Controls for time-invariant country-specific characteristics. |
| Random Effects (RE) | Models country-specific effects under the assumption that they are uncorrelated with the explanatory variables. |

The baseline specifications include oil-price changes, the logarithm of the nominal effective exchange rate, policy rates, the VIX, and the post-crisis indicator.

The script also calculates group-clustered robust standard errors to help address heteroskedasticity and within-country dependence.

### 5. Model Diagnostics and Robustness

The analysis incorporates several diagnostic procedures:

- **Hausman test:** Compares the Fixed Effects and Random Effects specifications.
- **Breusch–Pagan panel test:** Evaluates the presence of individual-level effects.
- **Serial-correlation test:** Examines potential serial correlation in panel residuals.
- **Breusch–Pagan heteroskedasticity test:** Tests for non-constant error variance.
- **Growth-rate robustness checks:** Re-estimates Fixed Effects models using changes in the logarithms of CPI and IPI.
- **Importers-versus-exporters analysis:** Estimates separate models to explore differences associated with countries' oil-trade positions.

## Repository Structure

```text
The-Geopolitics-of-Oil/
│
├── Rcode.R
│   └── Data preparation, forecasting adjustments,
│       exploratory plots, panel regressions,
│       diagnostic tests, and robustness checks.
│
├── panel_data_oil_crisis_final_v2 (1).xlsx
│   └── Input panel dataset.
│
├── Final Report.pdf
│   └── Final research report and discussion.
│
└── README.md
    └── Project documentation.
```

## Tools and Technologies

- **R:** Statistical computing and econometric analysis.
- **tidyverse:** Data manipulation and preparation.
- **readxl / writexl:** Excel data import and export.
- **forecast:** ARIMA modelling and time-series functionality.
- **zoo:** Missing-value handling and time-series operations.
- **plm:** Panel-data estimation.
- **lmtest:** Econometric hypothesis testing and diagnostics.
- **sandwich:** Robust covariance estimators.
- **ggplot2:** Data visualization.
- **stargazer:** Regression table generation.

## Getting Started

### Prerequisites

Install [R](https://cran.r-project.org/) and optionally [RStudio](https://posit.co/download/rstudio-desktop/).

### 1. Clone the repository

```bash
git clone https://github.com/MohamedAzizAmri/The-Geopolitics-of-Oil.git
cd The-Geopolitics-of-Oil
```

### 2. Check the input file

Ensure that the Excel dataset is located in the same working directory as `Rcode.R`. The script expects the following filename:

```text
panel_data_oil_crisis_final_v2 (1).xlsx
```

### 3. Run the analysis

Open `Rcode.R` in RStudio and run the script from top to bottom, with the repository directory set as the working directory.

The script checks for and installs its required R packages. An internet connection may be needed for initial package installation.

### 4. Inspect the generated outputs

The script creates an output directory named `oil_crisis_outputs_final_R`, including a `figures` subdirectory.

Generated outputs include:

- `final_estimation_panel.csv` — prepared panel dataset.
- `final_estimation_panel.xlsx` — Excel version of the prepared panel.
- `main_regression_results.txt` — main regression estimates and diagnostic results.
- `stargazer_main_results.txt` — formatted main-model results, with a fallback export if necessary.
- `stargazer_heterogeneity.txt` — importer-versus-exporter model results.
- `growth_rate_robustness.txt` — growth-rate robustness estimates.
- `figures/` — exploratory time-series plots.

## Research Findings

The empirical findings, coefficient estimates, statistical significance, and interpretation of the regression results are documented in the [Final Research Report](./Final%20Report.pdf).

The results should be interpreted in light of the model specifications, the treatment of missing and forecast-designated observations, and the assumptions required for valid econometric inference. Estimated associations alone do not establish that oil-price shocks or geopolitical events caused the observed macroeconomic changes.

## Limitations and Interpretation

Several considerations are important when interpreting this analysis:

- The post-crisis indicator captures a designated time period; by itself, it does not isolate the causal effect of a geopolitical event.
- Forecast-adjusted CPI and IPI observations are estimates rather than direct measurements and may influence the regression results.
- Country-level heterogeneity, omitted variables, and differences in economic structure can affect estimated relationships.
- Robust standard errors and diagnostic tests improve statistical assessment but do not eliminate all potential sources of bias.
- The reliability of conclusions depends on the underlying data, variable definitions, sample coverage, and model assumptions.

## Author

**Mohamed Aziz Amri**

Business Analytics and IT Student | Tunis Business School

GitHub: [@MohamedAzizAmri](https://github.com/MohamedAzizAmri)


