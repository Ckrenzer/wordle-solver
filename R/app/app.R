# Setup -----------------------------------------------------------------------
if(!require(shiny)) install.packages("shiny"); library(shiny)
if(!library(shinycssloaders, logical.return = TRUE)) install.packages("shinycssloaders")
if(!library(shinyjs, logical.return = TRUE)) install.packages("shinyjs")
#source("R/wordle-solver.R")

# DEFAULT VALUES ARE SUPPLIED FROM THE SOURCE() CALL

# Starting Page ---------------------------------------------------------------
# The unweighted proportion of remaining words
remaining <- double(length(color_combos))
for(i in seq_along(color_combos)){
  remaining[i] <- length(guess_filter("soree", color_combos[[i]]))
}
proportion_of_words_remaining <- remaining / num_words
proportion_plot <- ggplot(mapping = aes(x = reorder(seq_along(color_combos), -proportion_of_words_remaining), y = proportion_of_words_remaining)) +
  geom_col() +
  ggtitle("Lower values are better--you want as few words remaining as possible!") +
  xlab("Match Pattern Index (See 'Color 'Comobs' Tab)") +
  ylab("Proportion of Words Remaining") +
  theme(axis.text.x = element_text(size = 5.8, angle = 90))


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
              label = "Type your guess ('soree' is the best opening word).",
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
    tableOutput("remaining_words")
  )
)


# Server ----------------------------------------------------------------------
server <- function(input, output) {
  
  # Relaods the full data set
  observeEvent(input$reset, {
    scores <- readr::read_csv("data/processed/opening_word_scores.csv")
    words <- scores$word
  })
  
  # Updates the user's combo and filters down to the remaining words
  observeEvent(input$update, {
    combo <- c(input$color1, input$color2, input$color3, input$color4, input$color5)
    
    # Filter down to the remaining words
    words <- guess_filter(string = input$guess,
                          current_combo = combo,
                          word_list = words)
    scores <- dplyr::filter(scores, word %in% words)
    
    # The word that narrows down possibilities as much as possible
    best_guess <- scores %>%  
      dplyr::filter(weighted_score == min(weighted_score)) %>% 
      dplyr::pull(word)
  })
  
  
  
  # The actual output
  
  
}

shinyApp(ui = ui, server = server)
