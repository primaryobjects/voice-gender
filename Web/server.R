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

options(shiny.maxRequestSize=2*1024^2)

shinyServer(function(input, output, session) {
  v <- reactiveValues(data = NULL)

  observeEvent(input$file1, {
    # input$file1 will be NULL initially. After the user selects
    # and uploads a file, it will be a data frame with 'name',
    # 'size', 'type', and 'datapath' columns. The 'datapath'
    # column will contain the local filenames where the data can
    # be found.
    content <- ''
    inFile <- input$file1
    
    hide('graphs')
    hide('graph1')
    hide('graph2')
    
    if (grepl('.wav', tolower(inFile$name)) != TRUE) {
      content <- '<div class="shiny-output-error-validation">Please select a .WAV file to upload.</div>'
    }
    else if (!is.null(inFile)) {
      disable('btnUrl')
      disable('url')
      disable('file1')
      
      withProgress(message='Please wait ..', value=0, {
        result <- processFile(inFile, input$model)
        
        content <- result$content
        if (!is.null(result$graph1)) {
          output$graph1 <- result$graph1
          output$graph2 <- result$graph2
          runjs("document.getElementById('graphs').style.display = 'block'; document.getElementById('graph1').style.display = 'block'; document.getElementById('graph2').style.display = 'block';")
        }
      })
    }
    
    enable('btnUrl')
    enable('url')
    enable('file1')
    
    v$data <- content
  })
  
  observeEvent(input$btnUrl, {
    content <- ''
    url <- input$url
    
    disable('btnUrl')
    disable('url')
    disable('file1')
    hide('graphs')
    hide('graph1')
    hide('graph2')
    
    if (url != '' && grepl('http', tolower(url)) && (grepl('vocaroo.com', url) || grepl('clyp.it', url))) {
      withProgress(message='Please wait ..', value=0, {
        result <- processUrl(url, input$model)
        
        content <- result$content
        if (!is.null(result$graph1)) {
          output$graph1 <- result$graph1
          output$graph2 <- result$graph2
          runjs("document.getElementById('graphs').style.display = 'block'; document.getElementById('graph1').style.display = 'block'; document.getElementById('graph2').style.display = 'block';")
        }
      })
    }
    else {
      content <- '<div class="shiny-output-error-validation">Please enter a url to vocaroo or clyp.it.</div>'
    }
    
    enable('btnUrl')
    enable('url')
    enable('file1')
    
    v$data <- content
  })
  
  observeEvent(input$btnProcessRecording, {
    # Decode wav file.
    audio <- input$audio
    audio <- gsub('data:audio/wav;base64,', '', audio)
    audio <- gsub(' ', '+', audio)
    audio <- base64Decode(audio, mode = 'raw')
    
    # Save to file.
    inFile <- list()
    inFile$datapath <- paste0('temp', sample(1:100000, 1), '.wav')
    inFile$file <- file(inFile$datapath, 'wb')
    writeBin(audio, inFile$file)
    close(inFile$file)
    
    print(inFile$datapath)
    
    # Process file.
    withProgress(message='Please wait ..', value=0, {
      result <- processFile(inFile)
      
      content <- result$content
      if (!is.null(result$graph1)) {
        output$graph1 <- result$graph1
        output$graph2 <- result$graph2
        runjs("document.getElementById('graphs').style.display = 'block'; document.getElementById('graph1').style.display = 'block'; document.getElementById('graph2').style.display = 'block';")
      }
      
      unlink(inFile$datapath)
    })

    v$data <- content
  })
  
  output$content <- eventReactive(v$data, {
    HTML(v$data)
  })

  hide("graphs")
  hide("graph1")
  hide("graph2")
})

processFile <- function(inFile, model) {
  # Create a unique filename.
  filePath <- paste0('./temp', sample(1:100000, 1), '/temp', sample(1:100000, 1), '.wav')
  
  currentPath <- getwd()
  fileName <- basename(filePath)
  path <- dirname(filePath)
  
  # Create directory.
  dir.create(path)
  
  incProgress(0.1, message = 'Uploading clip ..')
  
  # Copy the temp file to our local folder.
  file.copy(inFile$datapath, filePath)
  
  # Process.
  result <- process(filePath)
  content1 <- result$content1
  content2 <- result$content2
  content3 <- result$content3
  content4 <- result$content4
  content5 <- result$content5
  
  unlink(path, recursive = T)
  
  list(content=paste0('SVM (96/85): ', colorize(content1$label), ' (', round(content1$prob * 100), '%)<br>', 'XGBoost Small: ', colorize(content2$label), ' (', round(content2$prob * 100), '%)<br>', 'Tuned Random Forest (100/87): ', colorize(content3$label), ' (', round(content3$prob * 100), '%)<br>', 'XGBoost Large (100/87): ', colorize(content4$label), ' (', round(content4$prob * 100), '%)<br>', 'Stacked (100/89): ', colorize(content5$label), ' (', round(content5$prob * 100), '%)'), graph1=result$graph1, graph2=result$graph2)
}

