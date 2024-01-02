#!/usr/bin/bash

mkdir -p wordle_assistant/data
mkdir -p wordle_assistant/r
cp app.R wordle_assistant/
cp r/play.R wordle_assistant/r
cp data/opening_word_scores.csv wordle_assistant/data/
cp data/unigram_freq.csv wordle_assistant/data/
cp data/wordle_list.txt wordle_assistant/data/

Rscript deploy.R
