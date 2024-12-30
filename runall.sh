#!/usr/bin/bash
# Run the 'calculate opening scores' code for each implementation
#
# NOTE: Environment variable 'NUM_PROCESSES' must be set at container run time!

timer_file="log/wall_time.txt"
test -e "$timer_file" && rm "$timer_file"

echo "R" >> $timer_file
time $(Rscript r/play.R TRUE > /dev/null) >> $timer_file

echo -e "\n\nGAWK" >> $timer_file
time $(source awk/batch.sh "gawk" > /dev/null) >> $timer_file

# TEMPORARILY UNAVAILABLE
#echo -e "\n\nMAWK" >> $timer_file
#time $(source awk/batch.sh "mawk" > /dev/null) >> $timer_file

echo -e "\n\nPython" >> $timer_file
time $(python3 py/play.py > /dev/null) >> $timer_file

echo -e "\n\nJulia" >> $timer_file
time $(julia -t $NUM_PROCESSES --optimize=3 jl/play.jl) >> $timer_file

echo -e "\n\nSBCL" >> $timer_file
time $(sbcl --script lisp/play.lisp) >> $timer_file

Rscript r/analyze_logs.R
