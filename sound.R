packages <- c('tuneR', 'seewave', 'fftw', 'caTools', 'randomForest', 'warbleR', 'mice', 'e1071', 'rpart', 'rpart-plot', 'xgboost', 'e1071')
if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))  
}
library(tuneR)
library(seewave)
library(caTools)
library(rpart)
library(rpart.plot)
library(randomForest)
library(warbleR)
library(mice)
library(xgboost)
library(e1071)

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

gender <- function(filePath) {
  if (!exists('genderBoosted')) {
    load('model.bin')
  }
  
  # Setup paths.
  currentPath <- getwd()
  fileName <- basename(filePath)
  path <- dirname(filePath)
  
  # Set directory to read file.
  setwd(path)
  
  # Start with empty data.frame.
  data <- data.frame(fileName, 0, 0, 20)
  
  # Set column names.
  names(data) <- c('sound.files', 'selec', 'start', 'end')
  
  # Process files.
  acoustics <- specan3(data, parallel=1)
  
  # Restore path.
  setwd(currentPath)
  
  predict(genderCombo, newdata=acoustics)
}

# Load data
males <- processFolder('male')
females <- processFolder('female')

# Set labels.
males$label <- 1
females$label <- 2
data <- rbind(males, females)
data$label <- factor(data$label, labels=c('male', 'female'))

# Remove unused columns.
data$duration <- NULL
data$sound.files <- NULL
data$selec <- NULL
data$peakf <- NULL

# Remove rows containing NA's.
data <- data[complete.cases(data),]

# Write out csv dataset.
write.csv(data, file='voice.csv', sep=',', row.names=F)

# Create a train and test set.
set.seed(777)
spl <- sample.split(data$label, 0.7)
train <- subset(data, spl == TRUE)
test <- subset(data, spl == FALSE)

# Build models.
genderLog <- glm(label ~ ., data=train, family='binomial')
genderCART <- rpart(label ~ ., data=train, method='class')
prp(genderCART)
genderForest <- randomForest(label ~ ., data=train)

# Assume a basline model of always predicting male.
# Accuracy: 0.50
table(train$label)
1107 / nrow(train)

# Accuracy: 0.50
table(test$label)
475 / nrow(test)

# Accuracy: 0.72
predictLog <- predict(genderLog, type='response')
table(train$label, predictLog >= 0.5)
(814 + 777) / nrow(train)

# Accuracy: 0.71
predictLog2 <- predict(genderLog, newdata=test, type='response')
table(test$label, predictLog2 >= 0.5)
(339 + 335) / nrow(test)

# Accuracy: 0.81
predictCART <- predict(genderCART)
predictCART.prob <- predictCART[,2]
table(train$label, predictCART.prob >= 0.5)
(858 + 941) / nrow(train)

# Accuracy: 0.78
predictCART2 <- predict(genderCART, newdata=test)
predictCART2.prob <- predictCART2[,2]
table(test$label, predictCART2.prob >= 0.5)
(364 + 378) / nrow(test)

# Accuracy: 1
predictForest <- predict(genderForest, newdata=train)
table(train$label, predictForest)

# Accuracy: 0.86
predictForest <- predict(genderForest, newdata=test)
table(test$label, predictForest)
(410 + 409) / nrow(test)

# Tune random-forest and return best model.
# Accuracy: 0.87
set.seed(777)
genderTunedForest <- tuneRF(train[, -21], train[, 21], stepFactor=.5, doBest=TRUE)
predictForest <- predict(genderTunedForest, newdata=test)
table(test$label, predictForest)
(412 + 416) / nrow(test)

# Try svm (gamma and cost determined from tuning).
set.seed(777)
genderSvm <- svm(label ~ ., data=train, gamma=0.21, cost=8)

# Accuracy: 0.96
predictSvm <- predict(genderSvm, train)
table(predictSvm, train$label)
(1076+1058)/nrow(train)

# Accuracy: 0.85
predictSvm <- predict(genderSvm, test)
table(predictSvm, test$label)
(423+386)/nrow(test)

# With no tuning, Accuracy: 0.84
#predictSvm <- predict(genderSvm, train)
#table(predictSvm, train$label)
#(954 + 902) / nrow(train)

# Accuracy: 0.81
#predictSvm <- predict(genderSvm, test)
#table(predictSvm, test$label)

# Try a tuned svm.
#set.seed(777)
#svmTune <- tune.svm(label ~ ., data=train, sampling='fix', gamma = 2^c(-8,-4,0,4), cost = 2^c(-8,-4,-2,0))
# The darker blue is the best values for a model.
#plot(svmTune)

# We can re-run the tuning with more specific values for gamma (epsilon) and cost.
#set.seed(777)
#svmTune <- tune.svm(label ~ ., data=train, sampling='fix', gamma = seq(0, 0.2, 0.01), cost = c(1, 2, 4))
#genderSvm <- svmTune$best.model
#plot(svmTune)

# Accuracy: 0.91
#predictSvm <- predict(genderSvm, train)
#table(predictSvm, train$label)
#(1023+1003)/nrow(train)

# Accuracy: 0.83
#predictSvm <- predict(genderSvm, test)
#table(predictSvm, test$label)
#(407+384)/nrow(test)

# Narrow down one more time.
#set.seed(777)
#svmTune <- tune.svm(label ~ ., data=train, sampling='fix', gamma = seq(0.2, 0.3, 0.01), cost = c(3, 5, 8))
#genderSvm <- svmTune$best.model
#plot(svmTune)

