# Calculates the opening scores on the full word list
# and writes the results to a file.
#
# Unless you wish to reproduce the results or
# need to recalculate after making changes to
# the algorithm, this script does not need
# to be run.
include("setup.jl")
scores = calculate_scores(words)
leftjoin!(scores, weighted, on = :word)
CSV.write("data/processed/opening_word_scores.csv", scores)
