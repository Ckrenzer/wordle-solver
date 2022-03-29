# Setup -----------------------------------------------------------------------
if(!require(shiny)) install.packages("shiny"); library(shiny)
if(!library(shinycssloaders, logical.return = TRUE)) install.packages("shinycssloaders")
if(!library(shinyjs, logical.return = TRUE)) install.packages("shinyjs")
source("solver/wordle-solver.R")


# UI --------------------------------------------------------------------------
ui <- fluidPage(
  # Initializing shinyjs
  useShinyjs(),
  titlePanel("Wordle Solver", windowTitle = "Wordle Solver"),
  
  
  # Inputs --------------------------------------------------------------------
  sidebarPanel(
    actionButton("reset", "Click here to start a new game"),
    
    # Chooses the input word
    textInput("guess",
              label = "Type your guess:",
              placeholder = "soree"),
    
    # Chooses the first letter's color
    radioButtons("color1",
                 label = h3("First Letter"),
                 choices = list("Grey" = "grey", "Yellow" = "yellow", "Green" = "green"), 
                 selected = 1),
    
    # Chooses the second letter's color
    radioButtons("color2",
                 label = h3("Second Letter"),
                 choices = list("Grey" = "grey", "Yellow" = "yellow", "Green" = "green"), 
                 selected = 1),
    
    # Chooses the third letter's color
    radioButtons("color3",
                 label = h3("Third Letter"),
                 choices = list("Grey" = "grey", "Yellow" = "yellow", "Green" = "green"), 
                 selected = 1),
    
    # Chooses the fourth letter's color
    radioButtons("color4",
                 label = h3("Fourth Letter"),
                 choices = list("Grey" = "grey", "Yellow" = "yellow", "Green" = "green"), 
                 selected = 1),
    
    # Chooses the fifth letter's color
    radioButtons("color5",
                 label = h3("Fifth Letter"),
                 choices = list("Grey" = "grey", "Yellow" = "yellow", "Green" = "green"), 
                 selected = 1),
    
    actionButton("update", "Click here once you've selected a word and input the colors")
    
  ),# End sidebarPanel()
  
  
  # Output --------------------------------------------------------------------
  mainPanel(
    # Prints the best guess to the console
    verbatimTextOutput(outputId = "guess"),
    
    # Plots the information distribution for the remaining
    # words of the current guess
    plotOutput("word_plot") %>% withSpinner(color = "#0dc5c1"),
    
    # Prints the remaining choices to the console
    strong("The Top 10 Choices:"),
    tableOutput("remaining_words")
  )
)


# Server ----------------------------------------------------------------------
server <- function(input, output) {
  
  
  # Updating values based on clicking of an action button ---------------------
  # Supplies default values to 'df' and 'terms'
  df <- reactiveValues(data = scores)
  terms <- reactiveValues(data = words)
  best_guess <- reactiveValues(data = "soree")
  
  # Resets 'df' and 'terms'
  observeEvent(input$reset, {
    df$data <- scores
    terms$data <- words
  })
  
  # Updates the user's combo and filters down to the remaining words
  observeEvent(input$update, {
    # Filter down to the remaining words
    terms$data <- guess_filter(string = input$guess,
                               current_combo = combo(),
                               word_list = terms$data)
    df$data <- dplyr::filter(df$data, word %in% terms$data)
    best_guess$data <-  df$data %>%  
      dplyr::filter(weighted_score == min(weighted_score)) %>% 
      dplyr::pull(word)
  })
  
  
  # Updating values -----------------------------------------------------------
  # Creates the combo from the user's input
  combo <- reactive({c(input$color1, input$color2, input$color3, input$color4, input$color5)})
  
  # Creates the plot containing the proportion remaining for a given pattern
  proportion_plot <- reactive({
    # Calculates the proportion of remaining words for the current word
    remaining <- double(length(color_combos))
    for(i in seq_along(color_combos)){
      remaining[i] <- length(guess_filter(best_guess$data, color_combos[[i]]))
    }
    proportion_of_words_remaining <- remaining / num_words
    
    ggplot(mapping = aes(x = reorder(seq_along(color_combos),
                                     -proportion_of_words_remaining),
                         y = proportion_of_words_remaining,
                         fill = -proportion_of_words_remaining)) +
      geom_col(show.legend = FALSE) +
      ggtitle("Lower values are better--you want as few words remaining as possible!",
              subtitle = paste0("Graph for: ", best_guess$data)) +
      xlab("Match Pattern Index (243 Possible Color Patterns)") +
      ylab("Proportion of Words Remaining for All Possible Color Combos") +
      theme(axis.text.x = element_blank())
  })
  
  
  # Displaying Output ---------------------------------------------------------
  # The recommended word
  output$guess <- renderPrint({cat("The best word to use is:", best_guess$data)})
  # The proportion plot
  output$word_plot <- renderPlot({proportion_plot()})
  # The top 10 remaining words and associated scores
  output$remaining_words <- renderTable({
    df$data %>% 
      select(word, score = weighted_score) %>%
      mutate(score = 1 / score) %>% 
      arrange(-score) %>% 
      slice(1:10)
  })
}

shinyApp(ui = ui, server = server)
