# Systemic 2 #
Systemic 2 is a C library for analyzing exoplanetary time series. The full distribution of Systemic also includes an R package to interface with the library, and a cross-platform GUI to perform interactive analysis.

## Installing ##
```bash
# install gfortran
sudo add-apt-repository universe
sudo apt update
sudo apt install gfortran
# install R
conda install conda-forge::r-base==4.0.5
# install Java; Java 11.0.12 works for me; current is javac 21.0.4
# isntall gsl-1.15
make -f Makefile.linux gsl

(R) install.packages("rdyncall", repos="http://R-Forge.R-project.org")
(R) q()

```