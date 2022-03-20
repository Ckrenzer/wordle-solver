# Packages --------------------------------------------------------------------



# Functions -------------------------------------------------------------------
# Add a source call to simple_stringr.jl here

# The same as R's seq_len(), but probably not as safe.
function seq_len(num::Integer)
    collect(1:1:num)
end


# The list of possible answers
open("data/wordle_list.txt") do file
   global words = read(file, String)
end
words = str_split(words, "\r\n")