# Accuracy: 0.96
#predictSvm <- predict(genderSvm, train)
#table(predictSvm, train$label)
#(1076+1058)/nrow(train)

# Accuracy: 0.85
#predictSvm <- predict(genderSvm, test)
#table(predictSvm, test$label)
#(423+386)/nrow(test)

# One final tuning.
#set.seed(777)
#svmTune <- tune.svm(label ~ ., data=train, sampling='fix', gamma = seq(0.2, 0.25, 0.01), cost = seq(8, 12, 1))
#genderSvm <- svmTune$best.model
#plot(svmTune)

# Accuracy: 0.97
#predictSvm <- predict(genderSvm, train)
#table(predictSvm, train$label)
#(1079+1065)/nrow(train)

# Accuracy: 0.85 (one less, so very tiny overfitting)
#predictSvm <- predict(genderSvm, test)
#table(predictSvm, test$label)
#(422+386)/nrow(test)

# Try a boosted tree model.
# Accuracy: 0.91
#set.seed(777)
#genderBoosted <- train(label ~ ., data=train, method='gbm')
#predictBoosted <- predict(genderBoosted, newdata=train)
#confusionMatrix(predictBoosted, train$label)

# Accuracy: 0.84
#predictBoosted <- predict(genderBoosted, newdata=test)
#confusionMatrix(predictBoosted, test$label)

# Try XGBoost.
# Accuracy: 1
trainx <- sapply(train, as.numeric)
trainx[,21] <- trainx[,21] - 1
set.seed(777)
genderXG <- xgboost(data = trainx[,-21], label = trainx[,21], eta=0.2, nround = 500, subsample = 0.5, colsample_bytree = 0.5, objective = "binary:logistic")
results <- predict(genderXG, trainx)
table(trainx[,21], results >= 0.5)

# Accuracy: 0.87
testx <- sapply(test, as.numeric)
testx[,21] <- testx[,21] - 1
results <- predict(genderXG, testx)
table(testx[,21], results >= 0.5)
(414 + 413) / nrow(test)

# Try stacking models in an ensemble.
results1 <- predict(genderSvm, newdata=test)
results2 <- predict(genderTunedForest, newdata=test)
results3 <- factor(as.numeric(predict(genderXG, testx) >= 0.5), labels = c('male', 'female'))
combo <- data.frame(results1, results2, results3, y = test$label)

# Accuracy: 0.89
set.seed(777)
genderStacked <- tuneRF(combo[,-4], combo[,4], stepFactor=.5, doBest=TRUE)
predictStacked <- predict(genderStacked, newdata=combo)
table(predictStacked, test$label)

# Accuracy: 1
results1 <- predict(genderSvm, newdata=train)
results2 <- predict(genderTunedForest, newdata=train)
results3 <- factor(as.numeric(predict(genderXG, trainx) >= 0.5), labels = c('male', 'female'))
combo <- data.frame(results1, results2, results3)
predictStacked <- predict(genderStacked, newdata=combo)
table(predictStacked, train$label)

# trans <- processFolder('sanity')
# trans$label <- c(2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 2, 2, 2, 1, 1, 2)
# trans$label <- factor(trans$label, labels=c('male', 'female'))
# 
# tpred <- predict(genderTunedForest, newdata=trans)
# table(trans$label, tpred)
# 
# tpred <- predict(genderSvm, newdata=trans)
# table(trans$label, tpred)
# 
# trans[,1:3] <- NULL
# trans$peakf <- NULL
# testx <- sapply(trans, as.numeric)
# testx[,21] <- testx[,21] - 1
# results <- predict(genderXG, testx)
# table(testx[,21], results >= 0.5)
# 
# results1 <- predict(genderSvm, newdata=trans)
# results2 <- predict(genderTunedForest, newdata=trans)
# results3 <- factor(as.numeric(predict(genderXG, testx) >= 0.5), labels = c('male', 'female'))
# combo <- data.frame(results1, results2, results3)
# predictStacked <- predict(genderStacked, newdata=combo)
# table(predictStacked, trans$label)



# tpred <- predict(genderCART, newdata=trans)
# tpred.prob <- tpred[,2]
# table(trans$label, tpred.prob >= 0.5)

# trans <- processFolder('trans2')
# trans$label <- c(2, 2, 2, 1, 2)
# trans$label <- factor(trans$label, labels=c('male', 'female'))
# tpred <- predict(genderLog, newdata=trans, type='response')
# table(trans$label, tpred >= 0.5)

# tpred <- predict(genderForest, newdata=trans)
# table(trans$label, tpred)

# tpred <- predict(genderBoosted, newdata=trans)
# confusionMatrix(trans$label, tpred)

# tpred <- predict(genderCART, newdata=trans)
# tpred.prob <- tpred[,2]
# table(trans$label, tpred.prob >= 0.5)

# trans <- processFolder('trans4')
# trans$label <- c(2, 2, 2, 2, 1, 1, 1, 1)
# trans$label <- factor(trans$label, labels=c('male', 'female'))
# 
# tpred <- predict(genderLog, newdata=trans, type='response')
# table(trans$label, tpred >= 0.5)
# 
# tpred <- predict(genderTunedForest, newdata=trans, type='response')
# table(trans$label, tpred)
# 
# trans[,1:3] <- NULL
# trans$peakf <- NULL
# testx <- sapply(trans, as.numeric)
# testx[,21] <- testx[,21] - 1
# results <- predict(genderXG, testx)
# table(testx[,21], results >= 0.5)
