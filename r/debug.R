# A manual setup useful for debugging
rm(list = ls())
source("r/play.R")
source("r/test.R")
# guess #1
remaining_words <- words
remaining_letters <- abc
best_guess <- names(scores[scores == max(scores)][1L])
color_combo_that_came_back_from_wordle <- colors[c("grey", "grey", "grey", "grey", "grey")]
guess1 <- update_scores(guess = best_guess,
                        split_words = split_words,
                        combo = color_combo_that_came_back_from_wordle,
                        remaining_words = remaining_words,
                        remaining_letters = remaining_letters,
                        color_combos = color_combos,
                        colors = colors)
# guess #2
new_scores        <- guess1$new_scores
remaining_words   <- guess1$remaining_words
remaining_letters <- guess1$remaining_letters
best_guess        <- guess1$best_guess
color_combo_that_came_back_from_wordle <- colors[c("grey", "yellow", "grey", "yellow", "green")]
guess2 <- update_scores(guess = best_guess,
                        split_words = split_words,
                        combo = color_combo_that_came_back_from_wordle,
                        remaining_words = remaining_words,
                        remaining_letters = remaining_letters,
                        color_combos = color_combos,
                        colors = colors)
# guess #3
new_scores        <- guess2$new_scores
remaining_words   <- guess2$remaining_words
remaining_letters <- guess2$remaining_letters
best_guess        <- guess2$best_guess
color_combo_that_came_back_from_wordle <- colors[c("grey", "green", "green", "green", "green")]
guess3 <- update_scores(guess = best_guess,
                        split_words = split_words,
                        combo = color_combo_that_came_back_from_wordle,
                        remaining_words = remaining_words,
                        remaining_letters = remaining_letters,
                        color_combos = color_combos,
                        colors = colors)
# guess #4
new_scores        <- guess3$new_scores
remaining_words   <- guess3$remaining_words
remaining_letters <- guess3$remaining_letters
best_guess        <- guess3$best_guess
color_combo_that_came_back_from_wordle <- colors[c("grey", "yellow", "green", "grey", "grey")]
guess4 <- update_scores(guess = best_guess,
                        split_words = split_words,
                        combo = color_combo_that_came_back_from_wordle,
                        remaining_words = remaining_words,
                        remaining_letters = remaining_letters,
                        color_combos = color_combos,
                        colors = colors)
# guess #5
new_scores        <- guess4$new_scores
remaining_words   <- guess4$remaining_words
remaining_letters <- guess4$remaining_letters
best_guess        <- guess4$best_guess
color_combo_that_came_back_from_wordle <- colors[c("yellow", "yellow", "grey", "grey", "grey")]
guess5 <- update_scores(guess = best_guess,
                        split_words = split_words,
                        combo = color_combo_that_came_back_from_wordle,
                        remaining_words = remaining_words,
                        remaining_letters = remaining_letters,
                        color_combos = color_combos,
                        colors = colors)
# guess #6
new_scores        <- guess5$new_scores
remaining_words   <- guess5$remaining_words
best_guess        <- guess5$best_guess
best_guess <- names(new_scores[new_scores == max(new_scores)][1L])
best_guess # this is your last guess!
