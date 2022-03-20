# I'd rather go through the pain of recreating R's
# stringr package than translate my regex knowledge
# to Julia...


# The same as R's seq_len(), but probably not as safe.
function seq_len(num::Integer)
    collect(1:1:num)
end





# Not quite a faithful recreation of str_c(), as it does
# not have the `sep =` functionality from stringr,
# but--from my experience--most people only use
# `collapse =` anyway
function str_c(vec, collapse::String = "")
    join(vec, collapse)    
end

# Basically a vectorized contains() but with that sweet,
# sweet stringr naming convention
function str_detect(string::String, pattern::String)    
    contains(string, pattern)
end
function str_detect(string::String, pattern::Regex)    
    contains(string, pattern)
end

# Extract the pattern in string. The pattern must
# be a regular expression.
#
# There is probably a more elegant way to write this,
# particularly by predefining the data type for m
# and replacing the conditional statement, but the
# function works as intended.
function str_extract_all(string::String, pattern::Regex)
    m = match(pattern, string)
    if(!isnothing(m))
        m.match
    else
        ""
    end
end

# Return the number of characters in each element of the string vector
function str_length(string::String)
    length(string)
end

# Remove all matches of pattern from string
function str_remove_all(string::String, pattern::String)
    str_replace_all(string, pattern, "")
end
function str_remove_all(string::String, pattern::Regex)
    str_replace_all(string, pattern, "")
end

# Replaces all matches of pattern in string with replacement
function str_replace_all(string::String, pattern::String, replacement::String)
    replace(string, pattern => replacement)
end
function str_replace_all(string::String, pattern::Regex, replacement::String)
    replace(string, pattern => replacement)
end

# Filters the input down to only those elements
# where a match was found. Do not broadcast.
#
# This function is not designed for 'scalars',
# but an implementation is provided to be thorough.
# Both return vectors for consistency--this function
# is intended for vectors and should return a vector.
function str_subset(string::Vector{String}, pattern::String)
    string[str_detect.(string, pattern)]
end
function str_subset(string::Vector{String}, pattern::Regex)
    string[str_detect.(string, pattern)]
end
function str_subset(string::String, pattern::String)
    if(str_detect(string, pattern))
        [string]
    else
        Vector{String}(undef, 1)
    end
end
function str_subset(string::String, pattern::Regex)
    if(str_detect(string, pattern))
        [string]
    else
        Vector{String}(undef, 1)
    end
end

# Converts strings to lower case
function str_to_lower(string::String)
    lowercase(string)
end

# Converts strings to title case
function str_to_title(string::String)
    titlecase(string)
end

# Converts strings to upper case
function str_to_upper(string::String)
    uppercase(string)
end






# Other functions you may want to consider
str_count

str_split