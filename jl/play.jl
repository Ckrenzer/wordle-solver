using Base.Threads
using Dates # only used for logging

# IMPORTANT 'CONSTANTS'
const UTC_TO_LOCAL_DIFF = -(60 * 60 * 5)
const TZ = "EST"
const NUM_PROCESSES = Threads.nthreads()
const NUM_CHARACTERS = 5
const COLORS = Dict(:green => 0, :yellow => 1, :grey => 2)
const LETTERS = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]
abc = Vector{Array}(undef, NUM_CHARACTERS)
for i in 1:NUM_CHARACTERS
    abc[i] = LETTERS
end
const ABC = abc
const NUM_COMBOS = length(COLORS)^NUM_CHARACTERS
color_combos = Vector{Array}(undef, NUM_COMBOS)
global counter = 0
for i in keys(COLORS)
    for ii in keys(COLORS)
        for iii in keys(COLORS)
            for iv in keys(COLORS)
                for v in keys(COLORS)
                    global counter += 1
                    color_combos[counter] = [COLORS[i], COLORS[ii], COLORS[iii], COLORS[iv], COLORS[v]]
                end
            end
        end
    end
end
const COLOR_COMBOS = color_combos
words = open(io->read(io, String), "data/wordle_list.txt")
words = words[1:(length(words) - 1)] # remove trailing newline
words = string.(split(words, "\n"))
words = Dict{String, Int}(word => 0 for word in words)
unigrams = open(io->read(io, String), "data/unigram_freq.csv")
unigrams = split(unigrams, "\n")
unigrams = split.(unigrams, ",")[2:(length(unigrams) - 1)] # remove header, trailing newline
filter!(row->length(row[1]) == 5, unigrams)
for (word, freq) in unigrams
    if(word in keys(words))
        words[word] = parse(Int, freq)
    end
end
const WORDS = words
tz = nothing
abc = nothing
counter = nothing
color_combos = nothing
words = nothing
unigrams = nothing

# HELPER FUNCTIONS
collapse_into_character_groups = function(string_arr)
    "[" * join(string_arr) * "]"
end
generate_logfile_name = function(id)
    "log/progress_jl" * string(id) * ".txt"
end
format_time = function()
    formatted_datetime = Dates.unix2datetime(time() + UTC_TO_LOCAL_DIFF)
    Dates.format(formatted_datetime, "yyyy-mm-dd HH:MM:SS") * " " * TZ
end
print_log_info = function(path_logfile, guess, starttime)
    info = "word: " * guess * "\tstart: " * starttime * "\tend: " * format_time()
    open(path_logfile, "a+") do logfile
        println(logfile, info)
    end
end

# 'BUSINESS LOGIC' FUNCTIONS
# builds a regular expression to subset the word list to possible remaining words.
# NOTE: this function edits remaining_letters in-place.
build_regex = function(guess, combo, remaining_letters)
    yellow_letters = []
    greys = Set()
    nongreys = Set()
    for i in 1:NUM_CHARACTERS
        current_letter = string(guess[i])
        current_combo_val = combo[i]
        # green letters are set
        if current_combo_val == COLORS[:green]
            push!(nongreys, current_letter)
            remaining_letters[i] = [string(current_letter)]
        # yellow letters are removed from the index at which they are found
        elseif current_combo_val == COLORS[:yellow]
            push!(nongreys, current_letter)
            push!(yellow_letters, current_letter)
            filter!(letter->letter != current_letter, remaining_letters[i])
        # grey letters are removed from each index
        else
            push!(greys, current_letter)
            filter!.(letter->letter != current_letter, remaining_letters)
        end
    end
    # this is a fine check to have, but the color combos are already checked upstream
    if any(grey -> grey ∈ nongreys, greys)
        error("Letters cannot be both grey and nongrey!")
    end
    if any(letter_arr -> length(letter_arr) == 0, remaining_letters)
        error("Out of letters available for regex!")
    end
    rgx = Regex(join(collapse_into_character_groups.(remaining_letters)))
    [rgx, yellow_letters]
end
# take the user's guess and filter down to the remaining
# possible words based on the input and color combo for that input.
guess_filter = function(guess, combo, remaining_words, remaining_letters)
    subset = Dict{String, Int}()
    rgx = nothing
    yellow_letters = nothing
    try
        rgx, yellow_letters = build_regex(guess, combo, remaining_letters)
    catch
        return subset
    end
    for word in keys(remaining_words)
        if contains(word, rgx) & all(occursin.(yellow_letters, word))
            subset[word] = remaining_words[word]
        end
    end
    subset
