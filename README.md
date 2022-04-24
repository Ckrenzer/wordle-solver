# About
Uses information theory to solve Wordle puzzles, inspired by [3Blue1Brown's YouTube video](https://youtu.be/v68zYyaEmEA).

Oh, and for the record: I never looked at 3Blue1Brown's code--the code you see is entirely from my own noggin. The linked video is all I used as reference.


# The Solver

You can see the solver with [this link](https://7phynv-connor0krenzer.shinyapps.io/Wordle-Solver/) when it is hosted on shinyapps.io, or you can paste the following code into your R console:

```
if(!require(shiny)) install.packages("shiny")
shiny::runGitHub(repo = "wordle-solver",
                 username = "Ckrenzer",
                 subdir = "R/app",
                 ref = "main")
```

*Note: You will need to have Julia installed for this app to function on your local machine.*


Calculating all possible outcomes would take ten days so to run on my laptop, from my flawed estimates (namely, (12947 * 1.1) / 60 / 24: I'm guestimating there are 18 million outcomes, my algo can run 12947 * 1.1 words per hour, and there are 60 minutes in an hour obviously == 21 hours). It may take some time before I'm ready to run something like this.


# Motivations

I usually have a sense for how R behaves. The basics are pretty simple since almost every data structure is implemented with arrays, along with the fact that there are only four useful data types ('character', 'logical', 'integer', 'double'). Copy-on-modify semantics and the quote from John Chambers, "Everything that exists is an object. Everything that happens is a function call" allow users to draft up pretty coherent guiding principles when studying code.

Learning the syntax of a programming language is something best done through experience. I have not built up guiding intuition of how Julia reacts to different situations, however. It is for this purpose I made this solver.

# Data

### Raw

I found term frequency data weighing the words on [Kaggle](https://www.kaggle.com/datasets/rtatman/english-word-frequency?select=unigram_freq.csv).

### Processed

This directory contains the term frequency, unweighted score, and weighted score for each word in the Wordle list of acceptable answers. This was the most computationally expensive portion of the project. To identify the best opening word, each color pattern had to be tried to see the number of remaining words. My Julia algorithm takes .3 seconds to calculate a score for one word.

The score columns are average proportions of words remaining after choosing a particular word (the unweighted one being when all words are equally likely with the other being the weighted average of the proportion of remaining words--weighted on term frequency). To avoid having to explain the rules of golf, the 'score' you'll see in the app is just the inverse of the weighted score.


# Thoughts
I have *thoroughly* enjoyed using Julia. Using for loops and if statements without guilt sure feels nice! The Julia code runs nearly twice as fast as R, using similar approaches to my subsetting algorithm in both languages. And that's with very little experience with Julia's ins-and-outs.

My biggest difficulties with the language come from subsettting. R's subsetting operations are very concise, but I've found that many of the Julia functions are not quite as user-friendly or robust, meaning I had to write custom functions for several subsetting operations.


# Next Steps

- Consider consider a way to input the results and get the color combo to send to next_guess() back from the website.

- Review notes, thoughts, and new ideas for functionality in subsequent_guesses.jl.

- Fix simple_stringr.jl and only keep those functions that were used in the script.

- Get app running without needing to read in data from a url.

- Consider adding a constant for the length of a string (5). Not just a constant for that. We want as many constants running around in the code as possible! For example, a constant called 'gr' with a value of zero that indicates that zero corresponds to green letters.

- As the number of remaining guesses dwindles down, consider changing how words are weighted. Add more weight to the individual words' frequencies instead of the amount of information that particular guess would provide.

- Supply default values when a row in abc contains all blanks...?

- Add logic to break ties when words provide the same amount of information by using the word counts.

- Do not include words that have a term frequency of zero beyond three guesses.