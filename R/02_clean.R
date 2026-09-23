library(tidyverse)

ppi_raw <- readRDS("data/raw/eurostat_ppi_2026-09-21.rds")
prod_raw <- readRDS("data/raw/eurostat_prod_2026-09-21.rds")

sectors <- c("C26", "C27", "C28")

ppi_raw |> dplyr::filter(nace_r2 %in% sectors) |> dplyr::count(indic_bt, unit, s_adj)
prod_raw |> dplyr::filter(nace_r2 %in% sectors) |> dplyr::count(indic_bt, unit, s_adj)

# creating the filtered data frames:
ppi <- ppi_raw |> filter(nace_r2 %in% sectors,
                         unit == "I21",
                         s_adj == "NSA",) |>
                  transmute(
                    outcome = "ppi",
                    geo = as.character(geo),
                    nace_r2 = as.character(nace_r2),
                    month = as.Date(TIME_PERIOD),
                    value = values
                  )

prod <- prod_raw |> filter(nace_r2 %in% sectors,
                           unit == "I21",
                           s_adj == "SCA")|>
                    transmute(
                      outcome = "prod",
                      geo = as.character(geo),
                      nace_r2 = as.character(nace_r2),
                      month = as.Date(TIME_PERIOD),
                      value = values
                  )

# stacking the outcomes:
panel_all <- bind_rows(ppi, prod)

# checking for errors:
stopifnot(nrow(ppi) > 0)
stopifnot(nrow(prod) > 0)

dups <- panel_all |>
  count(outcome, geo, nace_r2, month) |>
  filter(n > 1)

stopifnot(nrow(dups) == 0)

#saving:
saveRDS(panel_all, file.path("data", "processed", "panel_all.rds"))

panel_all |> count(outcome, nace_r2)
cat("Saved panel_all.rds -", nrow(panel_all), "rows\n")