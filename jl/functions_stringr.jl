# I'd rather go through the pain of recreating R's
# stringr package than translate my regex knowledge
# to Julia...


# Not quite a faithful recreation of str_c(), as it does
# not have the `sep =` functionality from stringr,
# but--from my experience--most people only use
# `collapse =` anyway.
function str_c(vec, collapse::String = "")
    join(vec, collapse)    
end

# Count the number of occurrences of pattern
# in string.
function str_count(str::String, pattern::Regex)
    length(collect(eachmatch(pattern, str)))
end

# Basically a vectorized contains() but with that sweet,
# sweet stringr naming convention
function str_detect(str, pattern)    
    contains(str, pattern)
end

# Extract the pattern in string. The pattern must
# be a regular expression.
#
# There is probably a more elegant way to write this,
# particularly by predefining the data type for m
# and replacing the conditional statement, but the
# function works as intended.
function str_extract_all(str, pattern)
    m = match(pattern, str)
    if(!isnothing(m))
        m.match
    else
        ""
    end
end

# Return the number of characters in each element of the string vector.
function str_length(str)
    length(str)
end

# Remove all matches of pattern from string.
function str_remove_all(str::String, pattern)
    str_replace_all(str, pattern, "")
end
function str_remove_all!(str::Vector{String}, pattern::String)
    str = str_replace_all!(str, pattern, "")
end
function str_remove_all!(str::Vector{String}, pattern::Regex)
    str_replace_all!(str, pattern, "")
end

# Replaces all matches of pattern in string with replacement.
function str_replace_all(str::String, pattern::String, replacement::String)
    replace(str, pattern => replacement)
end
function str_replace_all(str::String, pattern::Regex, replacement::String)
    replace(str, pattern => replacement)
end
function str_replace_all!(str::Vector{String}, pattern::String, replacement::String)
    str .= replace.(str, pattern => replacement)
end
function str_replace_all!(str::Vector{String}, pattern::Regex, replacement::String)
    str .= replace.(str, pattern => replacement)
end

# Breaks a string into different elements separated by a delimiter.
#
# Basically stringr::str_split(s, pattern = p, n = Inf, simplify = TRUE)
function str_split(str::String, pattern::String)
    split(str, pattern)
end
function str_split(str::String, pattern::Regex)
    split(str, pattern)
end
function str_split(str::Char, pattern::String)
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
function str_subset(str::String, pattern::String)
    if(str_detect(str, pattern))
        [str]
    else
        Vector{String}(undef, 1)
    end
end
function str_subset(str::String, pattern::Regex)
    if(str_detect(str, pattern))
        [str]
    else
        Vector{String}(undef, 1)
    end
end

# Converts strings to lower case.
function str_to_lower(str)
    lowercase(str)
end

# Converts strings to title case.
function str_to_title(str)
    titlecase(str)
end

# Converts strings to upper case.
function str_to_upper(str)
    uppercase(str)
end