processUrl <- function(url, model) {
  if (grepl('vocaroo', tolower(url))) {
    # Create a unique filename.
    fileName <- paste0('temp', sample(1:100000, 1), '.wav')
    
    # Get id from url.
    id <- gsub('.+/i/(\\w+)', '\\1', url)
    url <- paste0('http://vocaroo.com/media_command.php?media=', id, '&command=download_wav')
    print(paste('Downloading', url, sep=' '))
    
    incProgress(0.1, message = 'Downloading clip ..')
    
    # Download wav file.
    download.file(url, fileName)
    
    # Process.        
    result <- process(fileName)
    content1 <- result$content1
    content2 <- result$content2
    content3 <- result$content3
    content4 <- result$content4
    content5 <- result$content5
    graph1 <- result$graph1
    graph2 <- result$graph2
    
    # Delete temp file.
    file.remove(fileName)
    
    content <- paste0('SVM (96/85): ', colorize(content1$label), ' (', round(content1$prob * 100), '%)<br>', 'XGBoost Small: ', colorize(content2$label), ' (', round(content2$prob * 100), '%)<br>', 'Tuned Random Forest (100/87): ', colorize(content3$label), ' (', round(content3$prob * 100), '%)<br>', 'XGBoost Large (100/87): ', colorize(content4$label), ' (', round(content4$prob * 100), '%)<br>', 'Stacked (100/89): ', colorize(content5$label), ' (', round(content5$prob * 100), '%)')
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
    r <- sample(1:100000, 1)
    mp3FilePath <- paste0('./temp', r, '/temp', r, '.mp3')
    wavFilePath <- gsub('.mp3', '.wav', mp3FilePath)
    
    currentPath <- getwd()
    fileName <- basename(mp3FilePath)
    path <- dirname(mp3FilePath)
    
    # Create directory.
    dir.create(path)
    
    incProgress(0.1, message = 'Downloading clip ..')
    
    # Download mp3 file.
    download.file(mp3, mp3FilePath)
    
    print(path)
    print(mp3FilePath)
    print(wavFilePath)
    print(fileName)
    
    # Set directory to read file.
    setwd(path)

    # Convert mp3 to wav (does not always work due to bug with tuner).
    try(mp32wav())

    # Restore path.
    setwd(currentPath)
    
    if (file.exists(wavFilePath)) {
      # Process.
      result <- process(wavFilePath)
      content1 <- result$content1
      content2 <- result$content2
      content3 <- result$content3
      content4 <- result$content4
      content5 <- result$content5
      graph1 <- result$graph1
      graph2 <- result$graph2
      
      content <- paste0('SVM (96/85): ', colorize(content1$label), ' (', round(content1$prob * 100), '%)<br>', 'XGBoost Small: ', colorize(content2$label), ' (', round(content2$prob * 100), '%)<br>', 'Tuned Random Forest (100/87): ', colorize(content3$label), ' (', round(content3$prob * 100), '%)<br>', 'XGBoost Large (100/87): ', colorize(content4$label), ' (', round(content4$prob * 100), '%)<br>', 'Stacked (100/89): ', colorize(content5$label), ' (', round(content5$prob * 100), '%)')
    }
    else {
      content <- paste0('<div class="shiny-output-error-validation">Error converting mp3 to wav.<br>Try converting it manually with <a href="http://media.io" target="_blank">media.io</a>.<br>Your mp3 can be downloaded <a href="', mp3, '">here</a>.</div>')
      graph1 <- NULL
    }
    
    # Delete temp file.
    unlink(path, recursive=T)
  }
  
  list(content=content, graph1=graph1, graph2=graph2)
}

