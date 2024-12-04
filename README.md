# Systemic 2 #
Systemic 2 is a C library for analyzing exoplanetary time series. The full distribution of Systemic also includes an R package to interface with the library, and a cross-platform GUI to perform interactive analysis.

## Installing ##
```bash
# install gfortran
sudo add-apt-repository universe
sudo apt update
sudo apt install gfortran
# install R
sudo apt-get install r-base

# isntall gsl-1.15
sudo apt-get install libgsl-dev
tar -xvzf deps.tar.gz
cd deps/gsl; tar -xvzf gsl-1.15.tar.gz; cd gsl-1.15; ./configure --prefix='$(shell pwd)/deps'; make; make install

(R) install.packages("rdyncall", repos="http://R-Forge.R-project.org")
(R) install.packages("stringr")
(R) install.packages("Hmisc")
(R) install.packages("magrittr")
(R) install.packages("xtable")
(R) install.packages("latex2exp")

(R) q()

```