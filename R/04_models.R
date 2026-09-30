# 04_models.R — window selection, DiD estimation, robustness
# Input:  data/processed/panel.rds
# Output: data/processed/models.rds, es_df.rds, loo.rds

# setup:
library(tidyverse)
library(fixest)

T0     <- as.Date("2025-10-01")
N_POST <- 8

panel <- readRDS("data/processed/panel.rds") |>
  mutate(
    log_value    = log(value),
    treated      = as.integer(nace_r2 == "C26"),
    post         = as.integer(month >= T0),
    treated_post = treated * post,
    ym           = format(month, "%Y-%m"),
    cal_month    = lubridate::month(month),
    rel_month    = 12 * (lubridate::year(month) - 2025) +
      (lubridate::month(month) - 10)
  )

ppi  <- filter(panel, outcome == "ppi")
prod <- filter(panel, outcome == "prod")

stopifnot(
  inherits(panel$month, "Date"),
  all(is.finite(panel$log_value)),
  nrow(ppi) > 0, nrow(prod) > 0,
  setequal(unique(ppi$nace_r2), c("C26", "C27", "C28")),
  sum(ppi$treated_post) > 0,
  all(count(ppi, geo, nace_r2)$n == n_distinct(ppi$month))
)

# ---- Step 1: choose WIN_START from PRE-TREATMENT DATA ONLY ----

pretrend_test <- function(df, start) {
  d <- df |> filter(month >= as.Date(start), month < T0)
  m <- feols(log_value ~ treated:as.numeric(month) | geo^nace_r2 + geo^ym,
             data = d, cluster = ~geo)
  tibble(start          = start,
         slope_per_year = coef(m)[1] * 365,
         se_per_year    = se(m)[1] * 365,
         p              = pvalue(m)[1],
         n_months       = n_distinct(d$month))
}

CANDIDATES <- c("2019-01-01", "2021-01-01", "2022-07-01",
                "2023-01-01", "2023-07-01")

T_CRIT <- qt(0.975, df = n_distinct(ppi$geo) - 1)

pretrends <- map_dfr(CANDIDATES, ~ pretrend_test(ppi, .x)) |>
  mutate(
    start      = as.Date(start),
    lever      = (N_POST - 1) / 2 + (n_months + 1) / 2,
    bias_bound = 100 * lever * (abs(slope_per_year) + T_CRIT * se_per_year) / 12
  )
print(knitr::kable(pretrends, digits = 4))   # paste into memo.md

WIN_START <- pretrends |>
  filter(p > 0.05) |>
  slice_min(start, n = 1) |>
  pull(start)

stopifnot(length(WIN_START) == 1)
