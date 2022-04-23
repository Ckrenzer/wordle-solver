# Provides the elapsed time in seconds from `start`.
function time_from_start(start)
    round((Dates.DateTime(Dates.now()) - Dates.DateTime(start)) / Dates.Millisecond(1) * (1 / 1000), digits = 4)
end

# The same as R's seq_len(), but probably not as safe.
function seq_len(num::Integer)
    collect(1:1:num)
end

# The same as R's seq_along(), but probably not as safe.
function seq_along(obj)
    collect(1:1:length(obj))
end

# Similar to R's which(), but definitely not as safe.
function which(logical)
    seq_along(logical)[logical .== 1]
end

# Calculates the weighted mean. Fails if the input contains missing values.
function weighted_mean(vals, weights)
    if length(vals) != length(weights) error("vals and weights must be the same length!") end
    valsum = 0
    for i in seq_along(vals)
        valsum += (vals[i] * weights[i])
    end
    valsum / sum(weights)
end
