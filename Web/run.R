# Stub for running within VSCode debugger.
isDebugMode <- Sys.getenv("VS_DEBUG") == "1"
if (isDebugMode) {
    print("Running in VSCode debug mode.")
    library(shiny)

    runApp(
    appDir = getwd(),
    port = getOption("shiny.port"),
    launch.browser = getOption("shiny.launch.browser", interactive()),
    host = getOption("shiny.host", "127.0.0.1"),
    workerId = "",
    quiet = FALSE,
    display.mode = c("auto", "normal", "showcase"),
    test.mode = getOption("shiny.testmode", FALSE)
    )
} else {
    print("Running in web server mode.")
}