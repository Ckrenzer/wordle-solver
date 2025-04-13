# A simple UI for the solver
library(shiny)
library(shinyjs)
source("r/play.R")
options(browser = "brave")
is_running_on_server <- local({
    shiny_port <- Sys.getenv("SHINY_PORT")
    !(is.character(shiny_port) && shiny_port == "")
})
best_opening_guess <- names(scores[scores == max(scores)][1L])
color_dropdown <- list("Green" = "green", "Yellow" = "yellow", "Grey" = "grey")
color_inputs <- sprintf("color%d", 1L:5L)
default_color_prompt_string <- "[choose color]"
insert_css_for_color_combo <- function(clr){
    enhanced <- character(length(clr))
    found <- clr %in% names(colors)
    enhanced[found] <- sprintf("<span style='color:%s'>%s</span>", clr[found], clr[found])
    enhanced[!found] <- sprintf("<span style='color:black'>%s</span>", clr[!found])
    enhanced[clr == "yellow"] <- "<span style='color:#FFB90F'>yellow</span>"
    enhanced
}
# can revisit if I ever use a more powerful server
calculate_scores_fn <- `if`(is_running_on_server, calculate_scores_series, calculate_scores)

ui <- fluidPage(
  useShinyjs(),
  titlePanel("Wordle Assistant", windowTitle = "Wordle Assistant"),
  sidebarPanel(
    actionButton("new_game", label = "Click here to start a new game"),
    textInput("guess",       label = "Type your guess:",  placeholder = "audio"),
    actionButton("go_back",  label = "Go to previous letter in color combo"),
    radioButtons("color1",   label = h3("First Letter"),  choices = color_dropdown, selected = character(0L), inline = TRUE),
    radioButtons("color2",   label = h3("Second Letter"), choices = color_dropdown, selected = character(0L), inline = TRUE),
    radioButtons("color3",   label = h3("Third Letter"),  choices = color_dropdown, selected = character(0L), inline = TRUE),
    radioButtons("color4",   label = h3("Fourth Letter"), choices = color_dropdown, selected = character(0L), inline = TRUE),
    radioButtons("color5",   label = h3("Fifth Letter"),  choices = color_dropdown, selected = character(0L), inline = TRUE),
    uiOutput("color_combo"),
    actionButton("update",   label = "Click here once you've selected a word and input the colors")
  ),
  mainPanel(
    verbatimTextOutput(outputId = "next_best_guess"),
    strong("Top 10 Choices:"), tableOutput("top_choices_table")
  )
)

