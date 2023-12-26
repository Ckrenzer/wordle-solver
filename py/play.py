# MODULES
import string
import re
import copy
import multiprocessing
import os
import math
from datetime import datetime


# IMPORTANT 'CONSTANTS'
LOGFILE = "log/progress_py.txt"
NUM_PROCESSES = os.cpu_count()
NUM_CHARACTERS = 5
ABC = [list(string.ascii_lowercase) for i in range(NUM_CHARACTERS)]
COLORS = {"green": 0, "yellow": 1, "grey": 2}
NUM_COMBOS = pow(len(COLORS), NUM_CHARACTERS)
COLOR_COMBOS = []
for a in COLORS:
    for b in COLORS:
        for c in COLORS:
            for d in COLORS:
                for e in COLORS:
                    COLOR_COMBOS.append([COLORS[a], COLORS[b], COLORS[c], COLORS[d], COLORS[e]])
WORDS = {}
with open("data/wordle_list.txt", "r") as file:
    for line in file:
        WORDS[line.strip()] = 0
with open("data/unigram_freq.csv", "r") as file:
    file.readline()  # read and discard the first line
    for line in file:
        word, freq = line.strip().split(",")
        freq = int(freq)
        if len(word) == NUM_CHARACTERS and word in WORDS:
            WORDS[word] = freq


# 'BUSINESS LOGIC' FUNCTIONS
# builds a regular expression to subset the word list to possible remaining words.
# NOTE: this function edits remaining_letters in-place.
def build_regex(guess, combo, remaining_letters):
    yellow_letters = []
    greys = set()
    nongreys = set()
    for i in range(NUM_CHARACTERS):
        current_letter = guess[i]
        current_combo_val = combo[i]
        # green letters are set
        if current_combo_val == COLORS["green"]:
            nongreys.add(current_letter)
            remaining_letters[i] = [current_letter]
        # yellow letters are removed from the index at which they are found
        elif current_combo_val == COLORS["yellow"]:
            nongreys.add(current_letter)
            yellow_letters.append(current_letter)
            remaining_letters[i].remove(current_letter)
        # grey letters are removed from each index
        else:
            greys.add(current_letter)
            for j in range(NUM_CHARACTERS):
                if current_letter in remaining_letters[j]:
                    remaining_letters[j].remove(current_letter)
    if len(greys & nongreys) > 0:
        raise ValueError("Letters cannot be both grey and nongrey!")
    rgx_components = []
    for i in range(NUM_CHARACTERS):
        if len(remaining_letters[i]) == 0:
            raise ValueError("Out of letters available for regex!")
        rgx_components.append("[" + "".join(remaining_letters[i]) + "]")
    rgx = re.compile(r"".join(rgx_components))
    return [rgx, yellow_letters]


# take the user's guess and filter down to the remaining
# possible words based on the input and color combo for that input.
def guess_filter(guess, combo, remaining_words, remaining_letters):
    subset = {}
    try:
        rgx, yellow_letters = build_regex(guess, combo, remaining_letters)
    except ValueError:
        return subset
    for word in remaining_words:
        if rgx.search(word):
            # ensure results contain each of the yellow letters when yellow was in the combo
            if len(yellow_letters) > 0:
                all_yellow_letters_found = True
                for yellow_letter in yellow_letters:
                    all_yellow_letters_found = all_yellow_letters_found and (yellow_letter in word)
                if all_yellow_letters_found:
                    subset[word] = remaining_words[word]
            else:
                subset[word] = remaining_words[word]
    return subset


