## Including the required R packages.
#packages <- c('shiny', 'shinyjs')
#if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
#  install.packages(setdiff(packages, rownames(installed.packages())))  
#}

library(shiny)
library(shinyjs)

shinyUI(fluidPage(
  conditionalPanel(condition='!output.json',
  tags$head(tags$script(src = "script.js")),
  titlePanel('What is Your Voice Gender?'),
  mainPanel(width = '100%',
            useShinyjs(),
            h4(id='main', 'Upload a .WAV file of your voice or enter a url from vocaroo.com to detect its gender.'),
            inputPanel(
              div(id='uploadDiv', class='',
                fileInput('file1', 'Choose WAV File', accept = c('audio/wav'), width = '100%')
              ),
              div(id='urlDiv', class='',
                  strong('Enter a url from vocaroo.com'),
                textInput('url', NULL, width = '100%'),
                actionButton('btnUrl', 'Load Vocaroo')
              ),
              div('Please be patient after uploading or clicking submit.')
            ),
            div(id='result1', style='font-size: 22px;', htmlOutput('content1')),
            div(id='result2', style='font-size: 22px;', htmlOutput('content2')),
            h4('How does it work?'),
            p('This application uses machine learning (artificial intelligence) to determine the gender of a voice. The program was trained on a dataset of about 1800 voice samples, split between male and female voices. By analyzing the acoustic properties of the voices, the program is able to achieve 93% accuracy on the training set and 86% accuracy on the test set. A detailed article on the technology and data design is coming soon.'),
            p('Created by ', a(href='http://primaryobjects.com/kory-becker', target='_blank', 'Kory Becker'))
  ))
))