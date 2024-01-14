#!/usr/bin/bash
# Run the 'calculate opening scores' code for each implementation

echo "R"
time Rscript r/play.R TRUE

echo -e "\n\nGAWK"
time source awk/batch.sh "gawk"

echo -e "\n\nMAWK"
time source awk/batch.sh "mawk"

echo -e "\n\nPython"
time python3 py/play.py

echo -e "\n\nJulia"
time julia --optimize=3 jl/play.jl

Rscript r/analyze_logs.R
