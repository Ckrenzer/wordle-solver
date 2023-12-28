# I'd rather go through the pain of recreating R's
# stringr package than translate my regex knowledge
# to Julia...


# Not quite a faithful recreation of str_c(), as it does
# not have the `sep =` functionality from stringr,
# but--from my experience--most people only use
# `collapse =` anyway.
function str_c(vec, collapse = "")
    join(vec, collapse)    
end

# Basically a contains() alias but with
# that sweet, sweet stringr naming convention
function str_detect(str, pattern)    
    contains(str, pattern)
end

# Remove all matches of pattern from string.
function str_remove_all(str::String, pattern)
    str_replace_all(str, pattern, "")
end
function str_remove_all!(str::Vector{String}, pattern)
    str = str_replace_all!(str, pattern, "")
end

# Replaces all matches of pattern in string with replacement.
function str_replace_all(str, pattern, replacement)
    replace(str, pattern => replacement)
end
function str_replace_all!(str::Vector{String}, pattern, replacement)
    str .= replace.(str, pattern => replacement)
end

# Breaks a string into different elements separated by a delimiter.
#
# Basically stringr::str_split(s, pattern = p, n = Inf, simplify = TRUE)
function str_split(str::String, pattern)
    split(str, pattern)
end
function str_split(str::Char, pattern)
    [string(str)]
end

# Filters the input down to only those elements
# where a match was found. Do not broadcast.
#
# This function is not designed for 'scalars',
# but an implementation is provided to be thorough.
# Both return vectors for consistency--this function
# is intended for vectors and should return a vector.
function str_subset(str, pattern)
    str[str_detect.(str, pattern)]
end
function str_subset(str::String, pattern)
    if(str_detect(str, pattern))
        [str]
    else
        Vector{String}(undef, 1)
    end
end
