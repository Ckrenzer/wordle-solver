#!/usr/bin/Rscript
# references to 'powers of 2' are regarding the encoding of sets of letters or
# words into arbitrarily-large integers using sums of powers of 2 inspired by
# unix file permissions. this is done to represent sets of letters or words as
# scalars rather than needing to build out large tables that store every
# combination in the game. this cuts down on disk space, database query
# execution time, and the number of tables needed in the database
# (simplification!).
# sums of powers of 2 can be decomposed in exactly one way.
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
library(RPostgreSQL)
library(gmp)


# CONSTRUCT DATABASE
tryCatch({
    dbconn <- DBI::dbConnect(RPostgreSQL::PostgreSQL(),
                             host = Sys.getenv("dbhost"),
                             port = Sys.getenv("dbport"),
                             dbname = Sys.getenv("dbname"),
                             user = Sys.getenv("dbuser"),
                             password = Sys.getenv("dbpass"))
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
        -- houses combo_id for each color combo.
        CREATE TABLE IF NOT EXISTS combo_ids (
            combo_id INTEGER,
            PRIMARY KEY (combo_id)
       );
   ")
    DBI::dbExecute(dbconn, "
        -- stores all (num_colors)^(num_characters_in_guess) color combos.
        CREATE TABLE IF NOT EXISTS color_combos (
            combo_id INTEGER,
            letter_position INTEGER,
            representation INTEGER,
            PRIMARY KEY (combo_id, letter_position),
            FOREIGN KEY (combo_id) REFERENCES combo_ids(combo_id),
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
            power_of_2 NUMERIC,
            PRIMARY KEY (word),
            -- the power of 2 must tie to exactly one word.
            UNIQUE (power_of_2)
        );
    ")
    DBI::dbExecute(dbconn, "
        -- formalizes the encoding used to produce the letter_set_id column.
        -- the absence of a value in this table denotes the empty set of letters.
        CREATE TABLE IF NOT EXISTS letter_values (
            letter_position INTEGER,
            letter TEXT,
            power_of_2 NUMERIC,
            PRIMARY KEY (letter_position, letter, power_of_2),
            -- power_of_2 must tie to exactly one letter_position-letter combo.
            UNIQUE(power_of_2)
        );
    ")
    DBI::dbExecute(dbconn, "
        -- determines whether a color combo is possible for the given word
        -- Ex. the colors for 'll' in 'pulls' cannot be yellow and grey,
        --     respectively; that constitutes an invalid color combo.
        -- and stores an integer representation of remaining words and letters
        -- for that color combo and given word.
        --
        -- note that the empty set of words or letters is represented by the
        -- value zero.
        CREATE TABLE IF NOT EXISTS guess_combo_info (
            guess TEXT,
            combo_id INTEGER,
            combo_is_possible INTEGER,
            remaining_words_set_id NUMERIC,
            remaining_letters_set_id NUMERIC,
            PRIMARY KEY (guess, combo_id),
            FOREIGN KEY (guess) REFERENCES unigram_frequency(word),
            FOREIGN KEY (combo_id) REFERENCES combo_ids(combo_id),
            CONSTRAINT word_set_id_at_least_zero CHECK (remaining_words_set_id >= 0),
            CONSTRAINT letter_set_id_at_least_zero CHECK (remaining_letters_set_id >= 0)
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
        data.table::setnames(words, "count", "frequency")
        data.table::setkey(words, "word")
        # values used when encoding words into a set.
        words[, power_of_2 := as.character(gmp::pow.bigz(2L, seq_len(.N) - 1L))]
        words
    })
    DBI::dbWriteTable(dbconn, "unigram_frequency", word_table, append = TRUE, row.names = FALSE)
    # helper.
    split_words <- structure(strsplit(word_table[["word"]], "", fixed = TRUE), names = word_table[["word"]])

    # mapping between color and its integer representation.
    color_table <- data.table::data.table(representation = 0L:2L,
                                          color = c("green", "yellow", "grey"))
    DBI::dbWriteTable(dbconn, "colors", color_table, append = TRUE, row.names = FALSE)

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
    DBI::dbWriteTable(dbconn, "combo_ids", unique(color_combo_table[, .(combo_id)]), append = TRUE, row.names = FALSE)
    DBI::dbWriteTable(dbconn, "color_combos", color_combo_table, append = TRUE, row.names = FALSE)

    # values used when encoding letters into a set.
    letter_values_table <- local({
        letter_positions <- rep(seq_len(num_characters),
                                each = length(letters))
        letter_vec <- rep(letters, times = num_characters)
        powers_of_2 <- gmp::pow.bigz(2L, seq_len(length(letters) * num_characters) - 1L)
        powers_of_2 <- as.character(powers_of_2)
        data.table::data.table(letter_position = letter_positions,
                               letter = letter_vec,
                               power_of_2 = powers_of_2)
    })
    data.table::setkeyv(letter_values_table, c("letter_position", "letter", "power_of_2"))
    DBI::dbWriteTable(dbconn, "letter_values", letter_values_table, append = TRUE, row.names = FALSE)
    # this is useful for encoding values
    letter_encoding_lookup <- local({
        letter_vec <- letter_values_table[, unique(letter)]
        powers <- split(letter_values_table[, power_of_2],
                        (seq_len(nrow(letter_values_table)) - 1L) %/% length(letter_vec))
        unname(lapply(powers, function(elt) structure(elt, names = letter_vec)))
    })

    # identify impossible color combos--a grey letter cannot also be green or yellow.
    combo_validity_table <- local({
        words <- word_table[["word"]]
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
                                                 combo_is_possible = as.integer(is_valid_combo))
                      }) |>
        data.table::rbindlist(use.names = FALSE, fill = FALSE, ignore.attr = FALSE)
        data.table::setkey(out, "guess")
        out
    })
    # add constraint checking bounds of set IDs
    local({
        query_fmt <- "
            SELECT CAST(POW(2, n) AS TEXT) AS upper_bound
            FROM (SELECT CAST(COUNT(*) AS NUMERIC) AS n FROM %s);
        "
        word_set_id_upper_bound <- dbGetQuery(dbconn, sprintf(query_fmt, "unigram_frequency"))[["upper_bound"]]
        letter_set_id_upper_bound <- dbGetQuery(dbconn, sprintf(query_fmt, "letter_values"))[["upper_bound"]]
        constraint_query <- "
            ALTER TABLE guess_combo_info
            ADD CONSTRAINT word_set_id_within_upper_bound CHECK (remaining_words_set_id < %s),
            ADD CONSTRAINT letter_set_id_within_upper_bound CHECK(remaining_letters_set_id < %s);
        "
        constraint_query <- sprintf(constraint_query, word_set_id_upper_bound, letter_set_id_upper_bound)
        DBI::dbExecute(dbconn, constraint_query)
    })
    DBI::dbWriteTable(dbconn, "guess_combo_info", combo_validity_table, append = TRUE, row.names = FALSE)

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

compute_outcomes <- local({
    color_combo_ids <- color_combo_table[letter_position == 1L, combo_id]
    color_combo_representations <- split(color_combo_table, by = "combo_id", keep.by = FALSE, sorted = TRUE)
    color_combo_representations <- lapply(color_combo_representations, function(tbl) tbl[, representation])
    combo_validity_by_word_in_game <- split(combo_validity_table, by = "guess", keep.by = FALSE)
    combo_validity_by_word_in_game <- lapply(combo_validity_by_word_in_game, `[[`, "combo_is_possible")
    color_lookup_vec <- color_table[, structure(representation, names = color)]
    function(remaining_letters,
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
                    letter_set_id <- as.character(Reduce(`+`,
                                                         Map(function(lettrs, lookup) sum(gmp::as.bigz(lookup[lettrs])),
                                                             remaining[["letters"]],
                                                             letter_lookup)))
                    word_set_id <- word_lookup[remaining[["words"]]] |> gmp::sum.bigz() |> as.character()
                    rm(remaining)
                } else {
                    letter_set_id <- word_set_id <- "0"
                }
                outcome_id_tables[[i]] <- data.table::data.table(guess = guess,
                                                                 combo_id = game_combo_ids[[i]],
                                                                 remaining_words_set_id = word_set_id,
                                                                 remaining_letters_set_id = letter_set_id)
            }
            data.table::rbindlist(outcome_id_tables, use.names = FALSE, fill = FALSE, ignore.attr = FALSE)
        }
        guess_info
    }
})

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
    # compute all remaining words and letters for each open guesses
    outcomes <- compute_outcomes(remaining_letters = abc,
                                 remaining_words = word_table[["word"]],
                                 letter_lookup = letter_encoding_lookup,
                                 word_lookup = word_table[, structure(power_of_2, names = word)])
    con <- DBI::dbConnect(RPostgreSQL::PostgreSQL(),
                          host = Sys.getenv("dbhost"),
                          port = Sys.getenv("dbport"),
                          dbname = Sys.getenv("dbname"),
                          user = Sys.getenv("dbuser"),
                          password = Sys.getenv("dbpass"))
    on.exit({
        DBI::dbExecute(con, "DROP TABLE IF EXISTS outcomes;")
        DBI::dbDisconnect(con)
    }, add = TRUE)
    DBI::dbExecute(con, "CREATE TEMPORARY TABLE outcomes (guess TEXT,
                                                          combo_id INTEGER,
                                                          remaining_words_set_id NUMERIC,
                                                          remaining_letters_set_id NUMERIC);")
    DBI::dbWriteTable(con, "outcomes", outcomes, append = TRUE, row.names = FALSE)
    rm(outcomes)
    DBI::dbExecute(con, "
        INSERT INTO guess_combo_info (guess, combo_id, remaining_words_set_id, remaining_letters_set_id)
        SELECT * FROM outcomes
        ON CONFLICT (guess, combo_id) DO
        UPDATE SET
        remaining_words_set_id = EXCLUDED.remaining_words_set_id,
        remaining_letters_set_id = EXCLUDED.remaining_letters_set_id;
    ")
})
