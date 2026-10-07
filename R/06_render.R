# 06_render.R — render the full report for GitHub Pages
# Input:  report.Rmd (+ figures/, data/processed/*.rds)
# Output: docs/index.html

dir.create("docs", showWarnings = FALSE)
unlink("docs/index.html")    # remove old copy so a failed render can't leave a stale page

rmarkdown::render("report.Rmd",
                  output_file = "index.html",
                  output_dir  = "docs",
                  envir       = new.env())   

stopifnot(file.exists("docs/index.html"))