# the parallel part of calculate_scores
def calculate_scores_(iterable, information):
    guesses, remaining_words, remaining_letters, freq_total = iterable
    for guess in guesses:
        formatted_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S %Z')
        with open(LOGFILE, "a") as file:
            print(f"word: {guess}\ttime: {formatted_time}\n", end="", file=file)
        remaining_words_by_combo = []
        for i in range(len(COLOR_COMBOS)):
            filtered = guess_filter(guess,
                                    COLOR_COMBOS[i],
                                    remaining_words,
                                    copy.deepcopy(remaining_letters))
            if len(filtered) > 0:
                remaining_words_by_combo.append(filtered)
        # calculate expected bits of information gained
        expected_information = 0.0
        for i in range(len(remaining_words_by_combo)):
            combo_freq = sum(value for value in remaining_words_by_combo[i].values())
            proportion_of_words_remaining_for_this_combo = combo_freq / freq_total
            entropy = 0.0
            if proportion_of_words_remaining_for_this_combo > 0.0:
                entropy = math.log2(1.0 / proportion_of_words_remaining_for_this_combo)
            expected_information += proportion_of_words_remaining_for_this_combo * entropy
        information[guess] = expected_information


# calculate the bits of information gained for
# each guess after checking it against each color combination.
def calculate_scores(remaining_words, remaining_letters):
    freq_total = sum(value for value in remaining_words.values())
    words = list(remaining_words)
    numwords = len(words)
    words_each_process_is_responsible_for = []
    numwords_per_process = math.ceil(numwords / NUM_PROCESSES)
    start = 0
    for i in range(NUM_PROCESSES):
        words_each_process_is_responsible_for.append(words[start:(start + numwords_per_process)])
        start += numwords_per_process
        if(start + numwords_per_process > numwords):
            numwords_per_process = numwords_per_process - (numwords_per_process - numwords)
    iter = []
    for i in range(NUM_PROCESSES):
        iter.append([words_each_process_is_responsible_for[i],
                     remaining_words,
                     remaining_letters,
                     freq_total])
    if os.path.exists(LOGFILE):
        os.remove(LOGFILE)
    with multiprocessing.Pool(processes=NUM_PROCESSES) as pool:
        manager = multiprocessing.Manager()
        expected_information = manager.dict()
        pool.starmap(calculate_scores_,
                     [(elt, expected_information) for elt in iter]
                     )
    return dict(expected_information)


# UNIT TESTS
# this answer matches the build_regex call in play.R (after adding the re.compile call)
build_regex("helio", [1, 2, 2, 0, 1], copy.deepcopy(ABC))[0] == re.compile("[abcdfgijkmnopqrstuvwxyz][abcdfghijkmnopqrstuvwxyz][abcdfghijkmnopqrstuvwxyz][i][abcdfghijkmnpqrstuvwxyz]")
# these answers match the guess_filter call in play.R
"".join(guess_filter("ocean", [0, 0, 0, 0, 0], copy.deepcopy(WORDS), copy.deepcopy(ABC)).keys()) == "ocean"
"".join(guess_filter("ocean", [0, 0, 2, 0, 0], copy.deepcopy(WORDS), copy.deepcopy(ABC)).keys()) == "octan"
len(guess_filter("ocean", [0, 0, 1, 0, 0], copy.deepcopy(WORDS), copy.deepcopy(ABC))) == 0
# these answers match the calculate_scores call in play.R
testdict = {"aahed": WORDS["aahed"],
            "aalii": WORDS["aalii"],
            "aargh": WORDS["aargh"],
            "aarti": WORDS["aarti"],
            "abaca": WORDS["abaca"]}
outdict = calculate_scores(testdict, ABC)
round(outdict["aahed"], 1) == 1.6
round(outdict["aalii"], 1) == 1.6
round(outdict["aargh"], 1) == 1.6
round(outdict["aarti"], 1) == 1.6
round(outdict["abaca"], 1) == 1.0


# EXECUTION
scores = calculate_scores(WORDS, ABC)
outfile = "data/opening_word_scores.tsv"
if os.path.exists(outfile):
    os.remove(outfile)
with open(outfile, "a") as file:
    print("word\texpected_entropy\tfrequency", file=file)
    for word in scores:
        print(f"{word}\t{scores[word]}\t{WORDS[word]}", file=file)
