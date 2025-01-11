# WORDLE SOLVER
# 12/14/2023-12/15/2023
#
# The New York Times-owned game has a bug in it that could debatably be called a feature.
# When the user inputs a word with recurring letters (let's say the answer is "topic" and the
# user's guess was "apple"--a word for which there are two instances of the letter "p") where one
# of the recurring letters is in a matching position and the other is not (the first "p" of "apple" is
# in the wrong index while the second "p" of "apple" is in the same index as the "p" in "topic"),
# the letter that is in the matching position is marked green and the letter that is not is marked grey.
#
# I say this is a bug because the instructions are too ambiguous. Here's the help page, modified to make
# it nicer for text (* means green, ** means yellow, *** means grey):
#
#    How To Play
#    Guess the Wordle in 6 tries.
#
#        Each guess must be a valid 5-letter word.
#        The color of the tiles will change to show how close your guess was to the word.
#
#        Examples
#
#        W*   E*** A*** R*** Y***
#        W is in the word and in the correct spot.
#
#        P*** I**  L*** L*** S***
#        I is in the word but in the wrong spot.
#
#        V*** A*** G*** U*** E***
#        U is not in the word in any spot.
#
# The help screen leads one to think that the "p" marked grey should be yellow in the "topic"-"apple"
# example described above. I will be treating the solver as if this is the case.

# PACKAGES
library(doParallel)

# COMMAND LINE ARGUMENTS
run_calculation <- length(commandArgs(trailingOnly = TRUE)) > 0L # not very sophisticated

# IMPORTANT 'CONSTANTS'
num_characters <- 5L
abc <- rep(list(letters), num_characters)
colors <- c("green" = 0L, "yellow" = 1L, "grey" = 2L)
color_combos <- list(colors) |>
    rep(num_characters) |>
    expand.grid() |>
    as.matrix() |>
    unname()
# official acceptable answer list and unigram frequencies (frequencies as provided by google...i think it was google)
words <- local({
    words <- setNames(read.csv("data/wordle_list.txt", header = FALSE), "word")
    unigrams <- read.csv("data/unigram_freq.csv")
    combined <- merge(words, unigrams, on = "word", all.x = TRUE)
    counts <- as.integer(combined$count)
    counts[is.na(counts)] <- 0L
    structure(counts, names = combined$word)
})
split_words <- structure(strsplit(names(words), "", fixed = TRUE), names = names(words))

# HELPER FUNCTIONS
# fast and dangerous way of computing x[!x %in% y]
elim <- function(x, rmv){
    x[.Internal(match(x, rmv, 0L, NULL)) == 0L]
}
collapse_into_character_group <- function(lettervec){
    paste(c("[", lettervec, "]"), sep = "", collapse = "")
}
# uses a barebones grepl--fast and dangerous! built from the definition of grepl
str_subset <- function(str, patt, fixed = FALSE){
    str[.Internal(grepl(patt, str, FALSE, FALSE, FALSE, fixed, FALSE, FALSE))]
}
print_log_info <- function(guess, start_time, logfile = ""){
    msg <- sprintf("word: %s\tstart: %.6f\tend: %.6f\n", guess, start_time, Sys.time())
    cat(msg, file = logfile, append = TRUE)
}
# fast and dangerous duplicated.default, useful because it will be called many times on small vectors
duplicated <- function(x){
    .Internal(duplicated(x, FALSE, FALSE, NA))
}
# fast and dangerous unique.default, useful because it will be called many times on small vectors
uniq <- function(x){
    .Internal(unique(x, FALSE, FALSE, NA))
}
# fast and dangerous rowSums--i don't need to concern myself with all this silly error-checking
rowSums <- function (x, na.rm = FALSE, dims = 1L){
    .Internal(rowSums(x, nrow(x), ncol(x), FALSE))
}

