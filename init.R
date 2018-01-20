my_packages = c("RJSONIO", "RCurl", "warbleR", "parallel", "tuneR", "seewave", "gbm", "xgboost", "randomForest", "e1071")

install_if_missing = function(p) {
  if (p %in% rownames(installed.packages()) == FALSE) {
    install.packages(p)
  }
}

invisible(sapply(my_packages, install_if_missing))