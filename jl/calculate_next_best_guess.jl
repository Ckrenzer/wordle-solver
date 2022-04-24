# The shiny app does not call this script, but it uses the
# code in this script to determine the guess that narrows
# down possibilities the most.
#
# This script is included for easier debugging, easier reference,
# and to provide a checkpoint to start back up should a native
# julia app be desired for some future project.
include("setup.jl")
scores = sort!(CSV.read("data/processed/opening_word_scores.csv", DataFrame), :weighted_prop)
abc = copy(abc_full)
# Update the combo after each guess:
combo = Int8.([0, 0, 0, 0, 0])
scores = update_scores(scores.word[1], combo, scores, abc)
