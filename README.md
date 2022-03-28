# About
Uses information theory to solve Wordle puzzles, inspired by [3Blue1Brown's YouTube video](https://youtu.be/v68zYyaEmEA).

The goal is to turn this into a word recommender through a shiny app. Details to come--there's only so much I can do in a weekend!

Oh, and for the record: I never looked at 3Blue1Brown's code. The code you see is entirely from my own noggin. The linked video is all I used as reference.


# Motivations
I made this repo as a Julia learning exercise.

Learning the syntax of a programming language is something best learned through experience. I usually have a sense for how R behaves. Almost every data structure being implemented with arrays, along with the fact that there are only four useful data types ('character', 'logical', 'integer', 'double') means the basics are pretty simple. Copy-on-modify semantics and the quote from John Chambers, "Everything that exists is an object. Everything that happens is a function call" allow users to draft up pretty coherent guiding principles when studying code.

Among other things, Julia attempts to retain the straighforwardness of R while providing more control to the developer. The Wordle solver will, hopefully, give me some insights into these changes of behavior. The best way to learn something is by spending time with it. Wordle gives me a perfect excuse to do just that!


# Data
I found term frequency data weighing the words on [Kaggle](https://www.kaggle.com/datasets/rtatman/english-word-frequency?select=unigram_freq.csv).


# Thoughts
I have *thoroughly* enjoyed using Julia. Using for loops and if statements without guilt sure feels nice! The Julia code runs nearly twice as fast as R, using similar approaches to my subsetting algorithm in both languages. And that's with very little experience with Julia's ins-and-outs.

My biggest difficulties with the language come from subsettting. R's subsetting operations are very concise, but I've found that many of the Julia functions are not quite as user-friendly or robust, meaning I had to write custom functions for several subsetting operations.


# Next Steps

-   Fix simple_stringr.jl and only keep those functions that were used in the script.

-   THE APP SHOULD TRY TO EXPLAIN TO THE USER WHY THE APP IS THE BEST GUESS, PERHAPS BY USING ONE OF THOSE FANCY GRAPHS. YOU KNOW THE ONE.
