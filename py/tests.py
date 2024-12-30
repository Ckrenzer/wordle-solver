# UNIT TESTS
# be sure to define the functions from play.py

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
