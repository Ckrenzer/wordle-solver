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
# Finds the weighted proportion of words remaining
function calculate_scores(words = remaining_words, word_freq = word_freq, freq_total = word_counts)
    num_words = length(words)
    word_ind = 1
    start = Dates.now()
    num_remaining = Vector{Int64}(undef, num_combos)
    word_weights = Dict{String, Float64}()
    
    for word in words
        # Print the elapsed time since beginning the calculation
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
    
    # Identify the color to which each letter corresponds
    green_ind = which(combo .== 0)
    yellow_ind = which(combo .== 1)
    grey_ind = which(combo .== 2)
    
    rgx = build_regex(str, green_ind, yellow_ind, grey_ind)
    remaining_words = str_subset(word_list, Regex(rgx))
    
    # Ensure that the yellow letters were found
    for yellow_letter in unique(string.(str_split(str[yellow_ind], "")))
        remaining_words = str_subset(remaining_words, yellow_letter)
    end
    remaining_words
end

# Creates a regular expression to filter the word list.
function build_regex(str, green_ind, yellow_ind, grey_ind, all_letters = abc)
    # The letters to use in the regex.
    # Each element corresponds to a character class with
    # the possible letters given the color indexes.
    possible_letters = Vector{String}(undef, 5)
    
    # Green letters are set.
    for i in green_ind
        possible_letters[i] = "[" * str[i] * "]"
    end
    
    # Grey letters are removed from the list entirely
    # (removes grey letters from all rows of letters
    # in the letter matrix--we skip rows corresponding
    # to green letters because green rows aren't used).
    for i in grey_ind
        grey_letter = str[i]
        for j in union(grey_ind, yellow_ind)
            all_letters[j, all_letters[j, :] .== grey_letter] .= ' '
        end
        possible_letters[i] = str_remove_all(str_c(all_letters[i, :]), " ")
    end
    
    # Yellow letters are removed from the index in which they appear.
    for i in yellow_ind
        all_letters[i, all_letters[i, :] .== str[i]] .= ' '
        str_remove_all(str_c(all_letters[i, :]), " ")
    end
    
    str_c(possible_letters)
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
word_counts = sum(weighted.count)
# Storing the weights in a dictionary for quick access
word_freq = Dict{String, Int64}()
for i in seq_along(weighted.word)
    word_freq[weighted.word[i]] = weighted.count[i]
end
unigrams = nothing

# All words will be in alphabetical order.
# This enables sharing of indexes across multiple objects.
sort!(words)
sort!(weighted, :word)


# Additional Data -------------------------------------------------------------
# Letter ordering.
alphabet = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z']
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
lettervals = DataFrame([Vector{Char}(undef, num_rows),
Vector{Int8}(undef, num_rows),
Vector{Int64}(undef, num_rows)],
[:letter, :position, :freq])
index = 1
for letter_ind in seq_len(5)
    for letter in alphabet
        lettervals[index, :] = [letter, letter_ind, sum(str_detect.(SubString.(words, letter_ind, letter_ind), string(letter)))]
        index += 1
    end
end
lettervals = @orderby(lettervals, :position, -:freq)
# Each row corresponds to the possible letters at each index,
# surrounded by square brackets:
abc = Array{Char}(undef, 5, length(alphabet) + 2)
for i in seq_len(5)
    abc[i, :] = push!(pushfirst!(@subset(lettervals, :position .== i)[!, :letter], '['), ']')
end

# Color combinations.
# 0 is "green"
# 1 is "yellow"
# 2 is "grey"
colors = Vector{Int8}([0, 1, 2])
# All potential match patterns that could be found. There are 243 of them
# (3^5)--an option for each color and five letters in the word.
color_combos = Array{Int8}(undef, 243, 5)
num_colors = seq_along(colors)
rowindex = 1
for i in num_colors, j in num_colors, k in num_colors, l in num_colors, m in num_colors
    color_combos[rowindex, seq_len(5)] = [colors[i], colors[j], colors[k], colors[l], colors[m]] 
    rowindex += 1
end
num_combos = length(color_combos[:, 1])


# Saving Results --------------------------------------------------------------
scores = calculate_scores(words)
leftjoin!(scores, weighted, on = :word)
CSV.write("data/processed/opening_word_scores.csv", scores)