end
# calculate the bits of information gained for
# each guess after checking it against each color combination.
calculate_scores = function(remaining_words, remaining_letters, consolidate_logsp)
    # prepare iterator
    freq_total = sum(values(remaining_words))
    words = string.(keys(remaining_words))
    numwords = length(words)
    words_each_process_is_responsible_for = Vector{Array}(undef, NUM_PROCESSES)
    numwords_per_process = Int(ceil(numwords / NUM_PROCESSES))
    start = 1
    for i in 1:NUM_PROCESSES
        word_elts = start:(start + numwords_per_process - 1)
        words_each_process_is_responsible_for[i] = [words[word_elts], collect(word_elts)]
        start += numwords_per_process
        if(start + numwords_per_process > numwords)
            numwords_per_process = numwords - (start - 1)
        end
    end

    # storing results in a dict
    expected_information = Vector{Float64}(undef, numwords)
    Threads.@threads for iter in 1:NUM_PROCESSES
        iter_vals = words_each_process_is_responsible_for[iter]
        guesses, inds = iter_vals
        logfile = generate_logfile_name(iter)
        open(logfile, "w") # create log

        for elt in 1:length(guesses)
            guess_start_time = format_time()
            guess = guesses[elt]
            remaining_words_by_combo = []
            for i in eachindex(COLOR_COMBOS)
                filtered = [keys(guess_filter(guess, COLOR_COMBOS[i], remaining_words, deepcopy.(remaining_letters)))]
                if(length(filtered[1]) > 0)
                    append!(remaining_words_by_combo, filtered)
                end
            end

            # calculate expected bits of information gained
            info = 0
            for i in 1:length(remaining_words_by_combo)
                combo_freq = 0
                for remaining_word in remaining_words_by_combo[i]
                    combo_freq += sum(remaining_words[remaining_word])
                end
                proportion_of_words_remaining_for_this_combo = combo_freq / freq_total
                entropy = ifelse(proportion_of_words_remaining_for_this_combo > 0,
                                 log2(1 / proportion_of_words_remaining_for_this_combo),
                                 0)
                info += proportion_of_words_remaining_for_this_combo * entropy
            end
            expected_information[inds[elt]] = info
            print_log_info(logfile, guess, guess_start_time)
        end
    end
    # store results in dictionary
    expected_information_dict = Dict{String, Float64}()
    for i in 1:numwords
        guess = words[i]
        expected_information_dict[guess] = expected_information[i]
    end

    # consolidate logs
    outfile = generate_logfile_name("")
    logfiles = generate_logfile_name.(1:NUM_PROCESSES)
    if(consolidate_logsp)
        open(outfile, "w") do outfile
            for logfile in logfiles
                open(logfile, "r") do logfiles
                    write(outfile, read(logfile, String))
                end
            end
        end
    end
    rm.(logfiles)

    expected_information_dict
end

# UNIT TESTS
# build_regex
build_regex("ocean", [0, 0, 0, 0, 0], deepcopy.(ABC)) == [Regex("[o][c][e][a][n]"), []]
build_regex("ocean", [1, 1, 1, 1, 1], deepcopy.(ABC)) == [Regex("[abcdefghijklmnpqrstuvwxyz][abdefghijklmnopqrstuvwxyz][abcdfghijklmnopqrstuvwxyz][bcdefghijklmnopqrstuvwxyz][abcdefghijklmopqrstuvwxyz]"), ["o", "c", "e", "a", "n"]]
build_regex("ocean", [2, 2, 2, 2, 2], deepcopy.(ABC)) == [Regex("[bdfghijklmpqrstuvwxyz][bdfghijklmpqrstuvwxyz][bdfghijklmpqrstuvwxyz][bdfghijklmpqrstuvwxyz][bdfghijklmpqrstuvwxyz]"), []]
build_regex("ocean", [0, 1, 2, 2, 2], deepcopy.(ABC)) == [Regex("[o][bdfghijklmopqrstuvwxyz][bcdfghijklmopqrstuvwxyz][bcdfghijklmopqrstuvwxyz][bcdfghijklmopqrstuvwxyz]"), ["c"]]
build_regex("helio", [1, 2, 2, 0, 1], deepcopy.(ABC)) == [Regex("[abcdfgijkmnopqrstuvwxyz][abcdfghijkmnopqrstuvwxyz][abcdfghijkmnopqrstuvwxyz][i][abcdfghijkmnpqrstuvwxyz]"), ["h", "o"]]
# guess_filter
guess_filter("ocean", [0, 0, 0, 0, 0], WORDS, deepcopy.(ABC)) == Dict("ocean" => WORDS["ocean"])
guess_filter("ocean", [0, 0, 1, 0, 0], WORDS, deepcopy.(ABC)) == Dict{String, Int}()
guess_filter("ocean", [0, 0, 2, 0, 0], WORDS, deepcopy.(ABC)) == Dict("octan" => WORDS["octan"])
# calculate_scores
testdict = Dict("aahed" => WORDS["aahed"],
                "aalii" => WORDS["aalii"],
                "aargh" => WORDS["aargh"],
                "aarti" => WORDS["aarti"],
                "abaca" => WORDS["abaca"])
outdict = calculate_scores(testdict, ABC, false)
round(outdict["aahed"]; digits = 1) == 1.6
round(outdict["aalii"]; digits = 1) == 1.6
round(outdict["aargh"]; digits = 1) == 1.6
round(outdict["aarti"]; digits = 1) == 1.6
round(outdict["abaca"]; digits = 1) == 1.0

# EXECUTION
scores = calculate_scores(WORDS, ABC, true)
scores_file = "data/opening_word_scores.tsv"
open(scores_file, "w") do scores_file
    write(scores_file, "word\texpected_entropy\tfrequency\n")
    for (k,v) in scores
        line = string(k) * "\t" * string(v) * "\t" * string(WORDS[k]) * "\n"
        write(scores_file, line)
    end
end