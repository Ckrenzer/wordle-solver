# Notes -----------------------------------------------------------------------
#
# This implementation requires you to have access to a five letter word. This
# is why 'answer' is a word randomly chosen from the list of accepted answers.
#
# Need a good opening word. The best opening word should always be the same.
# Perhaps you should weight words based on the frequency of use (or the
# inverse, rather), as was done in the video?
#
# Will you need to record the location of colors? You already filter down the
# list of possible words, but you should also keep the colors to limit the
# characters allowed in subsequent guesses. But will choosing the word with
# the next highest value resolve this problem?
#
# Should you make a function that takes the inputs from the opening guess?
#
# Should you make a bot that inputs your guesses into the game online?
#
# It seems as if you have to work based on the results of your opening guess.
# The random word thing may not be the best approach to this...?
#
#
#
#
#
#
# Find the best opening word.
#
# Find proportion of words remaining for each word.
#
# # # # # If you were to choose a particular word in this list, what words would remain
# # # # # as possible solutions? Find this proportion for each word.
#
# # # # # Find probability of each pattern occurring. You shouldn't be so interested in the words themselves.
#
# After supplying the first guess, work within the remaining possible answers
# to determine the next best guess.
#
#
#
#
# You can only measure the results for one color pattern at a time.


# Packages --------------------------------------------------------------------
if(!require(readr)) install.packages("readr")
if(!require(stringr)) install.packages("stringr"); library(stringr)
if(!require(ggplot2)) install.packages("ggplot2"); library(ggplot2)
if(!require(dplyr)) install.packages("dplyr"); library(dplyr)


# Import Data -----------------------------------------------------------------
words <- readr::read_lines("datasets/wordle_list.txt")
num_words <- length(words)

# If I want to play a game with a random word, this is the way I'll pick one
set.seed(2022)
word <- sample(words, size = 1)


# Additional Data -------------------------------------------------------------
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
rm(i, j, k, l, m, index, colors)


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
# test for build_regex()
### build_regex("hello", combo = c("green", "grey", "green", "green", "yellow"))













# Trials ----------------------------------------------------------------------
# Remaining possible words with the current pattern. This will
# become our next 'word_list' parameter for a second call.
guess_filter(string = "while", current_combo = c("grey", "yellow", "yellow", "green", "yellow"))









# Misc ------------------------------------------------------------------------

# This calculates the number of possible words based
# on the input pattern for one input word.
#
# This may be computationally expensive. I suggest making a function
# to allow the user to compute these values on demand.
remaining <- double(length(color_combos))
for(i in seq_along(color_combos)){
  remaining[i] <- length(guess_filter("while", color_combos[[i]]))
}

# The proportion
proportion_of_words_remaining <- remaining / num_words

max(proportion_of_words_remaining)
# A trash histogram, similar to the one in the video but not interactive
hist(remaining, breaks = length(color_combos), main = "Number of words remaining")

hist(proportion_of_words_remaining, breaks = length(color_combos), main = "Proportion of words remaining")


plot_while <- ggplot(mapping = aes(x = reorder(seq_along(color_combos), -proportion_of_words_remaining), y = proportion_of_words_remaining)) +
  geom_col() +
  ggtitle("Lower values are better--you want as few words remaining as possible!") +
  xlab("Match Pattern Index") +
  theme(axis.text.x = element_text(size = 5.8, angle = 90))

index <- 203
color_combos[[index]]
guess_filter("while", color_combos[[index]])
remaining[index]
proportion_of_words_remaining[index]

median(proportion_of_words_remaining)





# Misc pt II



remaining2 <- double(length(color_combos))
for(i in seq_along(color_combos)){
  remaining2[i] <- length(guess_filter("hopes", color_combos[[i]]))
}

# The proportion
proportion_of_words_remaining2 <- remaining2 / num_words



# Lower values are better--you want as few words remaining as possible!
weighted.mean(proportion_of_words_remaining, remaining)
weighted.mean(proportion_of_words_remaining2, remaining2)





plot_hopes <- ggplot(mapping = aes(x = reorder(seq_along(color_combos), -proportion_of_words_remaining2), y = proportion_of_words_remaining2)) +
  geom_col() +
  ggtitle("Lower values are better--you want as few words remaining as possible!") +
  xlab("Match Pattern Index") +
  theme(axis.text.x = element_text(size = 5.8, angle = 90))




plot_while
plot_hopes



# Scoring Words ---------------------------------------------------------------
# About 1.81 words can be processed each second
sprintf("It will take approximately %.1f days to complete the full run.", (num_words / 100) * (.86 * 60) / 60)
timing <- function(){
  starttime <- proc.time()
  function(){
    round((proc.time() - starttime)[3] / 60, 2)
  }
}
time_from_start <- timing()


# The number of remaining words for a given word and pattern match
remaining <- double(length(color_combos))

# The weighted average of the proportion of remaining words,
# weighted on `remaining`
word_scores <- double(num_words)
names(word_scores) <- words
for(word in words[1:100]){
  for(i in seq_along(color_combos)){
    remaining[i] <- length(guess_filter(word, color_combos[[i]]))
  }
  proportion_of_words_remaining <- remaining / num_words
  word_scores[[word]] <- weighted.mean(proportion_of_words_remaining, remaining)
}
word_scores["women"]


# How many minutes has it been since the run started?
time_from_start()





















# Options to improve performance in 'Scoring Words':
# Find ways to optimize guess_filter()
# Re-write in data.table
# Re-write in Julia
# Re-write in C



# Further ideas to speed up the R code:
#
# Replace `colors` with integers (factors might be even easier???)
# Stop using all the bracket assignments. data.table set() functions
# may be good for this.
# Get rid of all error checking.
# split up the string beforehand?



# Even more ideas (probably less practical):
#
# Directly store the regular expressions for all combos. Is that possible?
# Subset the vector using an in operator instead of a regular expression? You
# would have to paste all the letters together.


# The frequency of words appearing in the English language...
# Using an inner join to remove all words that did not appear in the data set.
weights <- readr::read_csv("datasets/unigram_freq.csv") %>% 
  filter(str_length(word) == 5)
weights <- inner_join(as_tibble(words), weights, by = c("value" = "word"))

words <- structure(as.integer(weights$count), names = weights$value)

















# Reusing the functions from above, but this time we'll be using a dictonary instead of raw words
guess_filter <- function(string, current_combo, word_list = words){
  string <- str_to_lower(string)
  stopifnot(length(string) == 1,
            str_length(string) == 5)
  
  # Get the regex identifying remaining words
  rgx <- build_regex(string, current_combo)
  # Filter down to the remaining possible words
  filtered <- str_subset(word_list, rgx)
  if(length(filtered) == 0) return("zero")
  filtered
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


# The regex solution fails if there isn't a match... had to supply a conditional

time_from_start <- timing()
# The number of remaining words for a given word and pattern match
remaining <- double(length(color_combos))

# The weighted average of the proportion of remaining words,
# weighted on `remaining`
word_scores <- double(num_words)
names(word_scores) <- names(words)
for(word in names(words)){
  for(i in seq_along(color_combos)){
    remaining_words <- guess_filter(word, color_combos[[i]], word_list = names(words))
    remaining[i] <- if(all(remaining_words != "zero")) sum(words[remaining_words]) else 0
  }
  proportion_of_words_remaining <- remaining / sum(words)
  word_scores[[word]] <- weighted.mean(proportion_of_words_remaining, remaining)
print(time_from_start())
}
word_scores





