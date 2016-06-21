## Including the required R packages.
#packages <- c('shiny', 'shinyjs')
#if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
#  install.packages(setdiff(packages, rownames(installed.packages())))  
#}

library(shiny)
library(shinyjs)

shinyUI(fluidPage(
  conditionalPanel(condition='!output.json',
                   tags$head(tags$script(src = "script.js"),
                             tags$style(HTML(".shiny-output-error-validation { color: red; } .shiny-progress .progress { background-color: #ff00ff; }"))),
                   titlePanel('What is Your Voice Gender?'),
                   div(style='margin: 30px 0 0 0;'),
                   mainPanel(width = '100%',
                             useShinyjs(),
                             h4(id='main', 'Upload a .WAV file of your voice or enter a url from ', a(href='http://vocaroo.com', target='_blank', 'vocaroo.com'), 'or ', a(href='http://clyp.it', target='_blank', 'clyp.it'), ' to detect its gender.'),
                             div(style='margin: 20px 0 0 0;'),
                             
                             inputPanel(
                               div(id='uploadDiv', class='', style='height: 120px; border-right: 1px solid #ccc;',
                                   fileInput('file1', 'Choose WAV File', accept = c('audio/wav'), width = '100%')
                               ),
                               div(id='urlDiv', class='',
                                   strong('Url (vocaroo or clyp.it)'),
                                   textInput('url', NULL, width = '100%'),
                                   actionButton('btnUrl', 'Load Url', class='btn-primary', icon=icon('cloud'))
                               ),
                               div('Please be patient after uploading or clicking submit.')
                             ),
                             
                             div(style='margin: 20px 0 0 0;'),
                             div(id='result', style='font-size: 22px;', htmlOutput('content')),
                             div(style='margin: 20px 0 0 0;'),
                             
                             h4('Voice Tips and Tricks'),
                             p('- Pitch, combined with intonation (the rise and fall of the voice in speaking), are important factors in classifying male versus female.'),
                             p('- Male classified voices tend to be low and within a narrow range of pitch (ie., relatively monotone).'),
                             p('- Female classified voices tend to be higher in pitch and fluctuate frequency to a much greater degree.'),
                             p('- Female classified voices often rise in frequency at the end of a sentence, as if asking a question.'),
                             div(style='margin: 20px 0 0 0;'),
                             
                             h4('How does it work?'),
                             p('This application uses a method of artificial intelligence, called machine learning, to determine the gender of a voice.'),
                             p('The program was trained on a dataset of 3,168 voice samples, split between male and female voices. By analyzing the acoustic properties of the voices, the program is able to achieve 89% accuracy on the test set.'),
                             p('Interested in learning more? Read the complete ', a(href='http://primaryobjects.com/2016/06/20/gender-recognition-by-voice-and-speech-analysis/', target='_blank', 'article')),
                             p('Created by ', a(href='http://primaryobjects.com/kory-becker', target='_blank', 'Kory Becker'))
                   ))
))