# 'BUSINESS LOGIC' FUNCTIONS
# builds a regular expression to subset the word list to possible remaining words.
build_regex <- function(guess, combo, remaining_letters, colors){
    # green letters are set
    is_green <- combo == colors["green"]
    green_letters <- guess[is_green]
    remaining_letters[is_green] <- green_letters
    # yellow letters are removed from the index at which they are found
    is_yellow <- combo == colors["yellow"]
    yellow_letters <- guess[is_yellow]
    remaining_letters[is_yellow] <- Map(f = elim,
                                        x = remaining_letters[is_yellow],
                                        rmv = as.list(yellow_letters),
                                        USE.NAMES = FALSE)
    # grey letters are removed from each index
    grey_letters <- guess[combo == colors["grey"]]
    remaining_letters <- lapply(X = remaining_letters,
                                FUN = elim,
                                rmv = grey_letters)
    # NOTE: it should be impossible for a letter to be both grey and not grey
    # depending the position of the letter... this check is addressed upstream
    if(any(lengths(remaining_letters) == 0L)){
        stop("Out of letters available for regex!")
    }
    rgx <- paste(lapply(remaining_letters, collapse_into_character_group), collapse = "")
    list(remaining_letters = remaining_letters, rgx = rgx, is_yellow = is_yellow)
}
# take the user's guess and filter down to the remaining
# possible words based on the input and color combo for that input.
guess_filter <- function(guess, combo, remaining_words, remaining_letters, colors){
    tryCatch({
        rgx_info <- build_regex(guess = guess, combo = combo, remaining_letters = remaining_letters, colors = colors)
        remaining_letters <- rgx_info[["remaining_letters"]]
        rgx               <- rgx_info[["rgx"]]
        is_yellow         <- rgx_info[["is_yellow"]]
        remaining_words <- str_subset(names(remaining_words), rgx)
        # Ensure results contain all of the yellow letters when yellow was in the combo
        for(yellow_letter in guess[is_yellow]){
            remaining_words <- str_subset(remaining_words, yellow_letter, fixed = TRUE)
        }
        list(remaining_letters = remaining_letters, remaining_words = remaining_words)
    },
    error = function(cnd){
        list(remaining_letters = character(0L),
             remaining_words = structure(integer(0L), names = character(0L))
    )}
    )
}
# calculate the bits of information gained for
# each guess after checking it against each color combination.
calculate_scores <- function(color_combos, remaining_words, remaining_letters, colors, split_words, logfile){
    freq_total <- sum(remaining_words)
    cores <- as.integer(Sys.getenv("NUM_PROCESSES")) # parallel::detectCores()
    cl <- parallel::makeCluster(cores)
    doParallel::registerDoParallel(cl)
    on.exit(parallel::stopCluster(cl), add = TRUE)
    if(file.exists(logfile)) file.remove(logfile)
    foreach::foreach(guess = names(remaining_words),
                     .export = c("elim",
                                 "collapse_into_character_group",
                                 "str_subset",
                                 "print_log_info",
                                 "duplicated",
                                 "uniq",
                                 "rowSums",
                                 "build_regex",
                                 "guess_filter"),
                     .inorder = TRUE,
                     .combine = c,
                     .final = function(x) setNames(x, names(remaining_words))
                     ) %dopar% {
        start_time <- Sys.time()
        # filter out impossible color combos--a grey letter cannot also be green or yellow
        split_guess <- split_words[[guess]]
        repeating_letters <- uniq(split_guess[duplicated(split_guess)])
        is_valid_combo <- rep(TRUE, nrow(color_combos))
        for(repeating_letter in repeating_letters){
            letter_inds <- which(split_guess == repeating_letter)
            number_of_appearances <- length(letter_inds)
            number_of_greys_in_combo <- rowSums(color_combos[, letter_inds] == colors["grey"])
            is_valid_combo <- is_valid_combo & (number_of_greys_in_combo == 0L | number_of_greys_in_combo == number_of_appearances)
        }
        possible_combos <- color_combos[is_valid_combo, ]
        remaining_words_by_combo <- vector("list", nrow(possible_combos))
        for(i in seq_len(nrow(possible_combos))){
            remaining_words_by_combo[[i]] <- guess_filter(guess = split_guess,
                                                          combo = possible_combos[i, ],
                                                          remaining_words = remaining_words,
                                                          remaining_letters = remaining_letters,
                                                          colors = colors)[["remaining_words"]]
        }
        frequency_of_remaining_words_by_combo <- vapply(remaining_words_by_combo,
                                                        function(words_left) sum(remaining_words[words_left]),
                                                        double(1L),
                                                        USE.NAMES = FALSE)
        proportion_of_words_remaining <- frequency_of_remaining_words_by_combo / freq_total
        entropy <- log2(1 / proportion_of_words_remaining)
        entropy[is.infinite(entropy)] <- 0
        expected_information <- sum(proportion_of_words_remaining * entropy)
        print_log_info(guess = guess, start_time = start_time, logfile = logfile)
        expected_information
    }
}
# same as above, but in series (zero dependencies, easier to debug)
calculate_scores_series <- function(color_combos, remaining_words, remaining_letters, colors, split_words, ...){
    freq_total <-    sum(remaining_words)
    num_words  <- length(remaining_words)
    expected_information <- structure(double(num_words), names = names(remaining_words))
    for(guess in names(remaining_words)){
        start_time <- Sys.time()
        # filter out impossible color combos--a grey letter cannot also be green or yellow
        split_guess <- split_words[[guess]]
        repeating_letters <- uniq(split_guess[duplicated(split_guess)])
        is_valid_combo <- rep(TRUE, nrow(color_combos))
        for(repeating_letter in repeating_letters){
            letter_inds <- which(split_guess == repeating_letter)
            number_of_appearances <- length(letter_inds)
            number_of_greys_in_combo <- rowSums(color_combos[, letter_inds] == colors["grey"])
            is_valid_combo <- is_valid_combo & (number_of_greys_in_combo == 0L | number_of_greys_in_combo == number_of_appearances)
        }
        possible_combos <- color_combos[is_valid_combo, ]
        remaining_words_by_combo <- vector("list", nrow(possible_combos))
        for(i in seq_len(nrow(possible_combos))){
            remaining_words_by_combo[[i]] <- guess_filter(guess = split_guess,
                                                          combo = possible_combos[i, ],
                                                          remaining_words = remaining_words,
                                                          remaining_letters = remaining_letters,
                                                          colors = colors)[["remaining_words"]]
        }
        frequency_of_remaining_words_by_combo <- vapply(remaining_words_by_combo,
                                                        function(words_left) sum(remaining_words[words_left]),
                                                        double(1L),
                                                        USE.NAMES = FALSE)
        proportion_of_words_remaining <- frequency_of_remaining_words_by_combo / freq_total
        entropy <- log2(1 / proportion_of_words_remaining)
        entropy[is.infinite(entropy)] <- 0
        expected_information[guess] <- sum(proportion_of_words_remaining * entropy)
        print_log_info(guess = guess, start_time = start_time)
    }
    expected_information
}
# determine the next best guess to make after getting the color combo back from the game
update_scores <- function(guess, split_words, combo, remaining_words, remaining_letters, color_combos, colors, calculate_scores_fn){
    # only include words with a count greater than zero after the first guess
    remaining_words <- remaining_words[remaining_words > 0L]
    if(length(remaining_words) == 0L){
        return("You ran out of words!")
    }
    split_guess <- split_words[[guess]]
    updates <- guess_filter(guess = split_guess,
                            combo = combo,
                            remaining_words = remaining_words,
                            remaining_letters = remaining_letters,
                            colors = colors)
    remaining_words <- remaining_words[updates[["remaining_words"]]]
    remaining_letters <- updates[["remaining_letters"]]
    if(length(remaining_words) == 0L){
        stop("Out of words!")
    } else if(any(lengths(remaining_letters, use.names = FALSE) == 0L)){
        stop("Out of letters!")
    }
    new_scores <- calculate_scores_fn(color_combos = color_combos,
                                      remaining_words = remaining_words,
                                      remaining_letters = remaining_letters,
                                      colors = colors,
                                      split_words = split_words,
                                      logfile = "")
    best_guess <- names(new_scores[new_scores == max(new_scores)])[1L]
    list(remaining_letters = remaining_letters,
         remaining_words = remaining_words,
         new_scores = new_scores,
         best_guess = best_guess)
}

# EXECUTION
if(run_calculation || !file.exists("data/opening_word_scores.csv")){
    scores <- calculate_scores(color_combos = color_combos,
                               remaining_words = words,
                               remaining_letters = abc,
                               colors = colors,
                               split_words = split_words,
                               logfile = "log/progress_r.txt")
    data.frame(word = names(scores),
               expected_entropy = scores,
               frequency = words[names(scores)],
               row.names = NULL) |>
          write.csv(file = "data/opening_word_scores.csv",
                    quote = FALSE,
                    row.names = FALSE)
} else {
    scores <- local({
        word_info <- read.csv("data/opening_word_scores.csv")
        structure(word_info$expected_entropy, names = word_info$word)
    })
}
