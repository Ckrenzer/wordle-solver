# Supply default values when a row in abc contains all blanks...?
#
# Thoughts:
#   Add logic to break ties when words provide the same amount of information by using the word counts.
#   When there are few words, fewer than ... 10? Choose the word that has the highest word count.
scores = sort!(CSV.read("data/processed/opening_word_scores.csv", DataFrame), :weighted_prop)
abc = copy(abc_full)
scores = update_scores(scores.word[1], [2, 2, 0, 2, 2], scores, abc)
scores = update_scores(scores.word[1], [2, 0, 0, 0, 2], scores, abc)
scores = update_scores(scores.word[1], [2, 0, 2, 0, 0], scores, abc)
scores = update_scores(scores.word[1], [2, 0, 2, 0, 0], scores, abc)
