# This script loads in all required packages, functions, and data.
#
# It calls all scripts whose name starts with 'functions'.
# It gets called by all scripts whose name starts with 'calculate'.
# It gets called by the shiny app in R.


# Set Constants ---------------------------------------------------------------
# The number of characters in a word:
const global num_characters = 5
const global num_characters_seq = collect(1:num_characters)
# The possible colors:
# (0 is "green"; 1 is "yellow"; 2 is "grey")
const global grn = 0
const global ylw = 1
const global gry = 2
const global colors = Vector{Int8}([grn, ylw, gry])
# The number of possible color combinations:
# (3^5--an option for each color and five letters in the word)
const global num_combos = 3^num_characters
const global num_combos_seq = collect(1:length(num_combos))


# Packages and Functions ------------------------------------------------------
using CSV
using DataFrames
using DataFramesMeta
import Dates
include("jl/original_solver/functions_stringr.jl")
include("jl/original_solver/functions_utility.jl")
include("jl/original_solver/functions_wordle.jl")


# Import Data -----------------------------------------------------------------
# The list of possible answers.
open("data/wordle_list.txt") do file
    global words = read(file, String)
end
words = string.(str_split(words, "\n"))
num_words = length(words)

# Word counts to use as weights.
unigrams = CSV.read("data/unigram_freq.csv", DataFrame)
subset!(unigrams, :word => ByRow(x -> length.(x) .== num_characters))
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
num_rows = length(alphabet) * num_characters
lettervals = DataFrame([Vector{Char}(undef, num_rows),
Vector{Int8}(undef, num_rows),
Vector{Int64}(undef, num_rows)],
[:letter, :position, :freq])
index = 1
for letter_ind in num_characters_seq
    for letter in alphabet
        lettervals[index, :] = [letter, letter_ind, sum(str_detect.(SubString.(words, letter_ind, letter_ind), string(letter)))]
        global index += 1
    end
end
lettervals = @orderby(lettervals, :position, -:freq)
# Each row corresponds to the possible letters at each index,
# surrounded by square brackets:
abc = Array{Char}(undef, num_characters, length(alphabet) + 2)
for i in num_characters_seq
    abc[i, :] = push!(pushfirst!(@subset(lettervals, :position .== i)[!, :letter], '['), ']')
end
# Keep a copy to easily reset the game
abc_full = copy(abc)

# All potential match patterns.
color_combos = Array{Int8}(undef, num_combos, num_characters)
num_colors = colors .+ 1
rowindex = 1
for i in num_colors, j in num_colors, k in num_colors, l in num_colors, m in num_colors
    color_combos[rowindex, num_characters_seq] = [colors[i], colors[j], colors[k], colors[l], colors[m]] 
    global rowindex += 1
end
