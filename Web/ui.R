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
                   			 tags$script(src = "google-analytics.js"),
                         tags$style(HTML("a { font-weight: bold; } .shiny-output-error-validation { color: red; } .shiny-progress .progress { background-color: #ff00ff; } .fa-info { margin: 0 0 0 10px; cursor: pointer; font-size: 15px; color: #808080; } .fa-headphones { margin: 0 5px 0 2px; } .average-pitch { font-size: 18px; } .detail-summary { font-size: 16px; } .detail-summary .detail-header { font-size: 18px; margin: 0 0 10px 0; } .detail-summary span { font-weight: bold; } #summary1 { margin-top: 10px; } #summary2 { margin-bottom: 80px; } .female { color: #ff00ff; } .male { color: #0066ff; } .error { color: #ff0000; } .btn-primary.buy { margin: 0 0 10px 10px; border-radius: 4px; padding: 8px 12px 8px 12px; border: 0; -webkit-transition: all .25s ease-in-out; } .btn-primary.buy:hover { background-color: #e0e0e0; color: #333; } .intro-text { font-weight: bolder; font-size: 16px; color: deeppink; } .intro-text.register { color: #00aa00; } #lstLicense { margin-top: 3px; } #register-div { border: 1px solid #c0c0c0; padding: 10px 15px 10px 15px; max-width: 422px; background-color: aliceblue; } .fa-info-circle { cursor: pointer; -webkit-transition: all .1s ease-in-out; } .fa-info-circle:hover { color: #333; }"))
                   ),
                   titlePanel('What is Your Voice Gender?'),
   mainPanel(width = '100%',
   useShinyjs(),
   
   tags$form(action="https://www.paypal.com/cgi-bin/webscr", method="post", name="m_OrderForm", id="m_OrderForm",
     tags$input(type="hidden", name="business", value="kbecker@primaryobjects.com"),
     tags$input(type="hidden", name="item_name", value="Voice Gender App"),
     tags$input(type="hidden", name="item_number", value="VOICEGENDERAPP"),
     tags$input(type="hidden", name="amount", value="19.95"),
     tags$input(type="hidden", name="no_shipping", value="1"),
     tags$input(type="hidden", name="return", value="https://primaryobjects.shinyapps.io/voice/?action=register"),
     tags$input(type="hidden", name="currency_code", value="USD"),
     tags$input(type="hidden", name="no_note", value="1"),
     tags$input(type="hidden", name="cancel_return", value="https://primaryobjects.shinyapps.io/voice/?action=cancel"),
     tags$input(type="hidden", name="cmd", value="_xclick")
   ),

   div(id="register-div",
     div(
       div(style="float: left;",
         p(class="intro-text",
           "Register the Voice Gender App today!"
         )
       ),
       div(id="info",
         tags$i(class="fa fa-info-circle", style="float: left; margin: 2px 0 0 6px;", "data-toggle"="tooltip", "data-placement"="bottom", title="This app uses a method of artificial intelligence, called machine learning, to determine the gender of a voice. Registered users of the Voice Gender App receive an app license, priority email support, and priority suggestions for new features.")
       )
     ),
     div(style="clear: both;"),
     
     div(id="license-div",
       div(style="float: left",
         tags$select(id="lstLicense", class="form-control",
           tags$option(value="Starter", "Starter License $9.95"),
           tags$option(value="Personal", selected="true", "Personal License $19.95"),
           tags$option(value="Professional", "Professional License $39.95"),
           tags$option(value="Gold", "Gold License $99.95")
         )
       ),
       div(
         a(href="#", class="btn btn-primary btn-lg submit buy",
           tags$i(class="fa fa-unlock-alt"),
           "Buy Now"
         )
       )
     )
   ),
     
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
   
   conditionalPanel(condition='output.content != null && output.content.indexOf("Please enter") == -1',
     tabsetPanel(id='graphs',
       tabPanel('Frequency Graph', plotOutput("graph1", width=1000, height=500)),
       tabPanel('Spectrogram', plotOutput("graph2", width=1000, height=500)),
       tabPanel('Details', div(tableOutput('summary1'), tableOutput('summary2')))
     ),
     div(style='margin: 20px 0 0 0;')
   ),
  
   h4('Voice Tips and Tricks'),
   p('- Pitch, combined with intonation (the rise and fall of the voice in speaking), are important factors in classifying male versus female.'),
   p('- Male classified voices tend to be low and within a narrow range of pitch (ie., relatively monotone).'),
   p('- Female classified voices tend to be higher in pitch and fluctuate frequency to a much greater degree.'),
   p('- Female classified voices often rise in frequency at the end of a sentence, as if asking a question.'),
   div(style='margin: 20px 0 0 0;'),
   
   h4('How does it work?'),
   p('This application uses a method of artificial intelligence, called machine learning, to determine the gender of a voice.'),
   p('The program was trained on a dataset of 3,168 voice samples, split between male and female voices. By analyzing the acoustic properties of the voices, the program is able to achieve 89% accuracy on the test set.'),
   p('Interested in learning more? Read the complete ', a(href='http://www.primaryobjects.com/2016/06/22/identifying-the-gender-of-a-voice-using-machine-learning/', target='_blank', 'article')),
   p('Created by ', a(href='http://www.primaryobjects.com/kory-becker', target='_blank', 'Kory Becker'), br('7/28/2016'),
   span(style='font-style: italic;', 'Updated 10/8/2017'))
  ))
))