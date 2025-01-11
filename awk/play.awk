#!/usr/bin/gawk -f

# this implementation can only use gawk due to the presence of the time library
@load "time"
BEGIN{
    # AWK SETTINGS
    FS = ","
    # IMPORTANT 'CONSTANTS'
    LOG2 = log(2)
    NUM_CHARACTERS = 5
    COLORS["green"] = 0
    COLORS["yellow"] = 1
    COLORS["grey"] = 2
    NUM_COMBOS = length(COLORS)^NUM_CHARACTERS
    for(a in COLORS){
        for(b in COLORS){
            for(c in COLORS){
                for(d in COLORS){
                    for(e in COLORS){
                        combo_row++
                        COLOR_COMBOS[combo_row,1] = COLORS[a]
                        COLOR_COMBOS[combo_row,2] = COLORS[b]
                        COLOR_COMBOS[combo_row,3] = COLORS[c]
                        COLOR_COMBOS[combo_row,4] = COLORS[d]
                        COLOR_COMBOS[combo_row,5] = COLORS[e]
                    }
                }
            }
        }
    }
    for(i = 1; i <= NUM_CHARACTERS; i++){
        ABC[i] = "abcdefghijklmnopqrstuvwxyz"
    }
}

{
    FILENUM += FNR == 1
}

# load acceptable answers
FILENUM == 1{
    words[$0] = 0
}

# load unigram frequencies
FILENUM == 2 && \
   length($1) == NUM_CHARACTERS && \
   $2 > 0 && \
   $1 in words{
    words[$1] = $2 + 0
}

# load words for which an awk process is responsible
FILENUM == 3 {
    guesses[$1]
}

END{
    for(key in ABC) letters[key] = ABC[key]                #   'ABC' only works for opening scores
    for(word in words) remaining_words[word] = words[word] # 'words' only works for opening scores
    for(word in remaining_words){
        # let's pretend that this wouldn't necessarily give the same result as words[word]
        # (doing it this way is more convenient for calculating scores beyond the opening guess)
        freq_total += remaining_words[word]
    }
    for(guess in guesses){
        start_time = gettimeofday()
        expected_information = 0
        for(combo_row = 1; combo_row <= NUM_COMBOS; ++combo_row){
            # <<BUILD REGULAR EXPRESSION>>
            for(key in letters){
                remaining_letters[key] = letters[key]
            }
            for(g in greys){
                delete greys[g]
            }
            for(ng in nongreys){
                delete nongreys[ng]
            }
            for(y in yellow_letters){
                delete yellow_letters[y]
            }
            for(letterind = 1; letterind <= NUM_CHARACTERS; ++letterind){
                current_letter = substr(guess, letterind, 1)
                current_combo_val = COLOR_COMBOS[combo_row,letterind]
                # green letters are set
                if(current_combo_val == COLORS["green"]){
                    remaining_letters[letterind] = current_letter
                    nongreys[current_letter]
                # yellow letters are removed from the index at which they are found
                } else if(current_combo_val == COLORS["yellow"]){
                    yellow_letters[letterind] = current_letter
                    sub(current_letter, "", remaining_letters[letterind])
                    nongreys[current_letter]
                # grey letters are removed from each index
                } else {
                    for(another_letterind = 1; another_letterind <= NUM_CHARACTERS; ++another_letterind){
                        sub(current_letter, "", remaining_letters[another_letterind])
                    }
                    greys[current_letter]
                }
            }
            is_impossible_pattern = 0
            for(g in greys){
                if(g in nongreys){
                    is_impossible_pattern = 1
                    break
                }
            }
            # letters cannot be both grey and nongrey condition
            if(is_impossible_pattern){
                continue
            }
            rgx = ""
            is_impossible_pattern = 0
            for(letterind = 1; letterind <= NUM_CHARACTERS; ++letterind){
                if(length(remaining_letters[letterind]) == 0){
                    is_impossible_pattern = 1
                    break
                }
                rgx = rgx "[" remaining_letters[letterind] "]"
            }
            # out of letters condition
            if(is_impossible_pattern){
                continue
            }
            # <<BUILD REGULAR EXPRESSION>>
            # <<FILTER TO MATCHED WORDS USING RGX AND IDENTIFY PROPORTION OF WORD FREQUENCIES REMAINING>>
            frequency_of_remaining_words_for_this_combo = 0
            for(word in remaining_words){
                if(word ~ rgx){
                    # Ensure results contain all of the yellow letters when yellow was in the combo
                    all_yellows_found = 1
                    for(y in yellow_letters){
                        all_yellows_found = all_yellows_found && (index(word, yellow_letters[y]) != 0)
                    }
                    if(all_yellows_found){
                        frequency_of_remaining_words_for_this_combo += remaining_words[word]
                    }
                }
            }
            proportion_of_words_remaining_for_this_combo = frequency_of_remaining_words_for_this_combo / freq_total
            entropy_for_this_combo = 0
            if(proportion_of_words_remaining_for_this_combo > 0){
                entropy_for_this_combo = log(1 / proportion_of_words_remaining_for_this_combo) / LOG2
            }
            expected_information += proportion_of_words_remaining_for_this_combo * entropy_for_this_combo
            # <<FILTER TO MATCHED WORDS USING RGX AND IDENTIFY PROPORTION OF WORD FREQUENCIES REMAINING>>
        }
        # If you want to do further computation beyond the opening scores,
        # you'll want to save expected_information somewhere instead of just printing it out.
        end_time = gettimeofday()
        printf("word: %s\tstart: %.6f\tend: %.6f\n", guess, start_time, end_time) >> logfile
        printf("%s\t%s\t%s\n", guess, expected_information, remaining_words[guess])
    }
}
