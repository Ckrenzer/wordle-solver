# Packages --------------------------------------------------------------------


# Functions -------------------------------------------------------------------
include("simple_stringr.jl")

# The same as R's seq_len(), but probably not as safe.
function seq_len(num::Integer)
    collect(1:1:num)
end


# Data Import -----------------------------------------------------------------
# The list of possible answers
open("data/wordle_list.txt") do file
   global words = read(file, String)
end
words = str_split(words, "\r\n")
num_words = length(words)


# Additional Data -------------------------------------------------------------
# Combinations
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
    rowindex = rowindex + 1
end


function guess_filter(string, current_combo, word_list = words)








# Wordle Functions ------------------------------------------------------------
# Evaluate the user's guess
function guess(string, ans)
    if(str_length(string) != 5)
        error("Five letter words only!")
    elseif(!string in words)
        error("Invalid word.")
    end

    hints = Vector{String}(undef, 5)
    for i in 1:5
        if(string[i] == ans[i])
            global hints[i] = "green"
        elseif(str_detect(ans, string[i]))
            global hints[i] = "yellow"
        else
            global hints[i] = "grey"
        end
    end
    hints
end


# Going to build a regex with this array
letters = ["[", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "]"]
str_subset(letters, r"[^e]")
str_c(str_subset(letters, Regex("[^e]")))


# Make a list of possible letters?



# Filter the list to answers that are still possible
function find_remaining_words(guess, guess_results, words)
    
    greys = str_split(guess, "")[str_detect.(guess_results, "grey")]
    yellows = str_split(guess, "")[str_detect.(guess_results, "yellow")]
    
    # Regex for not grey, not yellow, and not grey and not yellow
    not_greys = "[^" * str_c(greys) * "]"
    not_yellows = "[^" * str_c(yellows) * "]"
    not_greys_nor_yellows = FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

    # Build a regular expression to subset the word list
    pattern = Vector{String}(undef, 5)
    for i in seq_len(str_length(guess))
        if(string(guess[i]) in greys)
            pattern[i] = str_c(str_subset(letters, Regex(not_greys)))
        elseif(string(guess[i]) in yellows)
            pattern[i] = not_greys_nor_yellows
        else
            pattern[i] = guess[i]
        end
    end

    str_subset(words, pattern)

end

string("hi"[1]) in ["hello", "h"]

str_c(["[^", "e", "]"])
guess("while", "women")

x = "while"
greys = str_split(x, "")[str_detect.(["green", "yellow", "grey", "yellow", "grey"], "grey")]
not_greys = "[^" * str_c(greys) * "]"
str_subset(letters, Regex(not_greys))

string(x[1]) in ["hey", "w"]

typeof(SubString("hello", 1, 1))