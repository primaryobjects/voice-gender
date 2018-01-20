library(shiny)

packages <- c('shiny', 'shinyjs', 'RJSONIO', 'RCurl', 'warbleR', 'tuneR', 'seewave', 'gbm', 'xgboost', 'randomForest', 'e1071')
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
	install.packages(setdiff(packages, rownames(installed.packages())))  
}

port <- Sys.getenv('PORT')

shiny::runApp(
  appDir = paste0(getwd(), '/Web'),
  host = '0.0.0.0',
  port = as.numeric(port)
)