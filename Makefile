.PHONY: clear build container run interactive-run

# set it yourself if you want something more robust
numprocs ?= $(shell lscpu | awk '/Core\(s\) per socket/ {numcores = $$NF}; /Socket\(s\)/ {numsockets = $$NF}; END {print numcores * numsockets}')


clear:
	sudo docker image rm wordle-solver:benchmarker-prod

build:
	# not serious enough about this to tie the tag to the git hash...
	# too little disk space to keep these lying around!
	sudo docker build --target benchmarker --tag wordle-solver:benchmarker-prod .

container: clear | build

run:
	sudo docker run --rm \
		--env NUM_PROCESSES=$(numprocs) \
		--mount type=bind,source=$(PWD)/log/,target=/app/log \
		--mount type=bind,source=$(PWD)/plot/,target=/app/plot \
		wordle-solver:benchmarker-prod

interactive-run:
	sudo docker run --rm -ti \
		--env NUM_PROCESSES=$(numprocs) \
		--mount type=bind,source=$(PWD)/log/,target=/app/log \
		--mount type=bind,source=$(PWD)/plot/,target=/app/plot \
		wordle-solver:benchmarker-prod bash
