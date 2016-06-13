#packages <- c('tuneR', 'seewave', 'gbm')
#if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
#  install.packages(setdiff(packages, rownames(installed.packages())))  
#}

library(tuneR)
library(seewave)
library(gbm)
library(caret)
library(xgboost)
library(randomForest)

specan3 <- function(X, bp = c(0,22), wl = 512, threshold = 15, parallel = 1){
  # To use parallel processing: library(devtools), install_github('nathanvan/parallelsugar')
  if(class(X) == "data.frame") {if(all(c("sound.files", "selec", 
                                         "start", "end") %in% colnames(X))) 
  {
    start <- as.numeric(unlist(X$start))
    end <- as.numeric(unlist(X$end))
    sound.files <- as.character(unlist(X$sound.files))
    selec <- as.character(unlist(X$selec))
  } else stop(paste(paste(c("sound.files", "selec", "start", "end")[!(c("sound.files", "selec", 
                                                                        "start", "end") %in% colnames(X))], collapse=", "), "column(s) not found in data frame"))
  } else  stop("X is not a data frame")
  
  #if there are NAs in start or end stop
  if(any(is.na(c(end, start)))) stop("NAs found in start and/or end")  
  
  #if end or start are not numeric stop
  if(all(class(end) != "numeric" & class(start) != "numeric")) stop("'end' and 'selec' must be numeric")
  
  #if any start higher than end stop
  if(any(end - start<0)) stop(paste("The start is higher than the end in", length(which(end - start<0)), "case(s)"))  
  
  #if any selections longer than 20 secs stop
  if(any(end - start>20)) stop(paste(length(which(end - start>20)), "selection(s) longer than 20 sec"))  
  options( show.error.messages = TRUE)
  
  #if bp is not vector or length!=2 stop
  if(!is.vector(bp)) stop("'bp' must be a numeric vector of length 2") else{
    if(!length(bp) == 2) stop("'bp' must be a numeric vector of length 2")}
  
  #return warning if not all sound files were found
  fs <- list.files(path = getwd(), pattern = ".wav$", ignore.case = TRUE)
  if(length(unique(sound.files[(sound.files %in% fs)])) != length(unique(sound.files))) 
    cat(paste(length(unique(sound.files))-length(unique(sound.files[(sound.files %in% fs)])), 
              ".wav file(s) not found"))
  
  #count number of sound files in working directory and if 0 stop
  d <- which(sound.files %in% fs) 
  if(length(d) == 0){
    stop("The .wav files are not in the working directory")
  }  else {
    start <- start[d]
    end <- end[d]
    selec <- selec[d]
    sound.files <- sound.files[d]
  }
  
  # If parallel is not numeric
  if(!is.numeric(parallel)) stop("'parallel' must be a numeric vector of length 1") 
  if(any(!(parallel %% 1 == 0),parallel < 1)) stop("'parallel' should be a positive integer")
  
  # If parallel was called
   if(parallel > 1)
   { options(warn = -1)
     if(all(Sys.info()[1] == "Windows",requireNamespace("parallelsugar", quietly = TRUE) == TRUE)) 
       lapp <- function(X, FUN) parallelsugar::mclapply(X, FUN, mc.cores = parallel) else
         if(Sys.info()[1] == "Windows"){ 
           cat("Windows users need to install the 'parallelsugar' package for parallel computing (you are not doing it now!)")
           lapp <- pbapply::pblapply} else lapp <- function(X, FUN) parallel::mclapply(X, FUN, mc.cores = parallel)} else lapp <- pbapply::pblapply
  
  options(warn = 0)
  
  if(parallel == 1) cat("Measuring acoustic parameters:")
  x <- as.data.frame(lapp(1:length(start), function(i) { 
    r <- tuneR::readWave(file.path(getwd(), sound.files[i]), from = start[i], to = end[i], units = "seconds") 
    
    b<- bp #in case bp its higher than can be due to sampling rate
    if(b[2] > ceiling(r@samp.rate/2000) - 1) b[2] <- ceiling(r@samp.rate/2000) - 1 
    
    
    #frequency spectrum analysis
    songspec <- seewave::spec(r, f = r@samp.rate, plot = FALSE)
    analysis <- seewave::specprop(songspec, f = r@samp.rate, flim = b, plot = FALSE)
    
    #save parameters
    meanfreq <- analysis$mean/1000
    sd <- analysis$sd/1000
    median <- analysis$median/1000
    Q25 <- analysis$Q25/1000
    Q75 <- analysis$Q75/1000
    IQR <- analysis$IQR/1000
    skew <- analysis$skewness
    kurt <- analysis$kurtosis
    sp.ent <- analysis$sh
    sfm <- analysis$sfm
    mode <- analysis$mode/1000
    centroid <- analysis$cent/1000
    
    #Frequency with amplitude peaks
    peakf <- 0#seewave::fpeaks(songspec, f = r@samp.rate, wl = wl, nmax = 3, plot = FALSE)[1, 1]
    
    #Fundamental frequency parameters
    ff <- seewave::fund(r, f = r@samp.rate, ovlp = 50, threshold = threshold, 
                        fmax = b[2] * 1000, plot = FALSE, wl = wl)[, 2]
    meanfun<-mean(ff, na.rm = T)
    minfun<-min(ff, na.rm = T)
    maxfun<-max(ff, na.rm = T)
    
    #Dominant frecuency parameters
    y <- seewave::dfreq(r, f = r@samp.rate, wl = wl, ovlp = 0, plot = F, threshold = threshold, bandpass = b * 1000, fftw = TRUE)[, 2]
    meandom <- mean(y, na.rm = TRUE)
    mindom <- min(y, na.rm = TRUE)
    maxdom <- max(y, na.rm = TRUE)
    dfrange <- (maxdom - mindom)
    duration <- (end[i] - start[i])
    
    #modulation index calculation
    changes <- vector()
    for(j in which(!is.na(y))){
      change <- abs(y[j] - y[j + 1])
      changes <- append(changes, change)
    }
    if(mindom==maxdom) modindx<-0 else modindx <- mean(changes, na.rm = T)/dfrange
    
    #save results
    return(c(duration, meanfreq, sd, median, Q25, Q75, IQR, skew, kurt, sp.ent, sfm, mode, 
             centroid, peakf, meanfun, minfun, maxfun, meandom, mindom, maxdom, dfrange, modindx))
  }))
  
  #change result names
  
  rownames(x) <- c("duration", "meanfreq", "sd", "median", "Q25", "Q75", "IQR", "skew", "kurt", "sp.ent", 
                   "sfm","mode", "centroid", "peakf", "meanfun", "minfun", "maxfun", "meandom", "mindom", "maxdom", "dfrange", "modindx")
  x <- data.frame(sound.files, selec, as.data.frame(t(x)))
  colnames(x)[1:2] <- c("sound.files", "selec")
  rownames(x) <- c(1:nrow(x))
  
  return(x)
}

