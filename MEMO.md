# Memo: Did the 2025–26 memory-chip price shock reach electronics prices?

**Question.** Memory chips roughly quadrupled in price between September and
December 2025. Did European manufacturers of memory-intensive electronics
respond by raising their prices faster than comparable manufacturers — and
how quickly?

**Answer.** Not within eight months. Through May 2026, producer prices for
computers, electronic and optical products rose about as much as prices for
comparable machinery and electrical-equipment manufacturers in the same
countries: the estimated difference is −0.5% (95% range: −2.1% to +1.1%).
Allowing for slow trends the data cannot fully rule out, a price response
larger than about 3–4% can be excluded at this horizon.

**Method.** For each of 19 EU countries, I compared monthly producer prices of
the memory-intensive sector (NACE C26) with two similar sectors that use
little memory (C27 electrical equipment, C28 machinery), before and after
October 2025. Comparing sectors within the same country and month removes
everything they share — energy costs, inflation, exchange rates. The key
assumption is that without the shock the sectors' prices would have moved in
parallel; this holds in the data from mid-2022 until the shock. The result is
unchanged when each comparison sector is used alone, when using a method 
designed for small numbers of countries, when seasonal patterns are removed,
when the start date is shifted, when any single country is dropped, and when
the method is applied to a fake date where no effect should appear.

**What this means.** A fourfold rise in a key component had not reached
output prices eight months later. The cost was absorbed somewhere before the
customer — in margins, inventories, or fixed-price supply contracts — which
this data cannot distinguish. For buyers, there was no shock-driven price
increase through May 2026. For planning, "not yet" is not "never": memory is
largely bought on quarterly and annual contracts, so any pass-through would
appear as contracts renew. There was no sign of it building by May 2026.

**Limitations.**
- The sector-wide result can hide larger increases in the most
  memory-intensive products within it (C26 also covers optics, instruments
  and components with little memory content).
- Quality adjustment in technology price indices can dampen measured
  increases.
- The 19 countries are mostly larger economies; small countries are excluded
  because their electronics data is confidential.
- A shock hitting European electronics everywhere at once — such as AI-driven
  demand — cannot be separated from the memory shock by this design.
- Production was also examined but is not reported as an effect: memory-heavy 
  electronics output was already rising faster than the comparison sectors since
  early 2023, so the method's key assumption fails for it.

**What I'd do next.** Re-run as new data is published (the pipeline is fully
reproducible) to see whether pass-through appears after mid-2026 contract
renewals, and repeat the analysis on narrower product groups where memory is
a larger share of costs.

---

## Decisions recorded before estimation

**Data.** Eurostat monthly producer prices, domestic market (`sts_inppd_m`,
index 2021 = 100, not seasonally adjusted) and industrial production
(`sts_inpr_m`, index 2021 = 100, seasonally and calendar adjusted). Vintage
downloaded 2026-09-20. Domestic rather than export prices, because export
prices carry exchange-rate movements that would not cancel between sectors.

**Sample rule.**
- Population: EU27 member states (this also excludes Eurostat aggregates).
- Window: 2019-01 to 2026-05. It ends in May 2026 because Portugal's
  production reporting becomes incomplete from June 2026.
- A country is eligible for an outcome if C26, C27 and C28 all have complete
  monthly data across the whole window.
- Result: 19 countries eligible for prices, 15 for production.

**Checks on the rule.**
- A relaxed rule (C26 plus at least one complete control sector) produced an
  identical sample: every exclusion is driven by incomplete C26 series, none
  by missing controls. The strict rule is kept so every country contributes
  the same control group.
- Near-miss countries have internal gaps rather than late starts: NL prices
  (2022-10 to 2024-03), NL production (all of 2021), PT production
  (2025-02 to 2025-03, inside the event-study window). Admitting them would
  make the pre-period composition vary month to month, so the strict rule is
  retained.

**Common sample (plan changed).** The original plan used the 15 countries
eligible for both outcomes, so that price and production effects would
describe the same economies. After the descriptive figures showed production
fails the parallel-trends assumption, before any price
regression), production was dropped as an outcome and the main specification
uses all 19 price-eligible countries.

**Estimation window.** Rule: WIN_START is the earliest candidate start date
whose pre-treatment C26-vs-control gap shows no significant linear drift
(p > 0.05, clustered by country). Earliest, not best.

Result: WIN_START = 2022-07-01 (39 pre-treatment months, 8 post).

|start      | slope_per_year| se_per_year|      p| n_months| lever| bias_bound|
|:----------|--------------:|-----------:|------:|--------:|-----:|----------:|
|2019-01-01 |        -0.0176|      0.0035| 0.0001|       81|  44.5|     9.2233|
|2021-01-01 |        -0.0119|      0.0043| 0.0126|       57|  32.5|     5.6643|
|2022-07-01 |        -0.0012|      0.0049| 0.8029|       39|  23.5|     2.2694|
|2023-01-01 |         0.0005|      0.0050| 0.9149|       33|  20.5|     1.9048|
|2023-07-01 |        -0.0029|      0.0056| 0.6103|       27|  17.5|     2.1477|

Windows starting in 2019 and 2021 show significant negative drift, consistent
with the 2021–22 energy shock hitting energy-intensive C27/C28 harder than
C26. From mid-2022 the gap is flat (slope −0.0012/yr, p = 0.80).

Caveat: failing to detect drift is not proof of its absence. Translating the
drift estimate's 95% range into its maximum effect on the main estimate,
undetected drift could account for up to about 2.3 percentage points.