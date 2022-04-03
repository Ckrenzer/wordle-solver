# Packages --------------------------------------------------------------------
if(!require(readr)) install.packages("readr"); library(readr)
if(!require(stringr)) install.packages("stringr"); library(stringr)
if(!require(ggplot2)) install.packages("ggplot2"); library(ggplot2)
if(!require(dplyr)) install.packages("dplyr"); library(dplyr)

# We need to pick up the performance some:
if(!require(JuliaCall)) install.packages("JuliaCall"); library(JuliaCall)
if(!require(data.table)) install.packages("data.table"); library(data.table)
if(!require(fastmatch)) install.packages("fastmatch"); library(fastmatch)
`%in%` <- `%fin%`


# Import Data -----------------------------------------------------------------
# Reading from URLs makes this much less of a headache...
scores <- fread("data/processed/opening_word_scores.csv")
#scores <- fread("https://raw.githubusercontent.com/Ckrenzer/wordle-solver/main/data/processed/opening_word_scores.csv")
words <- scores$word
num_words <- length(words)

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
  # Get the regex identifying remaining words
  rgx <- build_regex(string, current_combo)
  # Filter down to the remaining possible words
  word_list[grepl(rgx, word_list)]
}

# Creates a regular expression to filter the word list
build_regex <- function(str, combo){
  # Converting to lowercase ensures valid input
  # Each letter is an element of an array  
  str <- str_split(str_to_lower(str), "")[[1]]
  
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

# Calculates the score for subsequent guesses (the scores
# in the original file are only valid for the first guess)
#
# Column 4 in `scores` is the weighted score
#
#
# YOUR APPROACH IS TOTALLY WRONG! R SHOULD ONLY BE DOING QUERIES ON
# DATA SETS. JULIA SHOULD BE DOING THE HEAVY LIFTING!
#
# TRY TO HAVE JULIA BUILD OUT THE DICTIONARY ALL THE WAY UNTIL YOU'VE
# REACHED THE END OF THE POSSIBLE OUTCOMES.
recalculate_scores <- function(df = word_df[word %in% guess_filter(string = best_guess, current_combo = combo, word_list = word)],
                               current_combo){
  terms <- df$word
  word_freq <- df$count
  word_freq_sum <- sum(word_freq)
  word_weights <- structure(double(length(terms)), names = terms)
  
  # This loop updates the weighted score
  for(i in seq_along(word_weights)){
    message(i, " of ", 12947)
    for(term in terms){
    # Calculates the weighted score for each term
      word_weights[term] <- sum(word_freq[terms %in% guess_filter(term, current_combo, terms)])
    }
    word_freq_sum <- sum(word_freq)
    # Updating score
    set(df, i = i, j = 4, value = weighted.mean(word_weights / word_freq_sum, word_weights))
  }
  df
}


# Play ------------------------------------------------------------------------
# This function allows the game to be solved at the R console
play <- function(df = scores, terms = words){
  best_guess <- word_df[weighted_score == min(weighted_score)]$word
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
    # Subsequent calculations are horrifically slow
    # recalculate_scores changes `word_df` by reference
    recalculate_scores(df = word_df, current_combo = combo)
    play(df = word_df,
         terms = word_df$word,
         use_weighted_scores = using_weighted_score)
  }
}

