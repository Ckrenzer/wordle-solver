scores = CSV.read("data/processed/opening_word_scores.csv", DataFrame)
abc = copy(abc_full)


# Args:
# guess -- The word with the highest score in the `scores` data frame.
# combo -- The results of `guess` after entering it into wordle.
# scores -- The data frame containing the remaining words and their scores.
# abc -- The letter matrix containing the remaining letters.
#
# This function returns the updated `scores` data frame and modfies `abc`
# in-place.
function next_guess(guess, combo, scores, abc)
    # Removes ruled out letters based on the combo--this makes the
    # results of the previous guesses carry through the remainder of the game.
    remove_letters!(guess, which(combo .== 1), which(combo .== 2), abc)
    leftover_words = guess_filter(guess, combo, scores[:, :word])

    # Find the number of uses of each word in the English lanugage
    freq_vals = weighted[in.(weighted.word, Ref(leftover_words)), :]
    leftover_word_counts = sum(freq_vals.count)
    # Storing the weights in a dictionary for quick access
    word_freq = Dict{String, Int64}()
    for i in seq_along(freq_vals[:, 1])
        word_freq[freq_vals.word[i]] = freq_vals.count[i]
    end

    # Recalculate scores for the guess that provides the most information
    # about the remaining words
    @orderby(calculate_scores(leftover_words, word_freq, leftover_word_counts), :weighted_prop)
end

# Only the combo should change--consider a way to input the results
# and get the color combo back from the website.
#
# Perhaps make a function that inputs the guess and then retrieves the color combo.
# The results of that function would then get sent into next_guess().
#
# Supply default values when a row in abc contains all blanks...?
#
#
#
# Thoughts:
#   Add logic to break ties when words provide the same amount of information by using the word counts.
#   When there are few words, fewer than ... 10? Choose the word that has the highest word count.
scores = sort!(CSV.read("data/processed/opening_word_scores.csv", DataFrame), :weighted_prop)
abc = copy(abc_full)
scores = next_guess(scores.word[1], [2, 1, 1, 1, 2], scores, abc)
scores = next_guess(scores.word[1], [2, 0, 1, 0, 2], scores, abc)
scores = next_guess(scores.word[1], [2, 0, 2, 0, 0], scores, abc)
scores = next_guess(scores.word[1], [2, 0, 2, 0, 0], scores, abc)
