# About
Uses information theory to solve Wordle puzzles, inspired by [3Blue1Brown's YouTube video](https://youtu.be/v68zYyaEmEA).

Oh, and for the record: I never looked at 3Blue1Brown's code--the code you see is entirely from my own noggin. The linked video is all I used as reference.


# The Solver

You can see the solver by pasting the following code into your R console (this is no longer hosted on shinyapps.io):

```
if(!require(shiny)) install.packages("shiny")
shiny::runGitHub(repo = "wordle-solver",
                 username = "Ckrenzer",
                 ref = "main")
```

*Note: You will need to have Julia installed for this app to function on your local machine.*


# Motivations

I usually have a sense for how R behaves. The basics are pretty simple since almost every data structure is implemented with an array, along with the fact that there are only four useful data types ('character', 'logical', 'integer', 'double'). Copy-on-modify semantics and the quote from John Chambers, "Everything that exists is an object. Everything that happens is a function call" allow users to draft up pretty coherent guiding principles when studying R code.

Learning the syntax of a programming language is something best done through experience. I do not have enough experience to determine how Julia functions in different situations, so it is for this purpose that I made the solver.

# Data

### Raw

I found term frequency data weighing the words on [Kaggle](https://www.kaggle.com/datasets/rtatman/english-word-frequency?select=unigram_freq.csv).

### Processed

This directory contains the term frequency and weighted proportion of words remaining (if you were to use that word as the opener, weighted on term frequency) for each word in the Wordle list of acceptable answers. This was the most computationally expensive portion of the project. To identify the best opening word, each color pattern had to be tried to see the number of remaining words. My Julia algorithm takes .3 seconds to calculate a score for one word when using the full word list.

To avoid having to explain the rules of golf, the 'score' you'll see in the app is just the inverse of the weighted score.

# Thoughts
I have *thoroughly* enjoyed using Julia. Using for loops without suspicion or guilt sure feels nice! The Julia code runs nearly twice as fast as R, using similar approaches to my subsetting algorithm in both languages. And that's with very little experience with Julia's ins-and-outs.

My biggest difficulties with the language come from subsettting. R's subsetting operations are very concise, but I've found that many of the Julia functions are not quite as user-friendly or robust, meaning I had to write custom functions for several subsetting operations. I look forward to learning more about the language, it's syntax, and ways to apply it to solve everyday problems!
