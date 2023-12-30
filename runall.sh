#!/usr/bin/bash
# Run the 'calculate opening scores' code for each implementation

echo "R"
time Rscript r/play.R TRUE

echo -e "\n\nAWK"
time source awk/batch.sh

echo -e "\n\nPython"
time python3 py/play.py

echo -e "\n\nJulia"
time julia --optimize=3 jl/play.jl