process <- function(path) {
  content1 <- list(label = 'Sorry, an error occurred.', prob = 0, data = NULL)
  content2 <- list(label = '', prob = 0, data = NULL)
  content3 <- list(label = '', prob = 0, data = NULL)
  content4 <- list(label = '', prob = 0, data = NULL)
  content5 <- list(label = '', prob = 0, data = NULL)
  graph1 <- NULL
  graph2 <- NULL
  
  tryCatch({
    incProgress(0.2, message = 'Processing voice ..')
    content1 <- gender(path, 1)
    incProgress(0.3, message = 'Analyzing voice 1/4 ..')
    content2 <- gender(path, 2, content1)
    incProgress(0.4, message = 'Analyzing voice 2/4 ..')
    content3 <- gender(path, 3, content1)
    incProgress(0.5, message = 'Analyzing voice 3/4 ..')
    content4 <- gender(path, 4, content1)
    incProgress(0.6, message = 'Analyzing voice 4/4 ..')
    content5 <- gender(path, 5, content1)
    
    incProgress(0.8, message = 'Building graph 2/2 ..')
    
    wl <- 2048
    ylim <- 280
    thresh <- 5
    
    graph1 <- renderPlot({
      #content1$wave <- ffilter(content1$wave, from=0, to=400, output='Wave')
      #content1$wave <- fir(content1$wave, from=80, to=280, output='Wave')
      
      # spectro(content1$wave, ovlp=40, zp=8, scale=FALSE, flim=c(0,0.5))
      # par(new=TRUE)
      # 
      # freqs <- dfreq(content1$wave, at = seq(0.0, duration(content1$wave), by = 0.5), type = "o", xlim = c(0.0, duration(content1$wave)), ylim=c(0, 0.5), main = "a measure every 10 ms", plot=F)
      # dfreq(content1$wave, at = seq(0.0, duration(content1$wave), by = 0.5), type = "o", xlim = c(0.0, duration(content1$wave)), ylim=c(0, 0.5), main = "a measure every 10 ms")
      # 
      # x <- freqs[,1]
      # y <- freqs[,2] + 0.01
      # labels <- freqs[,2]
      # 
      # subx <- x[seq(1, length(x), 3)]
      # suby <- y[seq(1, length(y), 3)]
      # sublabels <- paste(labels[seq(1, length(labels), 3)] * 1000, 'hz')
      # text(subx, suby, labels = sublabels)
      # 
      # minf <- round(min(freqs[,2], na.rm = T)*1000, 0)
      # meanf <- round(mean(freqs[,2], na.rm = T)*1000, 0)
      # maxf <- round(max(freqs[,2], na.rm = T)*1000, 0)
      # text(duration(content1$wave) / 2, 0.47, labels = paste('Minimum Frequency = ', minf, 'hz'))
      # text(duration(content1$wave) / 2, 0.46, labels = paste('Avgerage Frequency = ', meanf, 'hz'))
      # text(duration(content1$wave) / 2, 0.45, labels = paste('Maximum Frequency = ', maxf, 'hz'))
      
      
      freqs <- fund(content1$wave, fmax=ylim, ylim=c(0, ylim/1000), threshold=thresh, plot=F, wl=wl)
      fund(content1$wave, fmax=ylim, ylim=c(0, ylim/1000), type='l', threshold=thresh, col='red', wl=wl)
      x <- freqs[,1]
      y <- freqs[,2] + 0.01
      labels <- freqs[,2]
      
      subx <- x[seq(1, length(x), 4)]
      suby <- y[seq(1, length(y), 4)]
      sublabels <- paste(round(labels[seq(1, length(labels), 4)] * 1000, 0), 'hz')
      text(subx, suby, labels = sublabels)
      
      minf <- round(min(freqs[,2], na.rm = T)*1000, 0)
      meanf <- round(mean(freqs[,2], na.rm = T)*1000, 0)
      maxf <- round(max(freqs[,2], na.rm = T)*1000, 0)
      legend(0.5, 0.05, legend=c(paste('Min frequency', minf, 'hz'), paste('Average frequency', meanf, 'hz'), paste('Max frequency', maxf, 'hz')), text.col=c('black', 'darkgreen', 'black'), pch=c(19, 19, 19))

      #dfreq(content1$wave, at=seq(0, duration(content1$wave) - 0.1, by=0.1), threshold=5, type="l", col="red", lwd=2, xlab='', xaxt='n', yaxt='n')
#      par(new=TRUE)
      #fund(wav, threshold=6, fmax=8000, type="l", col="green", lwd=2, xlab='', xaxt='n', yaxt='n')
      #par(new=TRUE)
#      res <- autoc(content1$wave, threshold=5, fmin=50, fmax=300, plot=T, type='p', col='black', xlab='', ylab='', xaxt='n', yaxt='n')
      #legend(0, 8, legend=c('Fundamental frequency', 'Fundamental frequency', 'Dominant frequency'), col=c('green', 'black', 'red'), pch=c(19, 1, 19))
#      legend(0, 8, legend=c('Fundamental frequency', 'Dominant frequency'), col=c('black', 'red'), pch=c(1, 19))
    })
    
    incProgress(0.9, message = 'Building graph 2/2 ..')
    graph2 <- renderPlot({
      spectro(content1$wave, ovlp=40, zp=8, scale=FALSE, flim=c(0,ylim/1000), wl=wl)
      #par(new=TRUE)
      #dfreq(content1$wave, threshold=thresh, wl=wl, ylim=c(0, ylim/1000), type="l", col="red", lwd=2, xlab='', xaxt='n', yaxt='n')
    })
  }, warning = function(e) {
    print(e)
    if (grepl('cannot open the connection', e) || grepl('cannot open compressed file', e)) {
      restart(e)
    }
  }, error = function(e) {
    print(e)
    if (grepl('cannot open the connection', e) || grepl('cannot open compressed file', e)) {
      restart(e)
    }
  })
  
  list(content1=content1, content2=content2, content3=content3, content4=content4, content5=content5, graph1=graph1, graph2=graph2)
}

colorize <- function(tag) {
  result <- tag
  
  if (tag == 'female') {
    result <- paste0("<span style='color: #ff00ff;'>", tag, "</span>")
  }
  else if (tag == 'male') {
    result <- paste0("<span style='color: #0066ff;'>", tag, "</span>")
  }
  else if (grepl('error', tag)) {
    result <- paste0("<span style='color: #ff0000;'>", tag, "</span>")
  }
  
  result
}

restart <- function(e) {
  system('touch ~/app-root/repo/R/restart.txt')
}