processFolder <- function(folderName) {
  # Start with empty data.frame.
  data <- data.frame()
  
  # Get list of files in the folder.
  list <- list.files(folderName, '\\.wav')
  
  # Add file list to data.frame for processing.
  for (fileName in list) {
    row <- data.frame(fileName, 0, 0, 20)
    data <- rbind(data, row)
  }
  
  # Set column names.
  names(data) <- c('sound.files', 'selec', 'start', 'end')
  
  # Move into folder for processing.
  setwd(folderName)
  
  # Process files.
  acoustics <- specan3(data, parallel=1)
  
  # Move back into parent folder.
  setwd('..')
  
  acoustics
}

gender <- function(filePath, model = 1, session = NULL) {
  if (model == 1) {
    print('Using model: Boosted Tree Small')
    if (!exists('genderBoosted')) {
      load('data/model1.bin')
    }
    
    fit <- genderBoosted
  }
  else if (model == 2) {
    print('Using model: XGBoost Small')
    if (!exists('genderXG')) {
      load('data/model2.bin')
    }
   
    fit <- genderXG
  }
  else if (model == 3) {
    print('Using model: Tuned Random Forest')
    if (!exists('genderTunedForest')) {
      load('data/model3.bin')
    }
    
    fit <- genderTunedForest
  }
  else if (model == 4) {
    print('Using model: XGBoost Large')
    if (!exists('genderXG2')) {
      load('data/model4.bin')
    }
    
    fit <- genderXG2
  }
  
  # Setup paths.
  currentPath <- getwd()
  fileName <- basename(filePath)
  path <- dirname(filePath)
  
  print(path)
  print(fileName)
  
  # Set directory to read file.
  setwd(path)
  print(getwd())
  
  # Start with empty data.frame.
  data <- data.frame(fileName, 0, 0, 20)
  
  # Set column names.
  names(data) <- c('sound.files', 'selec', 'start', 'end')
  
  if (is.null(session)) {
    # Process files.
    acoustics <- specan3(data, parallel=1)
  }
  else {
    acoustics <- session
  }
  
  # Restore path.
  setwd(currentPath)
  
  if (model == 2 || model == 4) {
    acoustics[,1:3] <- NULL
    acoustics[,'peakf'] <- NULL
    acoustics <- as.matrix(acoustics)
  }

  result <- predict(fit, newdata=acoustics)
  print(result)
  if (model == 1 || model == 3) {
    prob <- predict(fit, newdata=acoustics, type='prob')[,2]
    print(prob)
  }
  else if (model == 2 || model == 4) {
    prob <- result
    mf <- as.factor(c('male', 'female'))
    if (prob >= 0.5) {
      result <- mf[2]
    }
    else {
      result <- mf[1]
    }
  }
  
  list(label = result, prob = prob, data = acoustics)
}
