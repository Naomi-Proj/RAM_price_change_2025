# 03_audit.R - coverage audit and sample eligibility
# Input: data/processed/panel_all.rds
# Output: data/processed/panel.rds, coverage tables, figures/coverage_*.png

# setup:
library(tidyverse)

T0 <- as.Date("2025-10-01")     # treatment month
WIN_START <- as.Date("2019-01-01")    # window start
WIN_END <- as.Date("2026-05-01")    # chosen by the correlating segment
SECTORS <- c("C26", "C27", "C28")

EU27 <- c("AT","BE","BG","CY","CZ","DE","DK","EE","EL","ES","FI","FR","HR","HU",
          "IE","IT","LT","LU","LV","MT","NL","PL","PT","RO","SE","SI","SK")

# load population:
panel_all <- readRDS("data/processed/panel_all.rds") |>
  filter(geo %in% EU27, nace_r2 %in% SECTORS)

# WIN_END:
panel_all |>
  filter(!is.na(value), month >= as.Date("2026-01-01")) |>
  count(outcome, month, geo) |>
  filter(n < 3) |>
  print(n = 60)

panel_all |>
  dplyr::filter(outcome == "prod", month == as.Date("2026-07-01"), !is.na(value)) |>
  dplyr::count(geo) |>
  dplyr::filter(n < 3)

ppi |>
  dplyr::filter(outcome == "ppi", month == as.Date("2026-07-01"), !is.na(value)) |>
  dplyr::count(geo) |>
  dplyr::filter(n < 3)

  # conclusion: IE and FI are problematic reporters, and PT is a late reporter.

# The window, pre and post treatment periods:
months <- seq(WIN_START, WIN_END, by = "month")

full <- panel_all |>
  filter(month >= WIN_START, month <= WIN_END) |>
  complete(outcome, geo = EU27, nace_r2 = SECTORS, month = months)

N_PRE <- sum(months < T0)
N_POST <- sum(months >= T0)

# Coverage per country x sector:
cov_sector <- full |>
  group_by(outcome, geo, nace_r2) |>
  summarise(
    pre_obs = sum(!is.na(value) & month < T0),
    post_obs = sum(!is.na(value) & month >= T0),
    first = suppressWarnings(min(month[!is.na(value)])),
    last = suppressWarnings(max(month[!is.na(value)])),
    gaps = sum(is.na(value) & month > first & month < last),
    .groups = "drop"
  ) |>
  mutate(complete = pre_obs == N_PRE & post_obs == N_POST)

# Heatmap of coverage:
plot_cov <- function(out) {
  
  # ---- data prep (before any plotting) ----
  d <- full |>
    filter(outcome == out) |>
    mutate(observed = !is.na(value),
           m_idx = as.integer(lubridate::interval(WIN_START, month) %/% months(1)))
  
  ord <- d |> group_by(geo) |> summarise(tot = sum(observed)) |> arrange(tot)
  brk <- d |> filter(lubridate::month(month) == 1) |> distinct(m_idx, month)
  
  t0_idx <- as.integer(lubridate::interval(WIN_START, T0) %/% months(1))
  
  # the line positions, as data to map from
  vlines <- tibble::tibble(
    x    = c(t0_idx - 0.5, t0_idx - 36.5),
    what = c("Treatment (2025-10)", "Event-study window start")
  )
  
  # ---- the plot ----
  d |>
    mutate(geo = factor(geo, levels = ord$geo)) |>
    ggplot(aes(m_idx, geo, fill = observed)) +
    
    geom_tile(width = 1, height = 0.9) +
    
    geom_vline(aes(xintercept = x, linetype = what),
               data = vlines, inherit.aes = FALSE, linewidth = 0.45) +
    
    facet_wrap(~ nace_r2, nrow = 1) +
    
    scale_fill_manual(values = c(`TRUE` = "#2c7fb8", `FALSE` = "grey88"),
                      labels = c(`TRUE` = "Observed", `FALSE` = "Missing")) +
    scale_linetype_manual(values = c("Treatment (2025-10)"      = "solid",
                                     "Event-study window start" = "dotted")) +
    scale_x_continuous(breaks = brk$m_idx,
                       labels = lubridate::year(brk$month),
                       expand = c(0, 0)) +
    scale_y_discrete(expand = c(0, 0)) +
    
    labs(x = NULL, y = NULL, fill = NULL, linetype = NULL,
         title = paste0("Data coverage — ", out, ", EU27, ",
                        format(WIN_START, "%Y-%m"), " to ",
                        format(WIN_END, "%Y-%m"))) +
    
    theme_minimal(base_size = 10) +
    theme(legend.position = "bottom", panel.grid = element_blank())
}
ggsave("figures/coverage_ppi.png",  plot_cov("ppi"),  width = 10, height = 7, dpi = 200)
ggsave("figures/coverage_prod.png", plot_cov("prod"), width = 10, height = 7, dpi = 200)

# Rule: all 3 sectors must be complete withing the event-study window
cov_country <- cov_sector |>
  group_by(outcome, geo) |>
  summarise(
    eligible = all(complete),
    reason   = if_else(all(complete), "",
                       paste("incomplete:", paste(nace_r2[!complete], collapse = ", "))),
    .groups  = "drop"
  )

cov_country |> count(outcome, eligible)
cov_country |> filter(!eligible) |> print(n = 60)

# checking overlap between ppi valid and prod valid:
el <- cov_country |> filter(eligible)
common <- intersect(el$geo[el$outcome == "ppi"],
                    el$geo[el$outcome == "prod"])
length(common)
setdiff(el$geo[el$outcome == "ppi"], common)   # prices-only countries

# ---- Diagnostic: could the rule be relaxed? -------------------------
# Checked whether admitting C26 series with incomplete pre-periods
# would add countries. Four series qualify on post-period completeness
# (PT, NL, LV) but all have internal gaps rather than late starts.
# PT's gap (2025-02/03) falls inside the event-study window.
# Decision: strict rule retained. See memo.md.

relax_check <- cov_sector |>
  filter(nace_r2 == "C26", !complete, post_obs == N_POST) |>
  left_join(
    full |>
      filter(nace_r2 == "C26", is.na(value)) |>
      group_by(outcome, geo) |>
      summarise(first_missing = min(month),
                last_missing  = max(month), .groups = "drop"),
    by = c("outcome", "geo")
  ) |>
  select(outcome, geo, pre_obs, post_obs, first_missing, last_missing)

print(relax_check)

# ---- Diagnostic: does the 2-of-3 control rule change the sample? ----
# Equivalent to the strict rule on this vintage — all exclusions are
# driven by incomplete C26, never by missing controls.

cov_country |>
  mutate(loose = c26_ok & n_ctrl_ok >= 1) |>
  count(outcome, eligible, loose) |>
  print()

# saving the results
saveRDS(cov_sector,  "data/processed/coverage_sector.rds")
saveRDS(cov_country, "data/processed/coverage_country.rds")

eligible <- cov_country |> filter(eligible) |> select(outcome, geo)

panel <- full |> semi_join(eligible, by = c("outcome", "geo"))
saveRDS(panel, "data/processed/panel.rds")

cat("Eligible countries —",
    "ppi:",  sum(eligible$outcome == "ppi"),
    "| prod:", sum(eligible$outcome == "prod"), "\n")