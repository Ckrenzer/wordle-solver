# Packages --------------------------------------------------------------------
if(!require(readr)) install.packages("readr")
if(!require(stringr)) install.packages("stringr"); library(stringr)
if(!require(ggplot2)) install.packages("ggplot2"); library(ggplot2)
if(!require(dplyr)) install.packages("dplyr"); library(dplyr)
if(!require(rlang)) install.packages("rlang"); library(rlang)


# Import Data -----------------------------------------------------------------
words <- readr::read_lines("data/raw/wordle_list.txt")
num_words <- length(words)
scores <- readr::read_csv("data/processed/opening_word_scores.csv")

# Combinations
# All potential match patterns that could be found. There are 243 of them
# (3^5)--an option for each color and five letters in the word.
colors <- c("green", "yellow", "grey")
color_combos <- vector("list", 3^5)
index <- 1
for(i in seq_along(colors)){
  for(j in seq_along(colors)){
    for(k in seq_along(colors)){
      for(l in seq_along(colors)){
        for(m in seq_along(colors)){
          color_combos[[index]] <- c(colors[i], colors[j], colors[k], colors[l], colors[m])
          index <- index + 1
        }
      }
    }
  }
}
rm(i, j, k, l, m, index)


# Wordle Functions ------------------------------------------------------------
# Takes the user's guess and filters down to the remaining possible words
guess_filter <- function(string, current_combo, word_list = words){
  string <- str_to_lower(string)
  stopifnot(length(string) == 1,
            str_length(string) == 5)
  
  # Get the regex identifying remaining words
  rgx <- build_regex(string, current_combo)
  # Filter down to the remaining possible words
  str_subset(word_list, rgx)
}

# Creates a regular expression to filter the word list
build_regex <- function(str, combo){
  # Each letter is an element of an array  
  str <- str_split(str, "")[[1]]
  
  # Grey letters are removed from the list entirely.
  grey_letters <- str[combo == "grey"]
  non_grey_letters <- letters[!letters %in% grey_letters]
  
  # The letters to use in the regex
  possible_letters <- vector("list", 5)
  
  # Green letters letters are set.
  for(i in which(combo == "green")) possible_letters[[i]] <- str[i]
  # Grey letters are set to the remaining letters
  for(i in which(combo == "grey")) possible_letters[[i]] <- non_grey_letters
  # Yellow letters are removed from the index in which they appear.
  for(i in which(combo == "yellow")) possible_letters[[i]] <- str_subset(non_grey_letters, str[i], negate = TRUE)
  
  # Collapse the vectors of letters.
  collapsed_letters <- lapply(possible_letters, str_c, collapse = "")
  
  # Collapse the list into a regex.
  str_c("[", collapsed_letters, "]", collapse = "")
}


# Play ------------------------------------------------------------------------
# This function allows the game to be played at the R console
play_console <- function(df = scores, terms = words, use_weighted_scores = TRUE){
  score_col <- if(use_weighted_scores) expr(weighted_score) else expr(unweighted_score)
  using_weighted_score <- use_weighted_scores
  
  word_df <- dplyr::filter(df, word %in% terms)
  best_guess <- word_df %>%  
    dplyr::filter(!!score_col == min(!!score_col)) %>% 
    dplyr::pull(word)
  
  message("Your best bet: ", best_guess)
  message("Enter your color combo (Ex. green green grey yellow green), then hit Enter: ")
  combo <- scan(what = "character", n = 5, quiet = TRUE)
  while(!any(as.logical(lapply(color_combos, function(x) all(combo == x))))){
    message("Invalid color combination. Maybe you misspelled a color? Type the combo again:")
    combo <- scan(what = "character", n = 5)
  }
  
  
  if(all(combo == "green")){
    return("You win!")
  } else {
    play_console(df = word_df,
                 terms = guess_filter(string = best_guess, current_combo = combo, word_list = word_df$word),
                 use_weighted_scores = using_weighted_score)
  }
}
