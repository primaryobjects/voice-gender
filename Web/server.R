#packages <- c('shiny', 'shinyjs', 'RJSONIO', 'RCurl', 'warbleR', 'tuneR', 'seewave', 'gbm')
#if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  #install.packages(setdiff(packages, rownames(installed.packages())))  
#}

library(shiny)
library(shinyjs)
library(RJSONIO)
library(RCurl)
library(warbleR)

source('gender.R')

# REST service endpoint.
httpHandler = function(req) {
  if (req$REQUEST_METHOD == "GET") {
    # handle GET requests
    print(req$QUERY_STRING)
    query <- parseQueryString(req$QUERY_STRING)
    # name <- query$name
  }
  else if (req$REQUEST_METHOD == "POST") {
    # handle POST requests here
    reqInput <- req$rook.input
    print(reqInput)
    
    # read a chuck of size 2^16 bytes, should suffice for our test
    #buf <- reqInput$read(2^16)
    
    # simply dump the HTTP request (input) stream back to client
    #shiny:::httpResponse(
    #  200, 'text/plain', buf
    #)
  }  

  message = list(value = "hello")
  
  return(list(status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = toJSON(message)))
}

shiny:::handlerManager$addHandler(shiny:::routeHandler("/json", httpHandler) , "gendervoice")

shinyServer(function(input, output, session) {
  output$content1 <- eventReactive(input$file1, ignoreNULL = T, {
    # input$file1 will be NULL initially. After the user selects
    # and uploads a file, it will be a data frame with 'name',
    # 'size', 'type', and 'datapath' columns. The 'datapath'
    # column will contain the local filenames where the data can
    # be found.
    content <- ''
    inFile <- input$file1
    
    if (!is.null(inFile)) {
      disable('btnUrl')
      disable('url')
      disable('file1')

      content <- processFile(inFile, input$model)
    }
    
    enable('btnUrl')
    enable('url')
    enable('file1')

    HTML(content)
  })

  output$content2 <- eventReactive(input$btnUrl, {
    content <- ''
    url <- input$url

    disable('btnUrl')
    disable('url')
    disable('file1')

    if (url != '') {
      content <- processUrl(url, input$model)
    }

    enable('btnUrl')
    enable('url')
    enable('file1')

    HTML(content)
  })
  
  eventReactive(input$btnRefresh, {
    input$file1 <- NULL
  })
})

processFile <- function(inFile, model) {
  # Create a unique filename.
  filePath <- paste0('./temp', sample(1:100000, 1), '/temp', sample(1:100000, 1), '.wav')
  
  currentPath <- getwd()
  fileName <- basename(filePath)
  path <- dirname(filePath)
  
  # Create directory.
  dir.create(path)
  
  # Copy the temp file to our local folder.
  file.copy(inFile$datapath, filePath)
  
  content1 <- gender(filePath, 1)
  content2 <- gender(filePath, 2, content1$data)
  content3 <- gender(filePath, 3, content1$data)
  content4 <- gender(filePath, 4, content1$data)

  unlink(path, recursive = T)
  
  paste0('Boosted Tree Small: ', colorize(content1$label), ' (', round(content1$prob * 100), '%)<br>', 'XGBoost Small: ', colorize(content2$label), ' (', round(content2$prob * 100), '%)<br>', 'Tuned Random Forest: ', colorize(content3$label), ' (', round(content3$prob * 100), '%)<br>', 'XGBoost Large: ', colorize(content4$label), ' (', round(content4$prob * 100), '%)')
}

processUrl <- function(url, model) {
  if (grepl('vocaroo', tolower(url))) {
    # Create a unique filename.
    fileName <- paste0('temp', sample(1:100000, 1), '.wav')
    
    # Get id from url.
    id <- gsub('.+/i/(\\w+)', '\\1', url)
    url <- paste0('http://vocaroo.com/media_command.php?media=', id, '&command=download_wav')
    print(paste('Downloading', url, sep=' '))
    
    # Download wav file.
    download.file(url, fileName)
    
    # Process.        
    content1 <- gender(fileName, 1)
    content2 <- gender(fileName, 2, content1$data)
    content3 <- gender(fileName, 3, content1$data)
    content4 <- gender(fileName, 4, content1$data)
    
    # Delete temp file.
    file.remove(fileName)
    
    content <- paste0('Boosted Tree Small: ', colorize(content1$label), ' (', round(content1$prob * 100), '%)<br>', 'XGBoost Small: ', colorize(content2$label), ' (', round(content2$prob * 100), '%)<br>', 'Tuned Random Forest: ', colorize(content3$label), ' (', round(content3$prob * 100), '%)<br>', 'XGBoost Large: ', colorize(content4$label), ' (', round(content4$prob * 100), '%)')
  }
  else if (grepl('clyp.it', tolower(url))) {
    # Format url for api.
    url <- gsub('www.clyp.it', 'api.clyp.it', url)
    url <- gsub('/clyp.it', '/api.clyp.it', url)
    
    # Download json.
    json <- getURL(url)
    data <- fromJSON(json)
    mp3 <- data$Mp3Url
    
    # Create a unique filename.
    mp3FilePath <- paste0('./temp', sample(1:100000, 1), '/temp', sample(1:100000, 1), '.mp3')
    wavFilePath <- gsub('.mp3', '.wav', mp3FilePath)
    
    currentPath <- getwd()
    fileName <- basename(mp3FilePath)
    path <- dirname(mp3FilePath)
    
    # Create directory.
    dir.create(path)
    
    # Download mp3 file.
    download.file(mp3, mp3FilePath)
    
    print(path)
    print(mp3FilePath)
    print(wavFilePath)
    print(fileName)
    
    # Set directory to read file.
    setwd(path)
    
    # Convert mp3 to wav.
    try(mp32wav())
    
    # Restore path.
    setwd(currentPath)
    
    if (file.exists(wavFilePath)) {
      # Process.        
      content1 <- gender(wavFilePath, 1)
      content2 <- gender(wavFilePath, 2, content1$data)
      content3 <- gender(wavFilePath, 3, content1$data)
      content4 <- gender(wavFilePath, 4, content1$data)

      content <- paste0('Boosted Tree Small: ', colorize(content1$label), ' (', round(content1$prob * 100), '%)<br>', 'XGBoost Small: ', colorize(content2$label), ' (', round(content2$prob * 100), '%)<br>', 'Tuned Random Forest: ', colorize(content3$label), ' (', round(content3$prob * 100), '%)<br>', 'XGBoost Large: ', colorize(content4$label), ' (', round(content4$prob * 100), '%)')
    }
    else {
      content <- 'Error converting mp3 to wav.'
    }
    
    # Delete temp file.
    unlink(path, recursive=T)
  }
  
  content
}

colorize <- function(tag) {
  result <- tag
  
  if (tag == 'female') {
    result <- paste0("<span style='color: #ff00ff;'>", tag, "</span>")
  }
  else if (tag == 'male') {
    result <- paste0("<span style='color: #0066ff;'>", tag, "</span>")
  }
  
  result
}