server <- function(input, output, session) {
  session$onSessionEnded(function() stopApp())
  # supply default values
  shown_input <- reactiveValues(current_selection = "color1")
  selected_combo <- reactiveValues(color1 = NULL, color2 = NULL, color3 = NULL, color4 = NULL, color5 = NULL)
  remaining_letters <- reactiveValues(data =                abc)
  remaining_words   <- reactiveValues(data =              words)
  new_scores        <- reactiveValues(data =             scores)
  best_guess        <- reactiveValues(data = best_opening_guess)
  observeEvent(input$new_game, { # reset all values
    shinyjs::reset("guess")
    shinyjs::enable("go_back")
    shinyjs::enable("update")
    for(current_color in color_inputs){
        shinyjs::enable(current_color)
        updateRadioButtons(session = session, inputId = current_color, selected = character(0L))
        selected_combo[[current_color]] <- NULL
    }
    shinyjs::hide(shown_input$current_selection)
    shinyjs::show("color1")
    shown_input$current_selection <- "color1"
    remaining_letters$data <- abc
    remaining_words$data   <- words
    new_scores$data        <- scores
    best_guess$data        <- best_opening_guess
  })
  # manage radio button visibility (only one button visible at a time)
  observeEvent(input$go_back, { # choose color for previous letter
      val <- shown_input$current_selection
      selected_combo[[val]] <- NULL
      updateRadioButtons(session = session, inputId = val, selected = character(0L))
      valnum <- as.integer(substr(val, start = nchar(val), stop = nchar(val)))
      if(valnum > 1L){
          prev_val <- paste0("color", valnum - 1L)
          updateRadioButtons(session = session, inputId = prev_val, selected = character(0L))
          shinyjs::show(prev_val)
          shinyjs::hide(val)
          shown_input$current_selection <- prev_val
          selected_combo[[prev_val]] <- default_color_prompt_string
      }
  })
  observeEvent(input$color1, {
    selected_combo$color1 <- input$color1
    shinyjs::hide(shown_input$current_selection)
    shown_input$current_selection <- "color2"
    shinyjs::show(shown_input$current_selection)
  })
  observeEvent(input$color2, {
    selected_combo$color2 <- input$color2
    shinyjs::hide(shown_input$current_selection)
    shown_input$current_selection <- "color3"
    shinyjs::show(shown_input$current_selection)
  })
  observeEvent(input$color3, {
    selected_combo$color3 <- input$color3
    shinyjs::hide(shown_input$current_selection)
    shown_input$current_selection <- "color4"
    shinyjs::show(shown_input$current_selection)
  })
  observeEvent(input$color4, {
    selected_combo$color4 <- input$color4
    shinyjs::hide(shown_input$current_selection)
    shown_input$current_selection <- "color5"
    shinyjs::show(shown_input$current_selection)
  })
  observeEvent(input$color5, {
    selected_combo$color5 <- input$color5
  })
  # recalculate scores using new guess and the combo that wordle gave back for that guess
  observeEvent(input$update, {
    {# when a repeating letter is both grey and non-grey, set the grey ones to yellow,
     # consistent with the implementation liberties discussed in r/play.R
        combo <- c(selected_combo$color1, selected_combo$color2, selected_combo$color3, selected_combo$color4, selected_combo$color5)
        guess <- tolower(input$guess)
        split_guess <- split_words[[guess]]
        repeating_letters <- uniq(split_guess[duplicated(split_guess)])
        letters_with_impossible_pattern <- vapply(repeating_letters, function(lttr){
                                                lttr_colors <- uniq(combo[split_guess == lttr])
                                                sum(lttr_colors == "grey") != length(lttr_colors)
                                           }, logical(1L), USE.NAMES = TRUE)
        letters_with_impossible_pattern <- names(letters_with_impossible_pattern[letters_with_impossible_pattern])
        combo[split_guess %in% letters_with_impossible_pattern & combo == "grey"] <- "yellow"
    }
    tryCatch({
      updates <- update_scores(guess = guess,
                               split_words = split_words,
                               combo = colors[combo],
                               remaining_words = remaining_words$data,
                               remaining_letters = remaining_letters$data,
                               color_combos = color_combos,
                               colors = colors,
                               calculate_scores_fn = calculate_scores_fn)
      remaining_letters$data <- updates$remaining_letters
      remaining_words$data   <- updates$remaining_words
      new_scores$data        <- updates$new_scores
      best_guess$data        <- updates$best_guess
      # resetting the radio buttons back to the first letter is convenient
      for(current_color in color_inputs){
          updateRadioButtons(session = session, inputId = current_color, selected = character(0L))
          selected_combo[[current_color]] <- NULL
      }
      shinyjs::hide(shown_input$current_selection)
      shinyjs::show("color1")
      shown_input$current_selection <- "color1"
    },
    # out of words/letters/something has gone horribly wrong and you need to restart
    # lock everything up to force the user to click restart!
    error = function(cnd){
        remaining_letters$data <- abc
        remaining_words$data   <- head(words, 0L)
        new_scores$data        <- head(scores, 0L)
        best_guess$data        <- "<<OUT OF GUESSES! RESTART GAME TO TRY AGAIN!>>"
        shinyjs::disable("go_back")
        shinyjs::disable("update")
        for(current_color in color_inputs){
            shinyjs::disable(current_color)
        }
    })
  })
  # print currently selected colors
  output$color_combo <- renderUI({
      # ensure the color in the combo that is being selected tells the user to choose a color (except on the last one)
      selections <- c(selected_combo$color1, selected_combo$color2, selected_combo$color3, selected_combo$color4, selected_combo$color5)
      selected_colors <- names(colors[selections])
      selected_colors[is.na(selected_colors)] <- default_color_prompt_string
      val <- shown_input$current_selection
      if(is.null(selected_combo[[val]])){
          valnum <- as.integer(substr(val, nchar(val), nchar(val)))
          selected_colors[valnum] <- default_color_prompt_string
      }
      combo_text <- insert_css_for_color_combo(selected_colors) |>
          paste(collapse = ", ") |>
          sprintf(fmt = "Color combo:<br>%s")
      HTML(combo_text)
  })
  # print word info
  output$next_best_guess <- renderPrint({cat("The best word to use is:", best_guess$data)})
  output$top_choices_table <- renderTable({
      top_words <- head(sort(new_scores$data, decreasing = TRUE), 10L)
      data.frame(word = names(top_words),
                 score = top_words,
                 `# of Uses in English` = remaining_words$data[names(top_words)],
                 check.names = FALSE)
  })
  # hide these prompts upon opening the app
  shinyjs::hide("color2")
  shinyjs::hide("color3")
  shinyjs::hide("color4")
  shinyjs::hide("color5")
}

if(!is_running_on_server){
    app <- shinyApp(ui = ui, server = server)
    runApp(app, launch.browser = TRUE)
} else {
    shinyApp(ui = ui, server = server)
}
