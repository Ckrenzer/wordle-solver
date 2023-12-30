#!/usr/bin/bash

mkdir -p wordle_assistant/data
cp app.R wordle_assistant/
cp data/opening_word_scores.csv wordle_assistant/data/
cp data/unigram_freq.csv wordle_assistant/data/
cp data/wordle_list.txt wordle_assistant/data/
cp --recursive r/ wordle_assistant

Rscript deploy.R
