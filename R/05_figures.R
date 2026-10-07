# 05_figures.R — Part A: descriptive figures

# setup:
library(tidyverse)
library(fixest)

T0 <- as.Date("2025-10-01")

panel <- readRDS("data/processed/panel.rds") |>
  mutate(log_value = log(value),
         grp = if_else(nace_r2 == "C26", "C26 (treated)", "C27/C28 (control)"))

# --- Figure 1: mean index level by group ---
trends <- panel |>
  group_by(outcome, month, grp) |>
  summarise(mean_index = mean(value), .groups = "drop")

p_trends <- ggplot(trends, aes(month, mean_index, colour = grp)) +
  geom_line(linewidth = 0.7) +
  geom_vline(xintercept = T0, linetype = "dashed") +
  facet_wrap(~ outcome, scales = "free_y") +
  labs(x = NULL, y = "Index (2021 = 100)", colour = NULL,
       title = "Producer prices and production, treated vs control sectors") +
  theme_minimal(base_size = 11) + theme(legend.position = "bottom")

ggsave("figures/trends.png", p_trends, width = 10, height = 5, dpi = 200)

# --- Figure 2: the DiD gap, computed within country-month ---
gap <- panel |>
  group_by(outcome, geo, month, grp) |>
  summarise(lv = mean(log_value), .groups = "drop") |>
  pivot_wider(names_from = grp, values_from = lv) |>
  mutate(gap = `C26 (treated)` - `C27/C28 (control)`) |>
  group_by(outcome, month) |>
  summarise(mean_gap = mean(gap),
            se_gap   = sd(gap) / sqrt(n()), .groups = "drop")

p_gap <- ggplot(gap, aes(month, mean_gap)) +
  geom_ribbon(aes(ymin = mean_gap - 1.96 * se_gap,
                  ymax = mean_gap + 1.96 * se_gap), alpha = 0.2) +
  geom_line(linewidth = 0.7) +
  geom_vline(xintercept = T0, linetype = "dashed") +
  facet_wrap(~ outcome, scales = "free_y") +
  labs(x = NULL, y = "log(C26) − log(C27/C28), averaged across countries",
       title = "Within-country sector gap") +
  theme_minimal(base_size = 11)

ggsave("figures/gap.png", p_gap, width = 10, height = 5, dpi = 200)

# 05_figures.R — Part B: model figures

es_df  <- readRDS("data/processed/es_df.rds")
loo    <- readRDS("data/processed/loo.rds")
models <- readRDS("data/processed/models.rds")

p_es <- ggplot(es_df, aes(rel, estimate)) +
  geom_hline(yintercept = 0) +
  geom_vline(xintercept = -0.5, linetype = "dashed") +
  geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = 0.2) +
  geom_point(size = 1.4) +
  facet_wrap(~ outcome, scales = "free_y") +
  labs(x = "Months relative to October 2025",
       y = "Effect on log index",
       title = "Event study: C26 vs C27/C28, within country-month") +
  theme_minimal(base_size = 11)

ggsave("figures/event_study.png", p_es, width = 10, height = 5, dpi = 200)

p_loo <- ggplot(loo, aes(est, reorder(dropped, est))) +
  geom_vline(xintercept = coef(models$main$ppi)[["treated_post"]],
             linetype = "dashed") +
  geom_pointrange(aes(xmin = lo, xmax = hi), size = 0.25) +
  labs(x = "Estimate with country dropped", y = NULL,
       title = "Leave-one-out robustness, prices") +
  theme_minimal(base_size = 10)

ggsave("figures/leave_one_out.png", p_loo, width = 8, height = 6, dpi = 200)

checks <- readRDS("data/processed/checks.rds")

p_checks <- ggplot(checks, aes(est_pct, fct_rev(fct_inorder(check)), colour = type)) +
  geom_vline(xintercept = 0) +
  geom_vline(xintercept = checks$est_pct[checks$check == "Main"], linetype = "dashed") +
  geom_pointrange(aes(xmin = lo_pct, xmax = hi_pct)) +
  labs(x = "Effect on C26 domestic producer prices (%), 95% CI",
       y = NULL, colour = NULL,
       title = "Main estimate and robustness checks") +
  theme_minimal(base_size = 11) +
  theme(legend.position = "bottom")

ggsave("figures/robustness.png", p_checks, width = 8, height = 5, dpi = 200)