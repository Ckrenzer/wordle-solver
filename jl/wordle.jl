# The list of possible answers
open("data/wordle_list.txt") do file
   global words = read(file, String)
end
words = split(words, "\r\n")


str_subset(words, "d[a-z]{2}nk")