# tracking down the dependencies of this old project is kind of annoying...
# only using docker for the benchmark + benchmark analysis part of the code for now.
FROM manjarolinux/base AS bloat
RUN mkdir /app
WORKDIR /app
RUN pacman -Sy && \
    yes | pacman --noconfirm -S base-devel curl parallel julia sbcl r-base && \
    curl -O https://beta.quicklisp.org/quicklisp.lisp && \
    sbcl --load quicklisp.lisp --eval '(quicklisp-quickstart:install)' --quit && \
    echo -e '#-quicklisp\n(let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp" (user-homedir-pathname)))) (when (probe-file quicklisp-init) (load quicklisp-init)))' > /root/.sbclrc && \
    R -e 'install.packages(c("doParallel", "foreach", "ggplot2", "knitr"), repos = "https://cloud.r-project.org")' && \
    julia -e 'using Pkg; Pkg.add("Dates")'


# the log and plot directories should be mounts with write privileges.
FROM bloat AS benchmarker
COPY awk awk
COPY data data
COPY jl jl
COPY lisp lisp
COPY py py
COPY r r
COPY runall.sh .
CMD ["bash", "/app/runall.sh"]
