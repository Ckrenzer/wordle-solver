# Packages --------------------------------------------------------------------
using CSV
using DataFrames
using DataFramesMeta
import Dates


# Functions -------------------------------------------------------------------
include("simple_stringr.jl")

# Provides the elapsed time in seconds since the start
function time_from_start(start)
    round((Dates.DateTime(Dates.now()) - Dates.DateTime(start)) / Dates.Millisecond(1) * (1 / 1000), digits = 4)
end

# The same as R's seq_len(), but probably not as safe.
function seq_len(num::Integer)
    collect(1:1:num)
end

# The same as R's seq_along(), but probably not as safe.
# Code fails in surprising ways when you have a length
# zero input.
function seq_along(obj)
    collect(1:1:length(obj))
end

# Similar to R's which(), but definitely not as safe.
function which(logical)
    seq_along(logical)[logical .== 1]
end

# Calculates the weighted mean. Fails if the input contains missing values.
function weighted_mean(vals, weights)
    if length(vals) != length(weights) error("vals and weights must be the same length!") end
    valsum = 0
    for i in seq_along(vals)
        valsum += (vals[i] * weights[i])
    end
    valsum / sum(weights)
end


# Wordle Functions ------------------------------------------------------------
# Runs a query on the `weighted` data frame and returns
# the word frequency for each of the input words.
function get_freq(terms, dictionary = weighted_dict)
    getindex.(Ref(dictionary), terms)
end

# Takes the user's guess and filters down to the remaining possible words
# based on the input word and color combo.
function guess_filter(str, combo, word_list = words)
    if(length(str) != 5) error("You must use a five letter word!") end
    
    # Identify the color to which each letter corresponds
    green_ind = which(combo .== "green")
    yellow_ind = which(combo .== "yellow")
    grey_ind = which(combo .== "grey")
    
    rgx = build_regex(str, green_ind, yellow_ind, grey_ind)
    remaining_words = str_subset(word_list, Regex(rgx))

    # Ensure that the yellow letters were found
    for yellow_letter in unique(string.(str_split(str[yellow_ind], "")))
        remaining_words = str_subset(remaining_words, yellow_letter)
    end
    remaining_words
end

# Creates a regular expression to filter the word list.
function build_regex(str, green_ind, yellow_ind, grey_ind, all_letters = copy(abc))
    # The letters to use in the regex.
    possible_letters = Vector{String}(undef, 5)
    
    # Green letters are set.
    for i in green_ind
        possible_letters[i] = "[" * string(str[i]) * "]"
    end

    # Grey letters are removed from the list entirely
    grey_letters = str_split(string(str[grey_ind]), "")
    remove_grey_letters!(all_letters, grey_letters, green_ind)
    # Grey letters are set to the non-grey letters.
    for i in grey_ind
        possible_letters[i] = str_c(all_letters[i, :])
    end
    
    # Yellow letters are removed from the index in which they appear.
    for i in yellow_ind
        possible_letters[i] = str_c(remove_yellow_letters!(all_letters[i, :], string(str[i])))
    end
    
    str_c(possible_letters)
end

# Sets the value in `abc` to "".
# str_c() will remove letters for you!
# (concatenating empty strings effectively removes them)
function remove_grey_letters!(letters, to_remove, skipped)
    for letter in to_remove
        # Rows corresponding to green are skipped
        for i in setdiff(seq_along(letters[:, 1]), skipped)
            # j's bounds skip the square brackets
            # (starting at the end because most remove letters
            # should be at the end of the array).
            for j in (length(letters[i, :]) - 1):-1:2
                if letters[i, j] == letter
                    letters[i, j] = ""
                end
            end
        end
    end
end

# A separate remove*() function is used for yellows
# to avoid conditionals, boosting performance.
# This function does nearly the same thing as
# remove_grey_letters() but edits only one row
# at a time and returns the mutated row.
function remove_yellow_letters!(letters, to_remove)
    # j's bounds skip the square brackets
    # (starting at the end because most remove letters
    # should be at the end of the array).
    for j in (length(letters) - 1):-1:2
        if letters[j] == to_remove
            letters[j] = ""
        end
    end
    letters
end


# Data Import -----------------------------------------------------------------
# The list of possible answers.
open("data/raw/wordle_list.txt") do file
    global words = read(file, String)
end
words = string.(str_split(words, "\r\n"))
num_words = length(words)

# Word counts to use as weights.
unigrams = CSV.read("data/raw/unigram_freq.csv", DataFrame)
subset!(unigrams, :word => ByRow(x -> length.(x) .== 5))
weighted = leftjoin(DataFrame(word = words), unigrams, on = :word)
replace!(weighted.count, missing => 0)
unigrams = nothing

