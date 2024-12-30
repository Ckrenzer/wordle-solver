# INFORMAL UNIT TESTS
# be sure to define the functions from play.jl

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
