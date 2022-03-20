# I'd rather recreate go through the pain of recreating
# R's stringr package than translate my regex knowledge
# to Julia...


# The same as R's seq_len(), but probably not as safe.
function seq_len(num::Integer)
    collect(1:1:num)
end




# Basically a vectorized contains() but with that sweet,
# sweet stringr naming convention
function str_detect(string, pattern)    
    contains.(string, Regex(pattern))
end

# Filters the input vector down to only those elements
# where a match was found
function str_subset(string, pattern)
    string[str_detect(string, pattern)]
end

# Not quite a faithful recreation of str_c(), as it does
# not have the `sep =` functionality from stringr,
# but--from my experience--most people only want
# `collapse =` anyway
function str_c(vec, collapse::String = " ")
    join(vec, collapse)    
end



# Other functions you may want to consider
str_count





str_extract
str_length
str_remove
str_replace
str_split
str_to_lower
str_to_upper