# All words will be in alphabetical order.
# This enables sharing of indexes across multiple objects.
sort!(words)
sort!(weighted, :word)

# A dictionary for fast and easy subsetting of word frequencies.
weighted_dict = Dict{String, Int64}()
rowindex = 1
for word in words
    weighted_dict[word] = weighted[rowindex, 2]
    rowindex += 1
end


# Additional Data -------------------------------------------------------------
# Letter ordering.
alphabet = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
# Goal: Identify the best opening letter order for
# the regular expression, optimizing match speed.
#
# Sorting improves the speed of the score calculation
# by 1.5%, according to my own benchmarks.
#
# Create and populate a data frame with:
# the letter,
# the position in the word (1-5),
# the frequency of the letter occurring at that position.
num_rows = length(alphabet) * 5
lettervals = DataFrame([Vector{String}(undef, num_rows),
                        Vector{Int8}(undef, num_rows),
                        Vector{Int64}(undef, num_rows)],
                       [:letter, :position, :freq])
index = 1
for letter_ind in seq_len(5)
    for letter in alphabet
        lettervals[index, :] = [letter, letter_ind, sum(str_detect.(string.(SubString.(words, letter_ind, letter_ind)), letter))]
        index += 1
    end
end
lettervals = @orderby(lettervals, :position, -:freq)
# Each row corresponds to the possible letters at each index,
# surrounded by square brackets:
abc = Array{String}(undef, 5, length(alphabet) + 2)
for i in seq_len(5)
    abc[i, :] = push!(pushfirst!(@subset(lettervals, :position .== i)[!, :letter], "["), "]")
end

# Color combinations.
colors = ["green", "yellow", "grey"]
# All potential match patterns that could be found. There are 243 of them
# (3^5)--an option for each color and five letters in the word.
color_combos = Array{String}(undef, 243, 5)
num_colors = seq_along(colors)
rowindex = 1
for i in num_colors, j in num_colors, k in num_colors, l in num_colors, m in num_colors
    color_combos[rowindex, seq_len(5)] = [colors[i], colors[j], colors[k], colors[l], colors[m]] 
    rowindex += 1
end
num_combos = length(color_combos[:, 1])


# Calculations ----------------------------------------------------------------
# The number of words remaining for all possible color combinations on one word
# ("feens" in this case). If the value is zero, that means there isn't a word
# in the list that provides a match for the given word and pattern.
indexes = seq_len(num_combos)
remaining = zeros(Int64, num_combos)
for i in indexes
    remaining[i] = length(guess_filter("feens", color_combos[i, :]))
end
remaining

# Calculates the proportion of words remaining for each word.
num_remaining = zeros(Int64, num_combos)
word_scores = Dict{String, Float64}()
for word in words
    for i in indexes
        num_remaining[i] = length(guess_filter(word, color_combos[i, :]))
    end
    proportion_of_words_remaining = num_remaining ./ num_words
    word_scores[word] = weighted_mean(proportion_of_words_remaining, num_remaining)
end

# Calculates the weighted proportion of words remaining.
word_counts = sum(weighted.count)
word_weights = Dict{String, Float64}()
start = Dates.now()
word_ind = 1
for word in words
    # Print the elapsed time since the beginning
    println("Word: " * word * "    Time from start: " * string(time_from_start(start)) * "    Word Number:" * string(word_ind))
    for i in indexes
        num_remaining[i] = sum(get_freq(guess_filter(word, color_combos[i, :])))
    end
    proportion_of_words_remaining = num_remaining ./ word_counts
    word_weights[word] = weighted_mean(proportion_of_words_remaining, num_remaining)
    word_ind += 1
end


# Saving Results ---------------------------------------------------------------------
u = DataFrame(word = collect(keys(word_scores)), unweighted_prop = collect(values(word_scores)), r = 1)
w = DataFrame(word = collect(keys(word_weights)), weighted_prop = collect(values(word_weights)), r = 1)
scores = leftjoin(u, w, on = :word)
leftjoin!(scores, weighted, on = :word)


CSV.write("data/processed/word_scores.csv", scores)


# The scores (calculated using the final results in the Calculations section).
scores = CSV.read("data/processed/opening_word_scores.csv", DataFrame, header = true)

# What is the best opening word, assuming the words are all equally likely?
scores[scores.unweighted_score .== minimum(scores.unweighted_score), :]
# How about when the words are weighted based on how often they're used?
scores[scores.weighted_score .== minimum(scores.weighted_score), :]
