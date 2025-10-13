FROM pangeo/pangeo-notebook:2025.08.14

USER root

ENV HOME=/home/jovyan \
    ARCH="x86_64-linux-gnu" \
    LD_LIBRARY_PATH="/usr/lib:/lib:${LD_LIBRARY_PATH}"

RUN echo "Installing packages..." \
    && apt-get update --fix-missing > /dev/null \
    # Add packages in the following line if needed
    && apt-get install -y build-essential openmpi-bin libopenmpi-dev wget git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# Python packages
# ---------------
RUN conda install -n base -y -c conda-forge jax jaxlib "Cython>=3.0.8" flax optax


# Eophis
# ------
RUN git clone --branch v1.0.1 https://github.com/meom-group/eophis ${HOME}/eophis && \
    cd ${HOME}/eophis && \
    pip install .


# HDF5
# ----
RUN cd ${HOME} && \
    wget -O hdf5.tar.gz https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_5/downloads/hdf5-1.14.5.tar.gz && \
    tar -xvf hdf5.tar.gz && \
    cd hdf5-1.14.5 && \
    ./configure --enable-fortran --enable-parallel --enable-hl --enable-shared --prefix=/usr/lib/${ARCH}/ && \
    make -j"$(nproc)" && make install


# netcdf-c
# --------
RUN cd ${HOME} && \
    wget -O netcdf-c.tar.gz https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.7.3.tar.gz && \
    tar -xvf netcdf-c.tar.gz && \
    cd netcdf-c-4.7.3 && \
    export CPPFLAGS=-I/usr/lib/${ARCH}/include && \
    export LDFLAGS="-Wl,-rpath,/usr/lib/${ARCH}/lib -L/usr/lib/${ARCH}/lib -lhdf5_hl -lhdf5" && \
    export CC=mpicc && \
    ./configure --enable-parallel-tests --enable-netcdf-4 --enable-shared --prefix=/usr/lib/${ARCH}/ && \
    make -j"$(nproc)" && make install


# netcdf-fortran
# --------------
RUN cd ${HOME} && \
    wget -O netcdf-fortran.tar.gz https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.5.2.tar.gz && \
    tar -xvf netcdf-fortran.tar.gz && \
    cd netcdf-fortran-4.5.2 && \
    export CPPFLAGS=-I/usr/lib/${ARCH}/include && \
    export LDFLAGS="-Wl,-rpath,/usr/lib/${ARCH}/lib -L/usr/lib/${ARCH}/lib -lnetcdf -lhdf5_hl -lhdf5" && \
    export FC='mpif90 -fallow-argument-mismatch' && \
    ./configure --prefix=/usr/lib/${ARCH}/ --enable-shared --enable-parallel-tests && \
    make -j"$(nproc)" && make install


# install OASIS
# -------------
RUN cd ${HOME} && \
    git clone https://gitlab.com/cerfacs/oasis3-mct.git ${HOME}/oasis3-mct && \
    cd ${HOME}/oasis3-mct/util/make_dir && \
    git checkout OASIS3-MCT_5.0 && \
    echo "include ${HOME}/eophis/.github/workflows/make.gnu" > make.inc && \
    make -f TopMakefileOasis3 pyoasis

# julia
# -----
RUN apt-get update && apt-get install -y wget ca-certificates && \
    wget https://julialang-s3.julialang.org/bin/linux/x64/1.11/julia-1.11.1-linux-x86_64.tar.gz && \
    tar -xzf julia-1.11.1-linux-x86_64.tar.gz -C /opt/ && \
    ln -s /opt/julia-1.11.1/bin/julia /usr/local/bin/julia && \
    rm julia-1.11.1-linux-x86_64.tar.gz

RUN julia -e 'using Pkg; Pkg.add.(["IJulia", "OrdinaryDiffEq", "Optimization", "OptimizationOptimJL", "Plots", "Statistics"])'


# Cleanup
# -------
RUN rm -rf ${HOME}/hdf5* ${HOME}/netcdf* && \
    cd ${HOME}/oasis3-mct && rm -rf doc examples pyoasis/examples pyoasis/docs && \
    rm -rf ${HOME}/eophis ${HOME}/.cache && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


# Bashrc
# ------
RUN echo "source ${HOME}/oasis3-mct/BLD/python/init.sh" >> ${HOME}/.bashrc

USER ${NB_USER}
