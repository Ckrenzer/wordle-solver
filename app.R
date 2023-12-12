# This solution requires a Julia installation. Built under Julia 1.7.1.

# Packages --------------------------------------------------------------------
if(!require(shiny)) install.packages("shiny"); library(shiny)
if(!require(shinycssloaders)) install.packages("shinycssloaders"); library(shinycssloaders)
if(!require(shinyjs)) install.packages("shinyjs"); library(shinyjs)
if(!require(dplyr)) install.packages("dplyr"); library(dplyr)
if(!require(ggplot2)) install.packages("ggplot2"); library(ggplot2)
if(!require(stringr)) install.packages("stringr"); library(stringr)
if(!require(JuliaCall)) install.packages("JuliaCall"); library(JuliaCall)


# Setup -----------------------------------------------------------------------
julia_setup()
# Loads all necessary Julia packages, functions, objects, etc., for the solver.
julia_source("jl/setup.jl")

# Loads in required objects for a new game.
new_game <- function(){
  # Reset the scores data frame to the original opening scores
  # Reset the letter matrix, abc, to the unedited original
  julia_eval('scores = sort!(CSV.read("data/processed/opening_word_scores.csv", DataFrame), :weighted_prop)')
  julia_eval("abc = copy(abc_full)")
}

# Update the combo
update_combo <- function(new_combo){
  julia_assign(x = "combo", value = new_combo)
  julia_command("combo = Int8.(combo)")
}

# Accept the next guess from the user
update_scores <- function(guess){
  julia_assign(x = "guess", value = guess)
  julia_eval("scores = update_scores(guess, combo, scores, abc)")
}

# Load the data into Julia and R at the start of the session
new_game()
scores <- julia_eval("scores")
# A dictionary that assigns the colors numeric values based on the input.
# Necessary because radioButtons() requires all values to be strings:
cv <- structure(.Data = c(0, 1, 2), names = c("green", "yellow", "grey"))


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
              placeholder = "soare"),
    
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
    verbatimTextOutput(outputId = "next_best_guess"),
    
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
  
  
  # Updating values based on the clicking of an action button -----------------
  # Supplies default values to 'df' and 'terms'
  df <- reactiveValues(data = julia_eval("scores"))
  terms <- reactiveValues(data = julia_eval("scores.word"))
  best_guess <- reactiveValues(data = "soare")
  
  # Resets 'df' and 'terms' in both Julia and R
  observeEvent(input$reset, {
    new_game()
    df$data <- julia_eval("scores")
    terms$data <- julia_eval("scores.word")
  })
  
  # Updates the user's combo, recalculates scores with remaining words
  observeEvent(input$update, {
    # Updates the color combo in Julia
    update_combo(combo())
    # Recalculate scores
    df$data <- update_scores(str_to_lower(input$guess))
    terms$data <- df$data[["word"]]
    # The words are sorted in Julia with the
    # best guess at the first position
    best_guess$data <- terms$data[[1]]
  })
  
  
  # Updating values -----------------------------------------------------------
  # Creates the combo from the user's input
  combo <- reactive({
    cv[c(input$color1, input$color2, input$color3, input$color4, input$color5)]
  })
  
  # Creates the plot containing the proportion remaining for a given pattern
  proportion_plot <- reactive({
    # Calculates the proportion of remaining words for the input word
    remaining <- double(julia_eval("length(color_combos[:, 1])"))
    num_words <- sum(scores[["weighted_prop"]])
      for(i in julia_eval("seq_along(color_combos[:, 1])")){
        julia_assign(x = "i", value = i)
        remaining_words <- julia_eval("guess_filter(scores.word[1], color_combos[i, :], words)")
        remaining[i] <- sum(scores[scores$word %in% remaining_words, "weighted_prop"])
      }
      proportion_of_words_remaining <- remaining / num_words
      
    # Plots the weighted proportion of words remaining for the input word
    ggplot(mapping = aes(x = reorder(seq_along(remaining),
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
  # Display if the checks pass.
  # The recommended word
  output$next_best_guess <- renderPrint({cat("The best word to use is:", best_guess$data)})
  # The proportion plot
  output$word_plot <- renderPlot({proportion_plot()})
  # The top 10 remaining words and associated scores
  output$remaining_words <- renderTable({
    df$data %>% 
      select(word, score = weighted_prop, `# of Uses in English` = count) %>%
      mutate(score = 1 / score) %>% 
      arrange(-score) %>% 
      slice(1:10)
  })
}


shinyApp(ui = ui, server = server)
