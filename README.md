# Cost pass-through of the 2025–26 memory price shock

**One-line finding:** Memory-chip prices roughly quadrupled in late 2025, but
eight months later European electronics producers had not raised prices faster
than comparable manufacturers: −0.5% relative change (95% CI −2.1% to +1.1%),
with pass-through above ~3–4% ruled out.

[Read the full report](https://github.com/Naomi-Proj/RAM_price_change_2025) ·
[One-page memo](MEMO.md)

## Question

From October 2025, DRAM spot prices rose roughly fourfold as supply shifted
toward high-bandwidth memory for AI data centers. Did European manufacturers of
memory-intensive products (NACE C26: computers, electronic and optical
products) pass that cost on to their customers, and how fast? This is
**cost pass-through**: how much of an input-cost shock reaches output prices,
and with what lag.

## Data

- **Source:** Eurostat monthly short-term statistics, downloaded 2026-09-20.
  Official statistics are revised; the analysis is pinned to this vintage. See
  `R/01_download.R` for dataset codes.
- **Outcome:** producer prices, domestic market (`sts_inppd_m`, index
  2021 = 100, not seasonally adjusted). Domestic rather than export prices,
  because export prices carry exchange-rate movements that would not cancel
  between sectors. Industrial production (`sts_inpr_m`, seasonally and calendar
  adjusted) was examined as a second outcome; see Headline result.
- **Sectors:** C26 (treated, memory-heavy) vs. C27 electrical equipment and C28
  machinery (controls: similar manufacturing, minimal memory content).
- **Period:** 2019-01 to 2026-05.
- **Countries:** EU27 states with complete monthly data for all three sectors
  across the whole period: **19 for prices**. Eurostat suppresses C26 in many
  smaller economies, where a handful of firms would make published prices
  confidential, so those countries cannot enter the sample.

## Design

Difference-in-differences with interacted fixed effects, estimated with
`fixest`:

$$\log P_{cst} = \alpha_{cs} + \delta_{ct} + \beta\, D_{cst} + \varepsilon_{cst}$$

- **Country × month effects** ($\delta_{ct}$) compare sectors within the same
  country and month, absorbing every national shock: energy, inflation,
  exchange rates.
- **Country × sector effects** ($\alpha_{cs}$) compare each series to itself,
  making the arbitrary index bases irrelevant.
- $D_{cst} = 1$ for C26 from October 2025. Standard errors are clustered by
  country.
- **Key assumption:** without the shock, the C26-vs-control gap would have
  stayed flat. The estimation window starts in **July 2022**, chosen by a rule
  fixed in advance: the earliest start with no significant pre-treatment drift.
  Earlier windows fail it because of the 2021–22 energy shock, which hit
  energy-intensive C27/C28 harder than C26.

## Headline result

![Event study](figures/event_study.png)

**Prices (left):** the pre-treatment months scatter around zero (parallel
trends holds), and the post-treatment months stay flat through May 2026. There
is no jump at the shock, no spike at the January contract renewals, and no
build-up.

**Production (right):** reported as a **design failure**, not an effect. C26
output was already rising faster than the controls from early 2023, and the
climb continues through the treatment date with no break. Parallel trends
fails, so no causal estimate is reported.

## What I checked

![Robustness](figures/robustness.png)

| Check | Rules out | Result |
|---|---|---|
| Placebo: fake treatment in Oct 2023 | Design producing effects at random dates | 0.0% (−1.7 to +1.7) |
| Leave one country out (×19) | Result driven by a single country | Estimates range −0.8% to −0.1%; none outside the main CI |
| C27 only / C28 only as control | Result depending on the control group | −1.0% / −0.1% |
| Treatment dated Sep 2025 / Jan 2026 | Result depending on the exact start; contract lags | −0.5% / −0.6% |
| Country × sector × calendar-month effects | Sector-specific seasonality in unadjusted prices | −0.5% (−2.1 to +1.1) |
| Two-way clustering (country + month) | Correlated shocks across countries | CI −2.0 to +1.0 |
| Wild cluster bootstrap | Too few clusters (19) for standard clustered SEs | CI −2.1 to +1.1, p = 0.50 |
| Pre-trend drift bound | Undetected trend masking an effect | Up to 2.3 pp; included in the ~3–4% bound |

## Limitations

- **Sector-level data:** C26 includes products with little memory content, so
  larger increases in the most memory-intensive products could be hidden.
- **Common shocks:** a change affecting European electronics prices in all
  countries at once cannot be separated from the memory shock.
- **Sample:** 19 mostly larger economies; small countries are excluded by
  confidentiality.
- **Horizon:** eight months. Pass-through through annual contract renewals
  could still appear in later data.
- **Measurement:** quality adjustment in technology price indices can dampen
  measured increases.

## How this was built

- **Pre-registered decisions:** the country-selection rule and the estimation
  window were decided on data availability and pre-treatment evidence only,
  written into `MEMO.md`, and committed before any post-treatment regression
  (see commit history).
- **Self-checking pipeline:** each script reads from and writes to disk only,
  and asserts its own output with `stopifnot()`. The pipeline halts rather than
  writing invalid data.

## Reproducing

```r
renv::restore()
source("R/01_download.R")   # downloads the current Eurostat vintage
source("R/02_clean.R")
source("R/03_audit.R")
source("R/04_models.R")
source("R/05_figures.R")
source("R/06_render.R")     # builds docs/index.html
```

Raw data is not committed. A fresh download retrieves the current vintage, so
figures may differ slightly from the 2026-09-20 results as Eurostat revises.