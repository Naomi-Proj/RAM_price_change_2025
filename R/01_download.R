# 01_download.R - pull Eurostat PPI and industrial production.
# run manually, write dated raw files to data/raw/

library(eurostat)

stamp <- Sys.Date()

# Producer prices in industry, monthly
ppi <- get_eurostat("sts_inppd_m", time_format = "date")

# Production in industry, monthly
prod <- get_eurostat("sts_inpr_m", time_format = "date")

saveRDS(ppi, file.path("data", "raw", paste0("eurostat_ppi_", stamp, ".rds")))
saveRDS(prod, file.path("data", "raw", paste0("eurostat_prod_", stamp, ".rds")))

cat("Downloaded", stamp, "\n")
cat("PPI rows:", nrow(ppi), " Production rows:", nrow(prod), "\n")

# Vintage downloaded: 2026-09-20 17:00
# Eurostat updets their data; re-running will not reproduce these files exactly.
# Raw files are dated in data/raw/.

# Vintage downloaded: 2026-09-21 11:52