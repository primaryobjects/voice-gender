#packages <- c('shiny', 'shinyjs', 'RJSONIO', 'RCurl', 'warbleR', 'tuneR', 'seewave', 'gbm')
#if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
#install.packages(setdiff(packages, rownames(installed.packages())))
#}

# In Linux, also required:
# sudo apt-get install libcurl4-openssl-dev cmake r-base-core fftw3 fftw3-dev pkg-config

library(shiny)
library(shinyjs)
library(RJSONIO)
library(RCurl)
library(warbleR)
library(parallel)
library(tuneR)

source('config.R')
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

    if (grepl('.wav', tolower(inFile$name)) != TRUE) {
      content <- '<div class="shiny-output-error-validation">Please select a .WAV file to upload.</div>'
    }
    else if (!is.null(inFile)) {
      disable('btnUrl')
      disable('url')
      disable('file1')

      withProgress(message='Please wait ..', style='old', value=0, {
        result <- processFile(inFile, input$model)

        content <- result$content
        if (!is.null(result$graph1)) {
          output$summary1 <- renderTable(result$summary$summary1)
          output$summary2 <- renderTable(result$summary$summary2)
          output$graph1 <- result$graph1
          output$graph2 <- result$graph2
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

    if (url != '' && grepl('http', tolower(url)) && (grepl('vocaroo.com', url) || grepl('voca.ro', url) || grepl('clyp.it', url))) {
      # Extract url, removing any extraneous text.
      url <- regmatches(url, regexpr('(http|ftp|https)://([\\w_-]+(?:(?:\\.[\\w_-]+)+))([\\w.,@?^=%&:/~+#-]*[\\w@?^=%&/~+#-])?', url, perl=T))

      withProgress(message='Please wait ..', style='old', value=0, {
        result <- processUrl(url, input$model)

        content <- result$content
        if (!is.null(result$graph1)) {
          output$summary1 <- renderTable(result$summary$summary1)
          output$summary2 <- renderTable(result$summary$summary2)
          output$graph1 <- result$graph1
          output$graph2 <- result$graph2
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

  output$content <- eventReactive(v$data, {
    HTML(v$data)
  })
})

processFile <- function(inFile, model) {
  # Create a unique filename.
  id <- sample(1:100000, 1)
  filePath <- paste0('./temp', sample(1:100000, 1), '/temp', id, '.wav')

  logEntry('File uploaded.', paste0('"id": "', id, '", "inFile": "', inFile$datapath, '", "filePath": "', filePath, '"'))

  currentPath <- getwd()
  fileName <- basename(filePath)
  path <- dirname(filePath)

  # Create directory.
  dir.create(path)

  incProgress(0.1, message = 'Uploading clip ..')

  # Copy the temp file to our local folder.
  file.copy(inFile$datapath, filePath)

  logEntry('File copied.', paste0('"id": "', id, '", inFile": "', inFile$datapath, '", "filePath": "', filePath, '"'))

  # Process.
  result <- process(filePath)

  unlink(path, recursive = T)

  logEntry('Classification done.', paste0('"id": "', id, '", "filePath": "', path, '", "class": "', result$content5$label, '", "prob": "', round(result$content5$prob * 100), '"'))

  list(content=formatResult(result), summary=result$summary, graph1=result$graph1, graph2=result$graph2)
}

processUrl <- function(url, model) {
  origUrl <- url

  # Create a unique id for the file.
  id <- sample(1:100000, 1)

  isVocaroo = grepl('vocaroo', tolower(url)) || grepl('voca.ro', tolower(url))
  isClyp = grepl('clyp.it', tolower(url))

  if (isVocaroo || isClyp) {
    currentPath <- getwd()
    mp3 <- ''

    if (isClyp) {
      # Format url for api.
      url <- gsub('www.clyp.it', 'api.clyp.it', url)
      url <- gsub('/clyp.it', '/api.clyp.it', url)

      # Download json.
      json <- getURL(url)
      if (grepl('mp3url', tolower(json))) {
        data <- fromJSON(json)
        mp3 <- data$Mp3Url
      }
    }
    else {
      # Extract the last part of the url after the slash.
      parts <- strsplit(url, '/')
      if (lengths(parts) > 0) {
        id <- parts[[1]][lengths(parts)]
        if (nchar(id) > 0) {
          mp3 <- paste0('https://media1.vocaroo.com/mp3/', id)
        }
      }
    }

    if (nchar(mp3) > 0) {
      # Create a unique filename.
      mp3FilePath <- paste0('./temp', id, '/temp', id, '.mp3')
      wavFilePath <- gsub('.mp3', '.wav', mp3FilePath)

      fileName <- basename(mp3FilePath)
      path <- dirname(mp3FilePath)

      # Create directory.
      dir.create(path)

      incProgress(0.1, message = 'Downloading clip ..')

      logEntry('Downloading url.', paste0('"id": "', id, '", "url": "', origUrl, '", "downloadUrl": "', mp3, '", "mp3FilePath": "', mp3FilePath, '", "wavFilePath": "', wavFilePath, '", "fileName": "', fileName, '", "path": "', path, '"'))

      # Download mp3 file.
      download.file(mp3, mp3FilePath, mode='wb')

      print(mp3)
      print(path)
      print(mp3FilePath)
      print(wavFilePath)
      print(fileName)

      # Set directory to read file.
      setwd(path)

      incProgress(0.2, message = 'Converting mp3 to wav ..')

      logEntry('Converting mp3 to wav.', paste0('"id": "', id, '", "url": "', origUrl, '", "downloadUrl": "', mp3, '", "mp3FilePath": "', mp3FilePath, '", "wavFilePath": "', wavFilePath, '", "fileName": "', fileName, '", "path": "', path, '"'))

      # Convert mp3 to wav (does not always work due to bug with tuneR).
      tryCatch({
        # Use mcparallel to fork the process and hopefully recover from any R session crash.
        if(.Platform$OS.type == 'unix') {
          p <- mcparallel(try(mp32wav()))
          # wait for job to finish and collect all results.
          res <- mccollect(p)
        }
        else {
          try(mp32wav())
        }
      })

      # Restore path.
      setwd(currentPath)

      if (!file.exists(wavFilePath)) {
        r <- readMP3(mp3FilePath)
        writeWave(r, wavFilePath, extensible=FALSE)
      }

      if (file.exists(wavFilePath)) {
        # Process.
        result <- process(wavFilePath)
        graph1 <- result$graph1
        graph2 <- result$graph2

        logEntry('Classification done.', paste0('"id": "', id, '", "url": "', origUrl, '", "filePath": "', wavFilePath, '", "class": "', result$content5$label, '", "prob": "', round(result$content5$prob * 100), '"'))

        content <- formatResult(result)
        summary <- result$summary
      }
      else {
        # Invalid url.
        content <- paste0('<div class="shiny-output-error-validation">Error accessing Vocaroo or Clyp.it URL. Please use the format https://vocaroo.com/12345</div>')
        graph1 <- NULL
        graph2 <- NULL

        logEntry('Classification error. Error accessing url', paste0('"id": "', id, '", "url": "', origUrl, '", "apiUrl": "', url, '"'))
      }
    }
    else {
      content <- paste0('<div class="shiny-output-error-validation">Error converting mp3 to wav.<br>Try converting it manually with <a href="http://media.io" target="_blank">media.io</a>.<br>Your mp3 can be downloaded <a href="', mp3, '">here</a>.</div>')
      graph1 <- NULL
      graph2 <- NULL

      logEntry('Classification error. Error converting mp3 to wav.', paste0('"id": "', id, '", "url": "', origUrl, '"'))
    }

    # Restore working directory and delete temp folder.
    setwd(currentPath)
    unlink(path, recursive=T)

    # Delete extraneous temp file.
    wavFileName <- gsub('.mp3', '.wav', fileName, fixed=T)
    fileNameNoExt <- gsub('.mp3', '', fileName, fixed=T)
    tempFilePath <- paste0(fileNameNoExt, wavFileName)

    unlink(tempFilePath)
  }
  else {
    # 404 Not Found. Maybe a private clyp.it url?
    content <- paste0('<div class="shiny-output-error-validation">Error accessing Vocaroo or Clyp.it URL (404). Please use the format https://vocaroo.com/12345</div>')
    graph1 <- NULL
    graph2 <- NULL

    logEntry('Classification error. Error accessing url', paste0('"id": "', id, '", "url": "', origUrl, '", "apiUrl": "', url, '"'))
  }

  list(content=content, summary=summary, graph1=graph1, graph2=graph2)
}

process <- function(path) {
  content1 <- list(label = 'Sorry, an error occurred.', prob = 0, data = NULL)
  content2 <- list(label = '', prob = 0, data = NULL)
  content3 <- list(label = '', prob = 0, data = NULL)
  content4 <- list(label = '', prob = 0, data = NULL)
  content5 <- list(label = '', prob = 0, data = NULL)
  graph1 <- NULL
  graph2 <- NULL
  summary1 <- data.frame()
  summary2 <- data.frame()

  freq <- list(minf = NULL, meanf = NULL, maxf = NULL)

  id <- gsub('.*temp(\\d+)\\.wav', '\\1', path)
  logEntry('Classifying.', paste0('"id": "', id, '", "filePath": "', path, '"'))

  tryCatch({
    incProgress(0.3, message = 'Processing voice ..')
    content1 <- gender(path, 1)
    incProgress(0.4, message = 'Analyzing voice 1/4 ..')
    content2 <- gender(path, 2, content1)
    incProgress(0.5, message = 'Analyzing voice 2/4 ..')
    content3 <- gender(path, 3, content1)
    incProgress(0.6, message = 'Analyzing voice 3/4 ..')
    content4 <- gender(path, 4, content1)
    incProgress(0.7, message = 'Analyzing voice 4/4 ..')
    content5 <- gender(path, 5, content1)

    incProgress(0.8, message = 'Building graph 2/2 ..')

    wl <- 2048
    ylim <- 280
    thresh <- 5

    # Calculate fundamental frequencies.
    freqs <- fund(content1$wave, fmax=ylim, ylim=c(0, ylim/1000), threshold=thresh, plot=F, wl=wl)
    freq$minf <- round(min(freqs[,2], na.rm = T)*1000, 0)
    freq$meanf <- round(mean(freqs[,2], na.rm = T)*1000, 0)
    freq$maxf <- round(max(freqs[,2], na.rm = T)*1000, 0)

    summary1 <- data.frame(Duration=paste(duration(content1$wave), 's'), Sampling.Rate=content1$wave@samp.rate, Average.Frequency=paste(freq$meanf, 'hz'), Min.Frequency=paste(freq$minf, 'hz'), Max.Frequency=paste(freq$maxf, 'hz'))

    summary2 <- rbind(summary2, data.frame(Type='Support Vector Machine (SVM)', Label=content1$label, Threshold=paste0(round(content1$prob * 100), '%')))
    summary2 <- rbind(summary2, data.frame(Type='XGBoost Small', Label=content2$label, Threshold=paste0(round(content2$prob * 100), '%')))
    summary2 <- rbind(summary2, data.frame(Type='Tuned Random Forest', Label=content3$label, Threshold=paste0(round(content3$prob * 100), '%')))
    summary2 <- rbind(summary2, data.frame(Type='XGBoost Large', Label=content4$label, Threshold=paste0(round(content4$prob * 100), '%')))
    summary2 <- rbind(summary2, data.frame(Type='Stacked', Label=content5$label, Threshold=paste0(round(content5$prob * 100), '%')))
    summary2$Model <- c(1:nrow(summary2))
    summary2 <- summary2[,c(ncol(summary2),1:(ncol(summary2)-1))]

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

      fund(content1$wave, fmax=ylim, ylim=c(0, ylim/1000), type='l', threshold=thresh, col='red', wl=wl)
      x <- freqs[,1]
      y <- freqs[,2] + 0.01
      labels <- freqs[,2]

      subx <- x[seq(1, length(x), 4)]
      suby <- y[seq(1, length(y), 4)]
      sublabels <- paste(round(labels[seq(1, length(labels), 4)] * 1000, 0), 'hz')
      text(subx, suby, labels = sublabels)

      legend(0.5, 0.05, legend=c(paste('Min frequency', freq$minf, 'hz'), paste('Average frequency', freq$meanf, 'hz'), paste('Max frequency', freq$maxf, 'hz')), text.col=c('black', 'darkgreen', 'black'), pch=c(19, 19, 19))

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
      #dfreq(content1$wave, at=seq(0, duration(content1$wave) - 0.1, by=0.1), ylim=c(0, 10), type = "o", main = "Dominant Frequency Every 10 ms")
    })
  }, error = function(e) {
    print(paste0('Error in method process(): ', e))
    if (grepl('cannot open the connection', e) || grepl('cannot open compressed file', e)) {
      restart(e)
    }
  })

  list(content1=content1, content2=content2, content3=content3, content4=content4, content5=content5, summary=list(summary1=summary1, summary2=summary2), graph1=graph1, graph2=graph2, freq=freq)
}

colorize <- function(tag) {
  result <- tag

  if (!grepl('error', tag)) {
    result <- paste0("<span class='", tag, "'>", tag, "</span>")
  }
  else {
    result <- paste0("<span class='error'>", tag, "</span>")
  }

  result
}

formatResult <- function(result) {
  pitchColor <- '#aa00aa;'
  if (result$content5$label == 'male') {
    pitchColor <- '#0000ff'
  }
  html <- paste0('Overall Result: <span style="font-weight: bold;">', colorize(result$content5$label), '</span> <span class="average-pitch"><i class="fa fa-headphones" aria-hidden="true" title="Average Pitch" style="color: ', pitchColor, '"></i>', result$freq$meanf, ' hz</span><hr>')

  html <- paste0(html, '<div class="detail-summary">')
  html <- paste0(html, '<div class="detail-header">Details</div>')
  html <- paste0(html, 'Model 1: ', colorize(result$content1$label), '<i class="fa fa-info" aria-hidden="true" title="Support Vector Machine (SVM), Threshold value: ', round(result$content1$prob * 100), '%"></i>,  ')
  html <- paste0(html, 'Model 2: ', colorize(result$content2$label), '<i class="fa fa-info" aria-hidden="true" title="XGBoost Small, Threshold value: ', round(result$content2$prob * 100), '%"></i>,  ')
  html <- paste0(html, 'Model 3: ', colorize(result$content3$label), '<i class="fa fa-info" aria-hidden="true" title="Tuned Random Forest, Threshold value: ', round(result$content3$prob * 100), '%"></i>,  ')
  html <- paste0(html, 'Model 4: ', colorize(result$content4$label), '<i class="fa fa-info" aria-hidden="true" title="XGBoost Large, Threshold value: ', round(result$content4$prob * 100), '%"></i>,  ')
  html <- paste0(html, 'Model 5: ', colorize(result$content5$label), '<i class="fa fa-info" aria-hidden="true" title="Stacked, Threshold value: ', round(result$content5$prob * 100), '%"></i>')
  html <- paste0(html, '</div>')

  html
}

logEntry <- function(message, extra = NULL) {
  try(
    if (!is.null(message) && nchar(message) > 0) {
      body <- paste0('{"application": "Voice Gender", "message": "', message, '"')

      if (!is.null(extra)) {
        body <- paste0(body, ', ', extra)
      }

      body <- paste0(body, '}')

      getURL(paste0('http://logs-01.loggly.com/inputs/', token), postfields=body)
    }
  )
}

restart <- function(e) {
  system('touch ~/app-root/repo/R/restart.txt')
}