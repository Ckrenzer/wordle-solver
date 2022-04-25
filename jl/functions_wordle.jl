# Contains the functions used to filter out words
# and score remaining ones.


# Finds the weighted proportion of words remaining
# after accounting for the results of a previous guess.
#
# This function returns an updated `scores` data
# frame and modfies `abc` in-place.
#
# Args:
# guess -- The most recent word input to the game
#          (This should be the word with the highest score in the `scores` data frame).
# combo -- The results of `guess` after entering it into wordle.
# scores -- The data frame containing the remaining words and their scores.
# abc -- The letter matrix containing the remaining letters.
function update_scores(guess, combo, scores, abc)
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
    new_scores = calculate_scores(leftover_words, word_freq, leftover_word_counts)
    leftjoin!(new_scores, weighted, on = :word)
    new_scores = @orderby(new_scores, :weighted_prop)
end

# Finds the weighted proportion of words remaining.
function calculate_scores(words = remaining_words, word_freq = word_freq, freq_total = word_counts)
    num_words = length(words)
    word_ind = 1
    start = Dates.now()
    num_remaining = Vector{Int64}(undef, num_combos)
    word_weights = Dict{String, Float64}()
    
    for word in words
        # Print the elapsed time since beginning the calculation.
        println("Word: " * word * "    Time from start: " * string(time_from_start(start)) * "    Word " * string(word_ind) * " of " * string(num_words))
        word_ind += 1
        
        for i in seq_along(color_combos[:, 1])
            num_remaining[i] = sum(get_freq(guess_filter(word, color_combos[i, :], words), word_freq))
        end
        proportion_of_words_remaining = num_remaining ./ freq_total
        word_weights[word] = weighted_mean(proportion_of_words_remaining, num_remaining)
        
    end
    DataFrame(word = collect(keys(word_weights)), weighted_prop = collect(values(word_weights)))
end

# Runs a query on the dictionary storing the weights and returns
# the word frequency for each of the input words.
function get_freq(terms, dictionary)
    getindex.(Ref(dictionary), terms)
end

# Takes the user's guess and filters down to the remaining possible words
# based on the input word and color combo.
function guess_filter(str, combo, word_list)
    if(length(str) != 5) error("You must use a five letter word!") end
    
    # Identify the color to which each letter corresponds.
    green_ind = which(combo .== 0)
    yellow_ind = which(combo .== 1)
    grey_ind = which(combo .== 2)
    
    rgx = build_regex(str, green_ind, yellow_ind, grey_ind, copy(abc))
    remaining_words = str_subset(word_list, Regex(rgx))
    
    # Ensure that the yellow letters were found.
    for yellow_letter in unique(string.(str_split(str[yellow_ind], "")))
        remaining_words = str_subset(remaining_words, yellow_letter)
    end
    remaining_words
end

# Creates a regular expression to filter the word list.
function build_regex(str, green_ind, yellow_ind, grey_ind, all_letters)
    # The letters to use in the regex.
    # Each element corresponds to a character class with
    # the possible letters given the color indexes.
    possible_letters = Vector{String}(undef, 5)
    
    # Green letters are set.
    for i in green_ind
        possible_letters[i] = "[" * str[i] * "]"
    end
    # Remove ruled out letters.
    remove_letters!(str, yellow_ind, grey_ind, all_letters)
    # Assign remaining letters.
    for i in union(grey_ind, yellow_ind)
        possible_letters[i] = str_remove_all(str_c(all_letters[i, :]), " ")
    end

    str_c(possible_letters)
end

# Eliminates grey and yellow letters as possibilities
# at relevant indexes (updates `abc`).
function remove_letters!(str, yellow_ind, grey_ind, all_letters)
    # Grey letters are removed from the list entirely.
    for i in grey_ind
        for j in union(grey_ind, yellow_ind)
            all_letters[j, all_letters[j, :] .== str[i]] .= ' '
        end
    end
    # Yellow letters are removed from the index in which they appear.
    for i in yellow_ind
        all_letters[i, all_letters[i, :] .== str[i]] .= ' '
    end
end
