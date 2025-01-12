library(ggplot2)
library(knitr)

plot_colors <- c("lisp" = "green", "jl" = "purple", "r" = "blue", "gawk" = "red", "py" = "yellow")
logfiles <- list.files(path = "log", pattern = "progress_", full.names = TRUE)
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
logs[["start"]] <- as.POSIXct(as.double(logs[["start"]]))
logs[["end"]] <- as.POSIXct(as.double(logs[["end"]]))
logs[["compute_time"]] <- logs[["end"]] - logs[["start"]]
# calling unique after converting to bytes works and is faster than splitting for single-byte characters.
logs[["distinct_letters_in_word"]] <- vapply(logs[["word"]], function(s) length(unique(charToRaw(s))), integer(1L), USE.NAMES = FALSE)


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
by_lang <- by_lang[order(-by_lang[["compute_time"]]), ]
row.names(by_lang) <- NULL
superlatives <- group_by(logs, function(x){
                             sorted <- x[order(x$compute_time), ]
                             rbind(head(sorted, 5L), tail(sorted, 5L))
                   },
                   by = "language")
superlatives <- superlatives[, c("word", "language", "compute_time")]
superlatives <- split(superlatives, superlatives$language)
by_lang_and_length <- group_by(df = logs,
                                fn = function(x) mean(x[["compute_time"]]),
                                by = c("language", "distinct_letters_in_word"))
names(by_lang_and_length)[[1L]] <- "mean_compute_time"
by_lang_and_length <- reshape(data = by_lang_and_length,
                               direction = "wide",
                               idvar = "language",
                               timevar = "distinct_letters_in_word")
by_lang_and_length <- setNames(by_lang_and_length, c("language", 2:ncol(by_lang_and_length)))
by_lang_and_length <- by_lang_and_length[order(-by_lang_and_length[[ncol(by_lang_and_length)]]), ]
row.names(by_lang_and_length) <- NULL


time_by_language <- ggplot(by_lang) +
    geom_col(aes(x = reorder(language, -compute_time), y = compute_time, fill = language)) +
    ggtitle("average number of seconds needed to calculate opening word score") +
    xlab("language") +
    ylab("mean compute time (seconds)") +
    scale_fill_manual(values = plot_colors) +
    theme_minimal()
time_density <- ggplot(logs) +
    geom_violin(mapping = aes(x = language, y = compute_time), width = 1.8) +
    geom_jitter(mapping = aes(x = language, y = compute_time, color = as.factor(distinct_letters_in_word)), width = 0.01) +
    xlab("language") +
    ylab("compute time") +
    labs(color = "Distinct Letters") +
    theme(legend.position = "bottom")


cat("mean word compute time (seconds)", sep = "\n")
cat(kable(by_lang, format = "markdown"), sep = "\n")
cat("\nmean word compute time by number of distinct letters in word (seconds)", sep = "\n")
cat(kable(by_lang_and_length, format = "markdown"), sep = "\n")
cat("\nLeast expensive and most expensive words by language", sep = "\n")
invisible(lapply(superlatives,
                 function(...){
                     cat(kable(..., format = "markdown", row.names = FALSE), sep = "\n")
                     cat("\n")
                 }))
ggsave("plot/time_by_language.pdf", plot = time_by_language, device = "pdf")
ggsave("plot/time_density.pdf", plot = time_density, device = "pdf")
