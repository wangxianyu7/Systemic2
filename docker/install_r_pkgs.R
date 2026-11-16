# R packages the Systemic console loads (R/systemic.r), plus Hmisc.
#
# gtools, gdata, mvtnorm, MASS, KernSmooth, lattice come from fedora:26 RPMs.
# Everything else is built from a pinned 2018 CRAN snapshot (R 3.4.4 era) for
# reproducibility — the F26 R-bitops/R-caTools/R-gplots RPMs install files R can't
# load, so those come from the snapshot too.
options(repos = c(CRAN = "https://packagemanager.posit.co/cran/2018-04-02"))

# Rcpp MUST be reinstalled from source first: the F26 R-Rcpp RPM reports as present
# but ships no usable headers, so every C++ package below (scales -> ggplot2 ->
# Hmisc) fails with "Rcpp.h: No such file or directory". Unconditional on purpose.
install.packages("Rcpp")

from_snapshot <- c("bitops", "caTools", "gplots",
                   "circular", "stringr", "magrittr", "xtable", "latex2exp",
                   "Hmisc")
todo <- Filter(function(p) !requireNamespace(p, quietly = TRUE), from_snapshot)
if (length(todo)) install.packages(todo)

want <- c("rdyncall", "gtools", "gdata", "mvtnorm", "MASS", "KernSmooth", "lattice",
          "Rcpp", from_snapshot)
for (p in want)
  cat(sprintf("%-11s %s\n", p, ifelse(requireNamespace(p, quietly = TRUE), "OK", "MISSING")))
bad <- Filter(function(p) !requireNamespace(p, quietly = TRUE), want)
if (length(bad)) stop(paste("R packages missing:", paste(bad, collapse = ", ")))
