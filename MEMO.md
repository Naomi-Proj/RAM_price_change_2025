Question: Did the 2025-26 memory price shock raise European electronicsw manufacturers' prices, and did it
cost them volume (in production)?

Answer: 2-3 sentences, should include uncertainty range.

Method: DiD, comparing NACE C26 to C27,C28 across 24 European countries, monthly, 2019-2016. 
  ## sample rule (set before viewing the outcomes)
    - population: EU27 member states
    - window: 2019-01 to the last month reported by most countries
    - a country is eligible for an outcome if C26, C27 and C28 all have complete
      monthly data across the whole window, with no gaps.
    - from 02R: # prices: NSA, I21
                # produce: SCA (affected strongly by seasonality), I21
      im not sure where this info goes.


Interpretation: what it means in buisness language. 

Limitations: C26 includes non-memory products, so the estimate is diluted and should be read as a lower
 bound. PPI is quality-adjusted, which dampens measured increases in technology categories.

Suggestion: 


about changing the rule from 3/3 sectors to c26 and at least 7 or 8
One line for the memo:
The rule requires complete C26 plus at least one complete control sector.
C27 and C28 serve the same role — comparable manufacturing with minimal memory
content — so requiring both imposes a data constraint the identification 
strategy does not need. Control-group composition therefore varies across
countries; robustness runs restrict to C27 and C28 separately.
REVERT!!! -> were going back to the 3/3 rule, since the results were the same anyway. 
  the only issue was the C26 sector across those few countries (smaller ones),
  meaning the control sectors were not the problm to begin with.
Record both in the memo, because the check itself is a result:
The rule requires complete data on C26, C27 and C28. A relaxed variant 
requiring C26 plus at least one control was also evaluated and produced an 
identical sample, since all exclusions are driven by incomplete C26 series. The
stricter rule is used so that every country contributes the same control group.
AFTER CHECKING PT AND NL GAPS - FINDING THEY ARE RELEVANT TO THE WINDOW
C26 series for NL (both outcomes) and PT (production) have internal gaps of
2–12 months. PT's gap falls in February–March 2025, within the event-study
window; NL's gaps are longer. Admitting them would leave the pre-period
composition varying month to month. The strict balanced-panel rule is 
retained: N countries for prices, M for production.

we got 19 ppi valid, 15 prod valid, 15 overlap. so 4 in ppi arent in prod.
Main specification uses the N countries eligible for both outcomes,
so price and production effects describe the same economies over the same
months. Per-outcome samples (19 prices, 15 production) are reported as robustness.
