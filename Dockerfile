# tracking down the dependencies of this old project is kind of annoying...
# only using docker for the benchmark + benchmark analysis part of the code for now.
FROM ubuntu:plucky AS builder
WORKDIR /app
RUN apt-get update && \
    apt-get install -y wget=1.24.5-2ubuntu1 \
                       curl=8.11.1-1ubuntu1 \
                       parallel=20240222+ds-2 \
                       sbcl=2:2.2.9-1ubuntu2 \
                       r-base=4.4.2-1 \
                       gawk=1:5.2.1-2build3
RUN curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp --eval '(quicklisp-quickstart:install)' --quit && \
    printf '#-quicklisp\n(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))) (when (probe-file quicklisp-init) (load quicklisp-init)))' > /root/.sbclrc && \
    sbcl --eval '(ql:quickload "bordeaux-threads")' --eval '(ql:quickload "cl-ppcre")' --eval '(ql:quickload "local-time")' --eval '(ql:quickload "uiop")' --quit && \
    R -e 'install.packages(c("doParallel", "foreach", "ggplot2", "knitr"), repos = "https://mirrors.nics.utk.edu/cran/")'
# install julia -- update version as you see fit.
RUN apt-get update && apt-get install -y wget && \
    wget --output-document julia.tar.gz "https://julialang-s3.julialang.org/bin/linux/x64/1.10/julia-1.10.7-linux-x86_64.tar.gz" && \
    tar zxvf julia.tar.gz && \
    rm julia.tar.gz && \
    mv julia-* julia_installation && \
    ln -s /app/julia_installation/bin/julia /usr/local/bin/julia

FROM builder AS benchmarker
# the log and plot directories should be mounts with write privileges.
COPY awk awk
COPY data data
COPY jl jl
COPY lisp lisp
COPY py py
COPY r r
COPY runall.sh .
CMD ["bash", "/app/runall.sh"]
