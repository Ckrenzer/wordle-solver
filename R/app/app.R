# Setup -----------------------------------------------------------------------
if(!require(shiny)) install.packages("shiny"); library(shiny)
#source("R/wordle-solver.R")


# UI --------------------------------------------------------------------------
ui <- fluidPage(
    # Application title
    titlePanel("Wordle Solver", windowTitle = "Wordle Solver"),
        # Play the Game!
        mainPanel(
          radioButtons("color1", label = h3("First Letter"),
                       choices = list("Grey" = "grey", "Yellow" = "yellow", "Green" = "green"), 
                       selected = 1),
          fluidRow(column(3, verbatimTextOutput("match1"))),
           #selectInput("color2", choices = colors),
           #selectInput("color3", choices = colors),
           #selectInput("color4", choices = colors),
           #selectInput("color5", choices = colors),
           
           #textOutput("combo")
        )
)


# Server ----------------------------------------------------------------------
server <- function(input, output) {

    output$match1 <- renderPrint({ input$color1 })
}

# Run the application 
shinyApp(ui = ui, server = server)
