# This script loads in all required packages, functions, and data.
#
# It calls all scripts whose name starts with 'functions'.
# It gets called by all scripts whose name starts with 'calculate'.

# Packages and Functions ------------------------------------------------------
using CSV
using DataFrames
using DataFramesMeta
import Dates
include("functions_stringr.jl")
include("functions_utility.jl")
include("functions_wordle.jl")


# Import Data -----------------------------------------------------------------
# The list of possible answers.
open("data/raw/wordle_list.txt") do file
    global words = read(file, String)
end
words = string.(str_split(words, "\n"))
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


# Create Color Combos and Letter Data -----------------------------------------
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
# Keep a copy for game resetting
abc_full = copy(abc)

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
