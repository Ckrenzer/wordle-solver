# Packages --------------------------------------------------------------------
using CSV
using DataFrames


# Functions -------------------------------------------------------------------
include("simple_stringr.jl")

# The same as R's seq_len(), but probably not as safe.
function seq_len(num::Integer)
    collect(1:1:num)
end

# Similar to R's which(), but definitely not as safe.
function which(logical)
    seq_len(length(logical))[logical .== 1]
end

# Calculates the weighted mean. Fails if the input contains missing values.
function weighted_mean(vals, weights)
    if length(vals) != length(weights) error("vals and weights must be the same length!") end
    valsum = 0
    for i in seq_len(length(vals))
        valsum += (vals[i] * weights[i])
    end
    valsum / sum(weights)
end

# Runs a query on the `weighted` data frame and returns
# the word frequency for each of the input words.
function get_freq(terms, df = weighted)
    matches = zeros(Int16, nrow(df))
    for term in terms
        for i in seq_len(nrow(df))
            if str_detect(df[i, 1], term)
                matches[i] = i
            end
        end
    end
    collect(df[matches[matches .!= 0], 2])
end


# Wordle Functions ------------------------------------------------------------
# Takes the user's guess and filters down to the remaining possible words
# based on the input word and color combo.
function guess_filter(string, current_combo, word_list = words)
    if(length(string) != 5) error("You must use a five letter word!") end
    rgx = build_regex(string, current_combo)
    str_subset(word_list, Regex(rgx))
end

# Creates a regular expression to filter the word list.
function build_regex(str, combo, all_letters = alphabet)
    # Grey letters are removed from the list entirely
    grey_letters = str[which(combo .== "grey")]
    non_grey_letters = remove_letters(all_letters, grey_letters)
    
    # The letters to use in the regex.
    possible_letters = Vector{String}(undef, 5)
    
    # Green letters are set.
    for i in which(combo .== "green") possible_letters[i] = string(str[i]) end
    # Grey letters are set to the non-grey letters.
    for i in which(combo .== "grey") possible_letters[i] = str_c(non_grey_letters) end
    # Yellow letters are removed from the index in which they appear.
    for i in which(combo .== "yellow") possible_letters[i] = str_c(remove_letters(non_grey_letters, string(str[i]))) end
    
    # Each element of the array will be surrounded by brackets []
    # to send to the regex.
    str_c("[" .* possible_letters .* "]")
end

# Creates a new array containing only those letters
# not in to_remove by identifying the position of
# the letter to remove in the array of letters.
function remove_letters(letters, to_remove)
    remove_letter_indexes = zeros(Int64, 5)
    for i in seq_len(length(to_remove))
        letter = string(to_remove[i])
        ind = which(letters .== letter)
        if(length(ind) != 0)
            # The vector `ind` is guaranteed to be of length one.
            global remove_letter_indexes[i] = ind[1]
        else
            global remove_letter_indexes[i] = 0
        end
    end
    remove_letter_indexes = remove_letter_indexes[remove_letter_indexes .!= 0]
    letters[setdiff(1:end, remove_letter_indexes)]
end


# Data Import -----------------------------------------------------------------
# The list of possible answers.
open("data/raw/wordle_list.txt") do file
    global words = read(file, String)
end
words = string.(str_split(words, "\r\n"))
num_words = length(words)

# The unweighted scores (calculated by getting the final results of `word_scores`).
scores = CSV.read("data/processed/unweighted_word_scores.csv", DataFrame, header = ["word", "score"])
# Word counts to use as weights.
unigrams = CSV.read("data/raw/unigram_freq.csv", DataFrame)
subset!(unigrams, :word => ByRow(x -> length.(x) .== 5))
weighted = select(leftjoin(scores, unigrams, on = :word), Not(:score))
replace!(weighted.count, missing => 0)


# Additional Data -------------------------------------------------------------
alphabet = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
# Color combinations.
colors = ["green", "yellow", "grey"]
# All potential match patterns that could be found. There are 243 of them
# (3^5)--an option for each color and five letters in the word.
#
# You can assign an undefined string matrix, but you'll have to assign
# values to each index before you will be allowed to subset it.
color_combos = Array{String}(undef, 243, 5)
num_colors = seq_len(length(colors))
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
indexes = seq_len(num_combos)
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
for word in words
    for i in indexes
        num_remaining[i] = guess_filter(word, color_combos[i, :]) |> get_freq |> sum
    end
    proportion_of_words_remaining = num_remaining ./ word_counts
    word_weights[word] = weighted_mean(proportion_of_words_remaining, num_remaining)
end


# Results ---------------------------------------------------------------------
# What is the best opening word, assuming the words are all equally likely?
scores[scores.score .== minimum(scores.score), :]








# NEXT STEPS:

# WRITE THE RESULTS OF WORD_WEIGHTS TO A FILE
# FIND THE BEST OPENING WORD USING WORD_WEIGHTS
#
# FIND OUT HOW TO PLAY A GAME UNTIL YOU FIND THE RIGHT ANSWER OR REACH ROUND 7
#
# FIX SIMPLE_STRINGR.jl
#
# SIMPLIFY R SCRIPT SO THAT IT ONLY CONTAINS THE FINAL CODE FOR THE CALCULATIONS,
# THEN CREATE ANOTHER SCRIPT FOR A SHINY APP.
#
# THE SHINY APP SHOULD SUGGEST THE BEST WORD (OPENING WORD BY DEFAULT) TO CHOOSE,
# AND THE BEST WORD FOR A GIVEN PATTERN (AFTER THE FIRST GUESS). THE APP SHOULD
# TRY TO EXPLAIN TO THE USER WHY THE APP IS THE BEST GUESS, PERHAPS BY USING ONE
# OF THOSE FANCY GRAPHS. YOU KNOW THE ONE.
#
#
#
# READ THROUGH NOTES IN THE R SCRIPT TO SEE IF YOU MISSED ANYTHING THAT SHOULD
# HAVE BEEN MENTIONED HERE.