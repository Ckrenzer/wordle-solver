library(ggplot2)
library(knitr)

{
    plot_colors <- c("lisp" = "green", "jl" = "purple", "r" = "blue", "gawk" = "red", "mawk" = "orange", "py" = "yellow")
    logfiles <- list.files(path = "log", full.names = TRUE)
    language <- local({
        basenames <- basename(logfiles)
        matchind_start <- regexpr(pattern = "(?<=progress_)[a-z0-9]+(?=\\.)", text = basenames, perl = TRUE)
        matchind_end <- matchind_start + (attr(matchind_start, "match.length") - 1L)
        substr(basenames, start = matchind_start, stop = matchind_end)
    })
    loginfo <- Map(c, logfiles, language, USE.NAMES = FALSE)
    read_log <- function(loginfo){
        logfile <- loginfo[[1L]]
        language <- loginfo[[2L]]
        log <- readLines(logfile) |>
            strsplit(split = "\t", fixed = TRUE) |>
            do.call(what = rbind) |>
            as.data.frame(row.names = FALSE)
        cols <- vapply(log[1L, ],
                       sub,
                       character(1L),
                       pattern = "^([a-z]+): .+$",
                       replacement = "\\1",
                       perl = TRUE,
                       USE.NAMES = FALSE)
        names(log) <- cols
        for(col in cols){
            log[[col]] <- sub(x = log[[col]], pattern = sprintf("%s: ", col), replacement = "", fixed = TRUE)
        }
        log[["language"]] <- language
        log
    }
    logs <- do.call(rbind, lapply(loginfo, read_log))
    logs[["start"]] <- as.POSIXct(logs[["start"]])
    logs[["end"]] <- as.POSIXct(logs[["end"]])
    logs[["compute_time"]] <- logs[["end"]] - logs[["start"]]
}

{
    group_by <- function(df, fn, by){
        split_id <- Reduce(function(...) paste(...), x = df[, by, drop = FALSE])
        out <- as.data.frame(do.call(rbind, lapply(split(df, split_id), fn)))
        id <- as.data.frame(do.call(rbind, strsplit(rownames(out), " ", fixed = TRUE)))
        rownames(out) <- NULL
        names(id) <- by
        cbind(out, id)
    }
    by_lang <- group_by(logs, function(x) mean(x$compute_time), by = "language")
    names(by_lang)[1L] <- "compute_time"
    by_lang[["language"]] <- factor(by_lang[["language"]], levels = by_lang[["language"]][order(-by_lang[["compute_time"]])])
}

{
    time_by_language <- ggplot(by_lang) +
        geom_col(aes(x = reorder(language, -compute_time), y = compute_time, fill = language)) +
        ggtitle("average number of seconds needed to calculate opening word score") +
        xlab("language") +
        ylab("mean compute time (seconds)") +
        scale_fill_manual(values = plot_colors) +
        theme_minimal()
    time_by_word <- ggplot(logs) +
        geom_histogram(aes(compute_time,
                           fill = as.factor(compute_time)),
                       bins = length(unique(logs[["compute_time"]])),
                       binwidth = 1L,
                       show.legend = FALSE) +
        scale_x_continuous(breaks = min(logs[["compute_time"]]):max(logs[["compute_time"]])) +
        facet_wrap(~language, nrow = 4L) +
        ggtitle("computation time distribution") +
        xlab("seconds needed to compute opening score (rounded to the nearest second)") +
        ylab("number of words in bucket") +
        theme_minimal()
    superlatives <- group_by(logs, function(x){
                                 sorted <- x[order(x$compute_time), ]
                                 rbind(head(sorted, 5L), tail(sorted, 5L))
                       },
                       by = "language")
    superlatives <- superlatives[, c("word", "language", "compute_time")]
    superlatives <- split(superlatives, superlatives$language)
}

{
    cat(kable(by_lang, format = "markdown", caption = "mean word compute time (seconds)"), sep = "\n")
    max_freq <- 0
    for(lang in unique(logs$language)){
        freq <- max(table(logs$compute_time[logs$language == lang]))
        if(freq > max_freq) max_freq <- freq
    }
    value_of_one_star <- max_freq %/% 70L # 70 stars max
    for(lang in unique(logs$language)){
        freq <- table(logs$compute_time[logs$language == lang])
        seen_times <- as.integer(names(freq))
        times <- as.character(union(seen_times, seq_len(max(seen_times))))
        missing_times <- setdiff(times, seen_times)
        freq <- c(freq, structure(rep(0, length(missing_times)), names = missing_times))
        freq <- freq[order(as.integer(names(freq)))]
        num_stars <- freq %/% value_of_one_star
        cat(sprintf("\nfrequency of computing times (%s)", lang), sep = "\n")
        for(i in seq_along(freq)){
            sprintf("(freq %5d) %2ss: %s",
                    freq[i],
                    names(freq[i]),
                    paste(rep("*", max(1, num_stars[i])), collapse = "")) |>
            cat(sep = "\n")
        }
    }
    cat("\nLeast expensive and most expensive words by language", sep = "\n")
    invisible(lapply(superlatives, function(...){
                         cat(kable(..., format = "markdown", row.names = FALSE), sep = "\n")
                         cat("\n")
                           }))
    ggsave("plot/time_by_language.pdf", plot = time_by_language, device = "pdf")
    ggsave("plot/time_by_word.pdf", plot = time_by_word, device = "pdf")
    cat(sprintf("plots saved to %s/plot/", getwd()), sep = "\n")
}
