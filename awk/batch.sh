# create files for the words that each process will be responsible for running
numprocesses=$(nproc)
wc data/wordle_list.txt -l | awk -v numprocesses="$numprocesses" '{
    numlines_per_file = $1 / numprocesses
    if(numlines_per_file != int(numlines_per_file)){ # take the ceiling
        numlines_per_file = int(numlines_per_file) + 1
    }
    cmd = sprintf("split --lines=%d %s %s", numlines_per_file, $2, "data/word_list_partition_")
    system(cmd)
    close(cmd)
}'
function calculate(){
    awk -f awk/play.awk -v logfile="$2" data/wordle_list.txt data/unigram_freq.csv "$1"
}
export -f calculate
logfiles=()
for((i = 0; i < numprocesses; ++i)); do
    file="log/progress_awk$((${i}+1)).txt"
    test -e "$file" && rm "$file"
    logfiles[i]="$file"
done
outfile="data/opening_word_scores.tsv"
awk 'BEGIN { print "word\texpected_entropy\tfrequency" }' > "$outfile"
parallel --link calculate {1} {2} ::: data/word_list_partition* ::: "${logfiles[@]}" >> "$outfile"
cat log/progress_awk*.txt > log/progress_awk.txt
for file in "${logfiles[@]}"; do
    test -e "${file}" && rm "${file}"
done
# gawk took around 26 minutes on my 8-core/16-threaded laptop
# mawk took around 30 minutes on my 8-core/16-threaded laptop
