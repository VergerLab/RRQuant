## TO RUN IN THE RSTUDIO CONSOLE
## THIS WILL CHECK IF THE PACKAGES ARE ALREADY INSTALLED AND INSTALL THE ONES THAT ARE NEEDED ONLY.

# Define the packages you want to install
packages <- c("data.table", "readr", "stringr", "tidyverse", "shiny", "plotly", "bslib", "sortable")
# Find out which packages are already installed
installed_packages <- rownames(installed.packages())
# Determine which packages are not installed
packages_to_install <- setdiff(packages, installed_packages)
# Install the packages that are not yet installed
if (length(packages_to_install) > 0) {
  install.packages(packages_to_install)
} else {
  cat("All packages are already installed.\n")
}
