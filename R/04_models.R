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
print(knitr::kable(pretrends, digits = 4))  

WIN_START <- pretrends |>
  filter(p > 0.05) |>
  slice_min(start, n = 1) |>
  pull(start)

stopifnot(length(WIN_START) == 1)

# ---- Step 2: main DiD ----

# the DiD fitting function:
fit_window <- function(df, start) {
  feols(log_value ~ treated_post | geo^nace_r2 + geo^ym,
        data = filter(df, month >= as.Date(start)),
        cluster = ~geo)
}

m_ppi  <- fit_window(ppi,  WIN_START)
m_prod <- fit_window(prod, WIN_START)

b  <- coef(m_ppi)[["treated_post"]] # estimate
ci <- confint(m_ppi)["treated_post", ] # CI
stopifnot(is.finite(b), all(is.finite(unlist(ci))))

# report b and ci as percentage :
print(summary(m_ppi))
print(100 * (exp(b) - 1))
print(100 * (exp(unlist(ci)) - 1))

# ---- Step 3: event study ----

# the event-study function:
fit_es <- function(df, start) {
  feols(log_value ~ i(rel_month, treated, ref = -1) | geo^nace_r2 + geo^ym,
        data = filter(df, month >= as.Date(start)),
        cluster = ~geo)
}

es_ppi  <- fit_es(ppi,  WIN_START)
es_prod <- fit_es(prod, WIN_START)

# converting the model to plotable data:
tidy_es <- function(m, label) {
  broom::tidy(m, conf.int = TRUE) |>
    filter(str_detect(term, "rel_month")) |>
    mutate(rel = as.numeric(str_extract(term, "-?[0-9]+")),
           outcome = label) |>
    bind_rows(tibble(rel = -1, estimate = 0, conf.low = 0, conf.high = 0,
                     outcome = label))
}

es_df <- bind_rows(tidy_es(es_ppi, "ppi"), tidy_es(es_prod, "prod"))

n_win <- n_distinct(filter(ppi, month >= WIN_START)$month)   # 47 = 39 pre + 8 post
stopifnot(
  nrow(es_df) == 2 * n_win,                       # one row per relative month per outcome
  !anyDuplicated(es_df[c("outcome", "rel")]),
  all(es_df$rel %in% unique(filter(ppi, month >= WIN_START)$rel_month))
)
saveRDS(es_df, "data/processed/es_df.rds")

# ---- robustness and inference ----
# Each check changes one choice and re-estimates. Comments say which
# objection the check answers and what result would be a problem.

# 1. Placebo in time
# Objection: "a real effect was cancelled by a one-off step in the gap unrelated to treatment."
# Fake T0 two years early.
# WANT: estimate near 0. 
# Uses WIN_START, not 2019/2021: earlier windows contain the energy-shock
# fall in the gap and would produce a spurious placebo effect.

T0_FAKE <- as.Date("2023-10-01")

placebo <- function(df, start) {
  d <- df |>
    filter(month >= as.Date(start), month < as.Date("2025-07-01")) |>
    mutate(treated_post = treated * as.integer(month >= T0_FAKE))
  feols(log_value ~ treated_post | geo^nace_r2 + geo^ym, data = d, cluster = ~geo)
}

pl_ppi <- placebo(ppi, WIN_START)

# 2. Leave-one-out
# Objection: "Is this driven by one country?"

loo <- map_dfr(unique(ppi$geo), function(g) {
  m <- fit_window(filter(ppi, geo != g), WIN_START)
  tibble(dropped = g,
         est = coef(m)[["treated_post"]],
         lo  = confint(m)["treated_post", 1],
         hi  = confint(m)["treated_post", 2])
})
stopifnot(nrow(loo) == n_distinct(ppi$geo), all(is.finite(loo$est)))
saveRDS(loo, "data/processed/loo.rds")

# 3. Alternative control sectors
# Objection: "You picked the control group that gave your answer."
# WANT: both estimates near 0.

r_c27 <- fit_window(filter(ppi, nace_r2 %in% c("C26", "C27")), WIN_START)
r_c28 <- fit_window(filter(ppi, nace_r2 %in% c("C26", "C28")), WIN_START)

# 4. Alternative treatment dates
# Objection: "T0 was chosen by eye."

alt_T0 <- function(df, t0, start) {
  d <- df |>
    filter(month >= as.Date(start)) |>
    mutate(treated_post = treated * as.integer(month >= t0))
  feols(log_value ~ treated_post | geo^nace_r2 + geo^ym, data = d, cluster = ~geo)
}

r_sep <- alt_T0(ppi, as.Date("2025-09-01"), WIN_START)
r_jan <- alt_T0(ppi, as.Date("2026-01-01"), WIN_START)

