awk_implementation="$1"

# create files for the words that each process will be responsible for running
numprocesses=$(nproc)
wc data/wordle_list.txt -l | awk -v numprocesses="$numprocesses" '{
    numlines_per_file = $1 / numprocesses
    if(numlines_per_file != int(numlines_per_file)){ # take the ceiling
        numlines_per_file = int(numlines_per_file) + 1
    }
    cmd = sprintf("split --lines=%d %s data/word_list_partition_", numlines_per_file, $2)
    system(cmd)
    close(cmd)
}'

logfiles=()
for((i = 0; i < numprocesses; ++i)); do
    file="log/progress_${awk_implementation}$((${i}+1)).txt"
    test -e "$file" && rm "$file"
    logfiles[i]="$file"
done

function calculate(){
    "$1" -f awk/play.awk -v logfile="$2" data/wordle_list.txt data/unigram_freq.csv "$3"
}
export -f calculate

outfile="data/opening_word_scores.tsv"
echo -e "word\texpected_entropy\tfrequency" > "$outfile"
parallel --link calculate {1} {2} {3} \
    ::: "${awk_implementation}" \
    ::: "${logfiles[@]}" \
    ::: data/word_list_partition* \
    >> "$outfile"
logfile="log/progress_${awk_implementation}.txt"
test -e "${logfile}" && rm "${logfile}"
cat "log/progress_${awk_implementation}"*".txt" > "${logfile}"
for file in "${logfiles[@]}"; do
    test -e "${file}" && rm "${file}"
done
rm data/word_list_partition_*
