# About
Uses information theory to solve Wordle puzzles, inspired by [3Blue1Brown's YouTube video](https://youtu.be/v68zYyaEmEA).

# The Solver
You can see the solver by pasting the following code into your R console:

```
installed_packages <- rownames(installed.packages())
to_install <- c("doParallel", "shiny", "shinycssloaders", "shinyjs")
to_install <- to_install[!to_install %in% installed_packages]
for(pkg in to_install) install.packages(pkg)
shiny::runGitHub(repo = "wordle-assistant",
                 username = "Ckrenzer",
                 ref = "main")
```

# Data
Here are my data sources:

-    unigram frequency data on [Kaggle](https://www.kaggle.com/datasets/rtatman/english-word-frequency?select=unigram_freq.csv).
-    the official acceptable answers word list (possible answers as well as acceptable guesses that are not answers)
was taken from [GitHub](https://github.com/Kinkelin/WordleCompetition/blob/main/data/official/combined_wordlist.txt).