# 5. Alternative windows
# NOT a robustness check in the usual sense: these windows failed the
# pre-trend test. Expected to differ (2019 ~ -3%). Shows why the window matters.

r_2019 <- fit_window(ppi, "2019-01-01")
r_2021 <- fit_window(ppi, "2021-01-01")

# 6. Sector-specific seasonality
# Objection: "NSA prices; post-period (Oct-May) has no Jun-Sep."
# Each country-sector gets its own calendar-month effects.

r_seas <- feols(log_value ~ treated_post | geo^nace_r2^cal_month + geo^ym,
                data = filter(ppi, month >= WIN_START), cluster = ~geo)

# 7. Inference with few clusters
# Objection: "19 clusters is too few for cluster-robust SEs."

m_twoway <- feols(log_value ~ treated_post | geo^nace_r2 + geo^ym,
                  data = filter(ppi, month >= WIN_START),
                  cluster = ~ geo + ym)

# Wild cluster bootstrap
# boottest supports only ONE absorbed fixed effect. This is the same model
# as m_ppi, rewritten: country-month absorbed, country-sector as explicit dummies.

ppi_w <- filter(ppi, month >= WIN_START) |>
  mutate(fe_cs = factor(paste(geo, nace_r2)),   # country-sector ID
         fe_cm = factor(paste(geo, ym)))        # country-month ID

stopifnot(nlevels(ppi_w$fe_cs) == 57,
          nlevels(ppi_w$fe_cm) == 893)

m_boot <- feols(log_value ~ treated_post + fe_cs | fe_cm,
                data = ppi_w, cluster = ~geo)

stopifnot(isTRUE(all.equal(coef(m_boot)[["treated_post"]], b)))   # same model

set.seed(2026)
bt <- fwildclusterboot::boottest(m_boot, param = "treated_post",
                                 clustid = "geo", B = 9999, fe = "fe_cm")
print(summary(bt))

# results:

models <- list(
  main    = list(ppi = m_ppi, prod = m_prod),
  es      = list(ppi = es_ppi, prod = es_prod),
  placebo = pl_ppi,
  alt     = list(c27 = r_c27, c28 = r_c28, sep = r_sep, jan = r_jan,
                 y2019 = r_2019, y2021 = r_2021, seas = r_seas,
                 twoway = m_twoway),
  boot    = bt
)

alt_est <- sapply(models$alt, \(m) coef(m)[["treated_post"]])
stopifnot(all(is.finite(alt_est)),
          is.finite(coef(pl_ppi)[["treated_post"]]))
saveRDS(models, "data/processed/models.rds")

print(etable(m_ppi, r_c27, r_c28, r_sep, r_jan, r_2019, r_seas,
             headers = c("Main", "C27 only", "C28 only", "T0=Sep", "T0=Jan",
                         "From 2019", "Seasonal FE")))

# ---- Summary table of all checks, in % ----

report <- function(m, label, type) {
  b  <- coef(m)[["treated_post"]]
  ci <- confint(m)["treated_post", ]
  tibble(check   = label,
         type    = type,
         est_pct = 100 * (exp(b) - 1),
         lo_pct  = 100 * (exp(ci[[1]]) - 1),
         hi_pct  = 100 * (exp(ci[[2]]) - 1),
         p       = pvalue(m)[["treated_post"]],
         n_obs   = nobs(m))
}

checks <- bind_rows(
  report(m_ppi,    "Main",                               "main"),
  report(pl_ppi,   "Placebo (fake T0 2023-10)",          "placebo"),
  report(r_c27,    "Control: C27 only",                  "robustness"),
  report(r_c28,    "Control: C28 only",                  "robustness"),
  report(r_sep,    "T0 = Sep 2025",                      "robustness"),
  report(r_jan,    "T0 = Jan 2026",                      "robustness"),
  report(r_seas,   "Seasonal FE",                        "robustness"),
  report(m_twoway, "Clustered by country + month",       "inference"),
  tibble(check   = "Wild cluster bootstrap",
         type    = "inference",
         est_pct = 100 * (exp(b) - 1),
         lo_pct  = 100 * (exp(bt$conf_int[1]) - 1),
         hi_pct  = 100 * (exp(bt$conf_int[2]) - 1),
         p       = bt$p_val,
         n_obs   = nobs(m_ppi)),
  report(r_2019,   "Window from 2019 (fails pre-trend)", "fails pre-trend"),
  report(r_2021,   "Window from 2021 (fails pre-trend)", "fails pre-trend")
) |>
  mutate(half_width = (hi_pct - lo_pct) / 2)

stopifnot(all(is.finite(checks$est_pct)), !anyDuplicated(checks$check))
saveRDS(checks, "data/processed/checks.rds")
print(knitr::kable(checks, digits = 2))   # paste into memo.md

saveRDS(pretrends, "data/processed/pretrends.rds")