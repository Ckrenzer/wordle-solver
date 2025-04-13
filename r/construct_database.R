#!/usr/bin/Rscript
# references to 'powers of 2' refer to encoding sets of letters or words into
# arbitrarily-large integers using sums of powers of 2 inspired by unix file
# permissions. this is done to represent sets of letters or words as scalars
# rather than needing to build out large tables that store every combination
# in the game. this cuts down on disk space, database query execution time,
# and the number of tables needed in the database (simplification!). sums
# of powers of 2 can be decomposed in exactly one way.
#
# Ex. 15 can be decomposed into the following powers of 2:
#         8  +  4  +  2  +  1  = 15
#        2^3   2^2   2^1   2^0
#         d     c     b     a
# if you associate values with the powers of 2, you have an efficient lookup
# system. 15 here represents the set of letters [a, b, c, d].

library(data.table)
library(parallelly)
library(doParallel)
library(foreach)
library(DBI)
library(RSQLite)
library(gmp)


# CONSTRUCT DATABASE
db_file <- "db/wordle.sqlite3"
tryCatch({
    dbconn <- DBI::dbConnect(RSQLite::SQLite(), db_file)
    DBI::dbExecute(dbconn, "
        -- integer-to-color mapping.
        CREATE TABLE IF NOT EXISTS colors (
            representation INTEGER,
            color TEXT,
            PRIMARY KEY (representation),
            -- color cannot be part of a composite key alongside representation since
            -- it is the representation that determines the color, not the combination
            -- of representation and color. But each representation must represent
            -- exactly one color, hence the UNIQUE constraint.
            UNIQUE (color)
        );
    ")
    DBI::dbExecute(dbconn, "
        -- stores all (num_colors)^(num_characters_in_guess) color combos.
        CREATE TABLE IF NOT EXISTS color_combos (
            combo_id INTEGER,
            letter_position INTEGER,
            representation INTEGER,
            PRIMARY KEY (combo_id, letter_position),
            FOREIGN KEY (representation) REFERENCES colors(representation)
        );
    ")
    DBI::dbExecute(dbconn, "
        -- words and the amount of uses in the English language
        -- according to...Google, I think.
        CREATE TABLE IF NOT EXISTS unigram_frequency (
            word TEXT,
            frequency INTEGER,
            -- formalizes the values used to represent a given word in a set.
            -- storing as text because these values are arbitrarily-large.
            -- disk space is not a concern since this table is relatively
            -- small.
            power_of_2 TEXT,
            PRIMARY KEY (word),
            -- the power of 2 must tie to exactly one word. using smaller
            -- numbers is much more managable than arbitrarily-large powers of
            -- 2, so you may wish to revise this constraint to make it unique
            -- within a word length rather than globally unique.
            UNIQUE (power_of_2)
        );
    ")
    DBI::dbExecute(dbconn, "
        -- determines whether a color combo is possible for the given word
        -- Ex. the colors for 'll' in 'pulls' cannot be yellow and grey, respectively;
        --     that constitutes an invalid color combo.
        CREATE TABLE IF NOT EXISTS combo_validity (
            guess TEXT,
            combo_id INTEGER,
            combo_is_possible INTEGER,
            PRIMARY KEY (guess, combo_id),
            FOREIGN KEY (guess) REFERENCES unigram_frequency(word),
            FOREIGN KEY (combo_id) REFERENCES color_combos(combo_id)
        );
    ")
    DBI::dbExecute(dbconn, "
        -- formalizes the encoding used to produce remaining_letters' letter_set_id
        -- column. the power_of_2 value zero (which makes this column a bit of a
        -- misnomer since zero isn't a power of 2) denotes the empty set of letters.
        CREATE TABLE IF NOT EXISTS letter_values (
            letter_position INTEGER,
            letter TEXT,
            -- formalizes the values used to represent a given letter and
            -- position in a set.
            -- storing as text because these values are arbitrarily-large.
            -- disk space is not a concern since this table is relatively
            -- small.
            power_of_2 TEXT,
            PRIMARY KEY (letter_position, letter, power_of_2),
            -- the power of 2 must tie to exactly one letter-position combo.
            -- using smaller numbers is much more managable than
            UNIQUE(power_of_2)
        );
    ")
    DBI::dbExecute(dbconn, "
        -- this table stores combinations of guess, color combo, and guess
        -- numbers to represent a node along a tree of guesses.
        CREATE TABLE IF NOT EXISTS outcome_ids (
            current_guess_id INTEGER PRIMARY KEY AUTOINCREMENT,
            previous_guess_id INTEGER,
            current_guess_num INTEGER,
            current_guess TEXT,
            current_combo_id INTEGER,
            -- these could be stored as text (SQLite does not support
            -- arbitrarily-large integers), but I'm being a cheapo because I
            -- found that raw bytes consume 1/3 the disk space as an equivalent
            -- string.
            -- stores the whole numbers as binary data in little-endian format.
            -- processing and decoding is pretty quick.
            --
            -- a major shortcoming of storing raw bytes instead of using integers
            -- is that it becomes prohibitively difficult to add a constraint
            -- checking that the value is a whole number that can be decomposed
            -- by the powers of 2 in the corresponding lookup tables. A different
            -- database would be needed to implement such logic (duckdb and its
            -- VARINT is a likely contender).
            remaining_words_set_id BLOB,
            remaining_letters_set_id BLOB,
            FOREIGN KEY (previous_guess_id) REFERENCES outcome_ids(current_guess_id),
            FOREIGN KEY (current_guess, current_combo_id) REFERENCES combo_validity(guess, combo_id),
            CONSTRAINT node_info_within_tree_is_unique UNIQUE (previous_guess_id,
                                                               current_guess_num,
                                                               current_guess,
                                                               current_combo_id)
            );
    ")


    # IMPORTANT VARIABLES
    num_characters <- 5L
    abc <- rep(list(letters), num_characters)


    # TABLES (helper functions and other objects interspersed)
    # official acceptable answer list and corresponding unigram frequencies.
    word_table <- local({
        words <- data.table::fread("data/wordle_list.txt", header = FALSE)
        data.table::setnames(words, "word")
        unigrams <- data.table::fread("data/unigram_freq.csv")
        words <- merge(words, unigrams, by = "word", all.x = TRUE)
        words[, count := as.integer(count)]
        data.table::setnafill(words, type = "const", fill = 0L, cols = "count")
        data.table::setkey(words, "word")
        # values used when encoding words into a set.
        # do this in a group by if extended to games of differing word lengths.
        words[, power_of_2 := as.character(gmp::pow.bigz(2L, seq_len(.N) - 1L))]
        words
    })
    DBI::dbWriteTable(dbconn, "unigram_frequency", word_table, overwrite = TRUE, append = FALSE, row.names = FALSE)
    # helper.
    split_words <- structure(strsplit(word_table[["word"]], "", fixed = TRUE), names = word_table[["word"]])

    # mapping between color and its integer representation.
    color_table <- data.table::data.table(representation = 0L:2L,
                                          color = c("green", "yellow", "grey"))
    DBI::dbWriteTable(dbconn, "colors", color_table, overwrite = TRUE, append = FALSE, row.names = FALSE)

    # all color combos.
    color_combo_table <- local({
        color_combos <- replicate(n = num_characters, color_table[["representation"]], simplify = FALSE)
        color_combos <- data.table::as.data.table(expand.grid(color_combos))
        color_columns <- seq_len(num_characters)
        data.table::setnames(color_combos, as.character(color_columns))
        color_combos[, combo_id := .I]
        color_combos <- data.table::melt(color_combos,
                                         id.vars = "combo_id",
                                         measure.vars = color_columns,
                                         variable.factor = FALSE,
                                         variable.name = "letter_position",
                                         value.name = "representation")
        color_combos[, letter_position := as.integer(letter_position)]
        data.table::setkey(color_combos, "combo_id")
        color_combos[]
    })
    DBI::dbWriteTable(dbconn, "color_combos", color_combo_table, overwrite = TRUE, append = FALSE, row.names = FALSE)
    # filter down to those combos matching the number of letters in a guess
    # (color_combo_table is generalizable to any word length).
    filter_to_relevant_combos <- function(color_combos, num_characters_in_guess){
        relevant_combos <- color_combos[, .(maxpos = max(letter_position)), .(combo_id)]
        relevant_combos <- relevant_combos[maxpos == num_characters_in_guess, .(combo_id)]
        # filter down to the combos for the num_character_in_guess games
        relevant_combos <- merge(color_combos, relevant_combos, by = "combo_id", all.x = FALSE)
        data.table::setorderv(relevant_combos, c("combo_id", "letter_position"))
        relevant_combos
    }

    # identify impossible color combos--a grey letter cannot also be green or yellow.
    combo_validity_table <- local({
        words <- word_table[["word"]]
        color_combo_table <- filter_to_relevant_combos(color_combo_table, num_characters)
        color_combo_table <- color_combo_table[, .(combo_id, representation)]
        num_combos <- color_combo_table[, length(unique(combo_id))]
        grey_representation <- color_table[color == "grey", representation]
        is_valid_combo <- rep(TRUE, num_combos)
        inds <- seq_along(is_valid_combo)
        out <- lapply(words,
                      function(guess){
                          split_guess <- split_words[[guess]]
                          repeating_letters <- unique(split_guess[duplicated(split_guess)])
                          for(repeating_letter in repeating_letters){
                              is_repeat <- split_guess == repeating_letter
                              number_of_appearances <- sum(is_repeat)
                              number_of_greys_in_combo <- color_combo_table[, .(number_of_greys_in_combo = sum(representation[is_repeat] == grey_representation)), .(combo_id)]
                              number_of_greys_in_combo <- number_of_greys_in_combo[, number_of_greys_in_combo]
                              is_valid_combo <- is_valid_combo & (number_of_greys_in_combo == 0L | number_of_greys_in_combo == number_of_appearances)
                          }
                          data.table::data.table(guess = guess,
                                                 combo_id = inds,
                                                 combo_is_possible = is_valid_combo)
                      }) |>
        data.table::rbindlist(use.names = FALSE, fill = FALSE, ignore.attr = FALSE)
        data.table::setkey(out, "guess")
        out
    })
    DBI::dbWriteTable(dbconn, "combo_validity", combo_validity_table, overwrite = TRUE, append = FALSE, row.names = FALSE)

    # values used when encoding letters into a set.
    letter_values_table <- local({
        letter_positions <- rep(seq_len(num_characters),
                                each = length(letters))
        letter_vec <- rep(letters, times = num_characters)
        powers_of_2 <- gmp::pow.bigz(2L, seq_len(length(letters) * num_characters) - 1L)
        powers_of_2 <- as.character(powers_of_2)
        data.table::data.table(letter_position = c(0L, letter_positions),
                               letter = c("", letter_vec),
                               power_of_2 = c("0", powers_of_2))
    })
    data.table::setkeyv(letter_values_table, c("letter_position", "letter", "power_of_2"))
    DBI::dbWriteTable(dbconn, "letter_values", letter_values_table, overwrite = TRUE, append = FALSE, row.names = FALSE)
    # this is useful for encoding values
    letter_encoding_lookup <- local({
        nozero <- letter_values_table[power_of_2 != "0"]
        letter_vec <- nozero[, unique(letter)]
        powers <- split(nozero[, power_of_2],
                        (seq_len(nrow(nozero)) - 1L) %/% length(letter_vec))
        unname(lapply(powers, function(elt) structure(elt, names = letter_vec)))
    })
    # decoding doesn't require a names attribute, only a properly-ordered vector
    letter_decoding_lookup <- letter_values_table[power_of_2 != "0", letter]

}, finally = {
    DBI::dbDisconnect(dbconn)
})


# FUNCTIONS
# fast and dangerous way of computing x[!x %in% y].
# <<only used by build_regex>>
elim <- function(x, rmv){
    x[.Internal(match(x, rmv, 0L, NULL)) == 0L]
}
# <<only used by build_regex>>
collapse_into_character_group <- function(lettervec){
    paste(c("[", lettervec, "]"), sep = "", collapse = "")
}
# builds a regular expression to subset the word list to possible remaining words.
build_regex <- function(guess, combo, remaining_letters, colors){
    # green letters are set.
    is_green <- combo == colors["green"]
    green_letters <- guess[is_green]
    remaining_letters[is_green] <- green_letters
    # yellow letters are removed from the index at which they are found.
    is_yellow <- combo == colors["yellow"]
    yellow_letters <- guess[is_yellow]
    remaining_letters[is_yellow] <- Map(f = elim,
                                        x = remaining_letters[is_yellow],
                                        rmv = as.list(yellow_letters),
                                        USE.NAMES = FALSE)
    # grey letters are removed from each index.
    grey_letters <- guess[combo == colors["grey"]]
    remaining_letters <- lapply(X = remaining_letters,
                                FUN = elim,
                                rmv = grey_letters)
    # NOTE: it should be impossible for a letter to be both grey and not grey
    # depending the position of the letter... this check is addressed upstream.
    if(any(lengths(remaining_letters) == 0L)){
        stop("Out of letters available for regex!")
    }
    rgx <- paste(lapply(remaining_letters, collapse_into_character_group), collapse = "")
    list(remaining_letters = remaining_letters, rgx = rgx, is_yellow = is_yellow)
}

# uses a barebones grepl--fast and dangerous! built from the definition of grepl.
# as for the name...what can I say? I like stringr!
# <<only used by guess_filter>>
str_subset <- function(str, patt, fixed = FALSE){
    str[.Internal(grepl(patt, str, FALSE, FALSE, FALSE, fixed, FALSE, FALSE))]
}
# take the user's guess and filter down to the remaining
# possible words based on the input and color combo for that input.
guess_filter <- function(guess, combo, remaining_words, remaining_letters, colors, num_characters_in_guess){
    tryCatch({
        rgx_info <- build_regex(guess = guess, combo = combo, remaining_letters = remaining_letters, colors = colors)
        remaining_letters <- rgx_info[["remaining_letters"]]
        rgx               <- rgx_info[["rgx"]]
        is_yellow         <- rgx_info[["is_yellow"]]
        remaining_words <- str_subset(remaining_words, rgx)
        # Ensure results contain all of the yellow letters when yellow was in the combo.
        for(yellow_letter in guess[is_yellow]){
            remaining_words <- str_subset(remaining_words, yellow_letter, fixed = TRUE)
        }
        list(letters = remaining_letters, words = remaining_words)
    },
    error = function(cnd){
        list(letters = lapply(seq_len(num_characters_in_guess), function(i) character(0L)),
             words = character(0L))
    })
}

# helpers to filter down to the combos for the num_character_in_guess games.
color_combos_in_game <- filter_to_relevant_combos(color_combo_table, num_characters)
color_combos_in_game[, ordinal_id := .GRP, .(combo_id)] # used to look up combo id using a sequence staring
                                                        # at 1 in a for loop (needed if color_combos has data
                                                        # for more than one num_characters value).
compute_outcomes <- local({
    color_combo_ids <- color_combos_in_game[, .(combo_id = combo_id[1L]), .(ordinal_id)][, combo_id]
    color_combo_representations <- split(color_combos_in_game, by = "ordinal_id", keep.by = FALSE, sorted = TRUE)
    color_combo_representations <- lapply(color_combo_representations, function(tbl) tbl[, representation])
    combo_validity_by_word_in_game <- merge(combo_validity_table,
                                            unique(color_combos_in_game[, .(combo_id)]),
                                            by = "combo_id",
                                            all.x = TRUE)
    combo_validity_by_word_in_game <- split(combo_validity_by_word_in_game, by = "guess", keep.by = FALSE)
    combo_validity_by_word_in_game <- lapply(combo_validity_by_word_in_game, `[[`, "combo_is_possible")
    color_lookup_vec <- color_table[, structure(representation, names = color)]
    # computes the leaf nodes and their metadata for a single node along a tree of guesses.
    function(previous_guess_id,
             guess_num,
             remaining_letters,
             remaining_words,
             letter_lookup, # this doesn't change but gets passed from higher on the stack.
             word_lookup,   # this doesn't change but gets passed from higher on the stack.
             # the objects set as defaults do not change, but I do not want to
             # reference global vars or vars defined outside the function without passing
             # them in as parameters.
             game_combo_ids = color_combo_ids,
             color_lookup = color_lookup_vec,
             num_characters_in_guess = num_characters,
             split_guesses = split_words,
             game_combo_representations = color_combo_representations,
             is_valid_combo_by_word = combo_validity_by_word_in_game){
        # iterator prep.
        num_combos <- length(color_lookup)^num_characters_in_guess
        is_valid_combo_by_word <- is_valid_combo_by_word[remaining_words]
        split_guesses <- split_guesses[remaining_words]
        # NOTE: must already have a cluster registered with R for this to work.
        # for each word, this foreach loop computes the remaining outcomes for each color combo.
        guess_info <- foreach::foreach(guess = remaining_words,
                                       split_guess = split_guesses,
                                       is_valid_combo = is_valid_combo_by_word,
                                       .export = c("elim", # build_regex helper.
                                                   "collapse_into_character_group", # build_regex helper.
                                                   "build_regex",
                                                   "str_subset", # guess_filter helper.
                                                   "guess_filter"),
                                       .packages = c("data.table", "gmp"),
                                       .inorder = FALSE,
                                       .combine = rbind,
                                       .errorhandling = "stop") %dopar% {
            outcome_id_tables <- vector("list", num_combos)
            for(i in seq_along(game_combo_ids)){
                if(is_valid_combo[[i]]){
                    remaining <- guess_filter(guess = split_guess,
                                              combo = game_combo_representations[[i]],
                                              remaining_words = remaining_words,
                                              remaining_letters = remaining_letters,
                                              colors = color_lookup,
                                              num_characters_in_guess = num_characters_in_guess)
                    # this is the only place that uses the encodings, so it makes
                    # sense to compute the IDs here rather than in guess_filter.
                    letter_set_id <- list(Reduce(`+`,
                                                 Map(function(lettrs, lookup) sum(gmp::as.bigz(lookup[lettrs])),
                                                     remaining[["letters"]],
                                                     letter_lookup)))
                    word_set_id <- word_lookup[remaining[["words"]]] |> gmp::sum.bigz() |> list()
                    rm(remaining)
                } else {
                    letter_set_id <- word_set_id <- list(as.bigz("0"))
                }
                outcome_id_tables[[i]] <- data.table::data.table(previous_guess_id = previous_guess_id,
                                                                 current_guess_num = guess_num,
                                                                 current_guess = guess,
                                                                 current_combo_id = game_combo_ids[[i]],
                                                                 remaining_words_set_id = word_set_id,
                                                                 remaining_letters_set_id = letter_set_id)
            }
            data.table::rbindlist(outcome_id_tables, use.names = FALSE, fill = FALSE, ignore.attr = FALSE)
        }
        guess_info
    }
})

# return the powers of 2 that sum to the input (whole numbers only).
# <<only used by base2_decode>>
base2_decomposition <- function(number){
    UseMethod("base2_decomposition")
}
base2_decomposition.integer <- function(number) {
    powers_of_2 <- integer(0L)
    power <- 1L
    while (number > 0L) {
        if (number %% 2L == 1L) {
            powers_of_2 <- c(powers_of_2, power)
        }
        number <- number %/% 2L
        power <- power * 2L
    }
    powers_of_2
}
base2_decomposition.bigz <- function(number) {
    zero <- gmp::as.bigz("0")
    if(number == zero) return(zero)
    one <- gmp::as.bigz("1")
    two <- gmp::as.bigz("2")
    power <- one
    powers_of_2 <- gmp::as.bigz(character(0L))
    while (number > zero) {
        if (mod.bigz(number, two) == one) {
            powers_of_2 <- c(powers_of_2, power)
        }
        number <- gmp::divq.bigz(number, two)
        power <- gmp::mul.bigz(power, two)
    }
    powers_of_2
}
base2_decomposition.character <- base2_decomposition.bigz
# decompose a whole number into a sum of powers of 2,
# represent the decomposed values as a sequence into a vector,
# and use this sequence to extract the elements of the vector represented by
# the whole number, splitting into appropriate data structure for set_id_type.
# <<only used by process_outcomes>>
base2_decode <- function(set_id,
                         set_id_type, # one of "word" or "letter"
                         ordered_vector){
    # the log2(x) + 1 operation converts the powers-of-2 decomposed number into
    # an index (plus one due to 1-based indexing in R).
    #
    # log2 is a generic for bigz objects and seems to always return a double.
    if(set_id_type == "word"){
        decomp <- base2_decomposition(set_id)
        if(any(decomp == "0")){
            out <- character(0L)
        } else {
            out <- ordered_vector[log2(decomp) + 1]
        }
    } else if(set_id_type == "letter") {
        # it doesn't matter if the decomp messes up due to there being
        # no remaining letters in a given letter position since this
        # object is never used when that is the case. therefore, no
        # checks for the validity of the set id are required.
        inds <- log2(base2_decomposition(set_id))
        out <- unname(split(ordered_vector[inds + 1],
                            inds %/% length(letters)))
    } else {
        stop("argument 'set_id_type' is not one of \"word\" or \"letter\"!")
    }
    out
}
# traverse each tree of guesses and write the results to the database.
process_outcomes <- function(parent_id,
                             parent_combo_id,
                             current_guess_num,
                             letters_that_remain, words_that_remain, dbconn,
                             letter_enc_lookup = letter_encoding_lookup,
                             letter_dec_lookup = letter_decoding_lookup,
                             word_enc_lookup = word_table[, structure(power_of_2, names = word)],
                             word_dec_lookup = names(word_enc_lookup),
                             game_ending_combo_id = color_combos_in_game[ordinal_id == 1L, combo_id[1L]]){
    # end traversal at terminal nodes in the tree of guesses (game-ending guesses).
    # if the parent node doesn't have a remaining word, the game is over. if the
    # last combo was all green (indicating the correct answer has been input),
    # the game is over.
    if(parent_combo_id == game_ending_combo_id || length(words_that_remain) == 0L){
        # we do not need to return anything since we call this function for its
        # side-effects (populating the database with data about each node in
        # the trees of guesses).
        return()
    }
    # compute outcomes for the current node
    outcomes <- compute_outcomes(previous_guess_id = parent_id,
                                 guess_num = current_guess_num,
                                 remaining_letters = letters_that_remain,
                                 remaining_words = words_that_remain,
                                 letter_lookup = letter_enc_lookup,
                                 word_lookup = word_enc_lookup)
    # update database and determine which current_guess_id values to check in
    # the recursive calls.
    autoincrement_sql <- "SELECT seq FROM sqlite_sequence WHERE name = 'outcome_ids';"
    if(current_guess_num == 1L){
        last_node_before_insertion <- 0L
    } else {
        last_node_before_insertion <- dbGetQuery(dbconn, autoincrement_sql)[[1L]]
    }
    DBI::dbWriteTable(dbconn, "outcome_ids", outcomes, overwrite = FALSE, append = TRUE, row.names = FALSE)
    last_node_after_insertion <- dbGetQuery(dbconn, autoincrement_sql)[[1L]]
    outcome_ids_to_check <- (last_node_before_insertion + 1L):last_node_after_insertion
    # allow garbage collector to free RAM
    rm(outcomes, last_node_before_insertion, last_node_after_insertion)
    # R doesn't like it when parameters pass themselves in recursive calls.
    game_finishing_combo_id <- game_ending_combo_id
    letter_encode_lookup <- letter_enc_lookup
    letter_decode_lookup <- letter_dec_lookup
    word_encode_lookup <- word_enc_lookup
    word_decode_lookup <- word_dec_lookup
    db <- dbconn
    # traverse the trees of guesses, checking each outcome one by one.
    outcomes_sql <- "
        SELECT current_combo_id,
               remaining_words_set_id,
               remaining_letters_set_id
        FROM outcome_ids
        WHERE current_guess_id = :outcome_id_to_check
    "
    for(outcome_id_to_check in outcome_ids_to_check){
        next_outcome_id <- dbGetQuery(dbconn,
                                      outcomes_sql,
                                      params = list(outcome_id_to_check = outcome_id_to_check))
        combo_id_of_outcome <- next_outcome_id[["current_combo_id"]]
        remaining_words <- next_outcome_id[["remaining_words_set_id"]][[1L]]
        remaining_words <- base2_decode(gmp::as.bigz(remaining_words),
                                        set_id_type = "word",
                                        word_dec_lookup)
        remaining_letters <- next_outcome_id[["remaining_letters_set_id"]][[1L]]
        remaining_letters <- base2_decode(gmp::as.bigz(remaining_letters),
                                          set_id_type = "letter",
                                          letter_dec_lookup)
        rm(next_outcome_id)
        process_outcomes(parent_id = outcome_id_to_check, # unique node identifier (passed as previous_guess_id to compute_outcomes)
                         parent_combo_id = combo_id_of_outcome, # used by recursive call to process_outcomes to determine if this was a game-ending combo (all greens)
                         current_guess_num = current_guess_num + 1L,
                         letters_that_remain = remaining_letters,
                         words_that_remain = remaining_words,
                         # those params that are passing themselves down the call stack:
                         dbconn = db,
                         letter_enc_lookup = letter_encode_lookup,
                         letter_dec_lookup = letter_decode_lookup,
                         word_enc_lookup = word_encode_lookup,
                         word_dec_lookup = word_decode_lookup,
                         game_ending_combo_id = game_finishing_combo_id)
    }
}

local({
    # note that this compute cluster is specific to my SSH config, so your cluster
    # would need different configurations for `ip` and `user` in order to work.
    num_cores <- c(localhost = 12L, optiplex = 4L, aspire = 0L)
    ip <- rep(names(num_cores), num_cores)
    user <- rep(c("ckrenzer", "ckserver", "ckserver"), num_cores)
    docker_image_name <- "ckrenzer/cluster-r:data.table" # on DockerHub
    cl <- parallelly::makeClusterPSOCK(ip, user = user,
                                       # launch Rscript inside Docker container.
                                       rscript = c("docker",
                                                   "run",
                                                   "--rm",
                                                   "--network=host",
                                                   docker_image_name,
                                                   "Rscript"),
                                       dryrun = FALSE,
                                       quiet = FALSE)
    on.exit(parallel::stopCluster(cl), add = TRUE)
    doParallel::registerDoParallel(cl)
    if(file.exists("log/db_compute_times.log")) {
        file.remove("log/db_compute_times.log")
    }
    # compute all outcomes in a tree of guesses.
    con <- DBI::dbConnect(RSQLite::SQLite(), db_file)
    on.exit(DBI::dbDisconnect(con), add = TRUE)
    words <- word_table[["word"]]
    process_outcomes(parent_id = NA_integer_, # passed as previous_guess_id to compute_outcomes
                     parent_combo_id = 0L,
                     current_guess_num = 1L,  # depth of node in tree
                     letters_that_remain = abc,
                     words_that_remain = words,
                     dbconn = con)
})
