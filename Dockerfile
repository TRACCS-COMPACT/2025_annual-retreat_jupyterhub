FROM quay.io/jupyterhub/k8s-singleuser-sample:4.3.0

USER root

# Env
# ---
ENV HOME=/home/jovyan \
    LIB=$HOME/local_lib \
    ARCH="x86_64-linux-gnu" \
    PYLIB=$HOME/.local_python
    
RUN mkdir $LIB

# System packages
# ---------------
RUN apt-get update --fix-missing > /dev/null \
    && apt-get install -y build-essential ca-certificates subversion wget git vim bash liburi-perl \
                          libopenmpi-dev openmpi-bin libnetcdff-dev libnetcdf-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*


# HDF5
# ----
RUN cd ${LIB} && \
    wget -O hdf5.tar.gz https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_5/downloads/hdf5-1.14.5.tar.gz && \
    tar -xvf hdf5.tar.gz && \
    cd hdf5-1.14.5 && \
    ./configure --enable-fortran --enable-parallel --enable-hl --enable-shared --prefix=/usr/lib/${ARCH}/ && \
    make -j"$(nproc)" && make install


# netcdf-c
# --------
RUN cd ${LIB} && \
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
RUN cd ${LIB} && \
    wget -O netcdf-fortran.tar.gz https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v4.5.2.tar.gz && \
    tar -xvf netcdf-fortran.tar.gz && \
    cd netcdf-fortran-4.5.2 && \
    export CPPFLAGS=-I/usr/lib/${ARCH}/include && \
    export LDFLAGS="-Wl,-rpath,/usr/lib/${ARCH}/lib -L/usr/lib/${ARCH}/lib -lnetcdf -lhdf5_hl -lhdf5" && \
    export FC='mpif90 -fallow-argument-mismatch' && \
    ./configure --prefix=/usr/lib/${ARCH}/ --enable-shared --enable-parallel-tests && \
    make -j"$(nproc)" && make install


# XIOS2
# -----
RUN svn co --non-interactive --trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other \
    --config-option servers:global:http-max-connections=1 \
    --config-option servers:global:http-timeout=120 \
    https://forge.ipsl.jussieu.fr/ioserver/svn/XIOS2/trunk ${LIB}/XIOS2

RUN rm $LIB/XIOS2/arch/arch-GCC_LINUX.env && \
    echo "export INC_DIR=/usr/lib/$ARCH/include" >> $LIB/XIOS2/arch/arch-GCC_LINUX.env && \
    echo "export LIB_DIR=/usr/lib/$ARCH/lib" >> $LIB/XIOS2/arch/arch-GCC_LINUX.env && \
    echo "export ZLIB_DIR=/usr/lib/" >> $LIB/XIOS2/arch/arch-GCC_LINUX.env && \
    echo "export OPENMPI_INC_DIR=/usr/lib/$ARCH/openmpi/include" >> $LIB/XIOS2/arch/arch-GCC_LINUX.env && \
    echo "export OPENMPI_LIB_DIR=/usr/lib/$ARCH/openmpi/lib" >> $LIB/XIOS2/arch/arch-GCC_LINUX.env

RUN rm $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'NETCDF_INCDIR="-I $INC_DIR"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'NETCDF_LIBDIR="-L $LIB_DIR"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'NETCDF_LIB="-lnetcdff -lnetcdf"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'MPI_INCDIR="-I $OPENMPI_INC_DIR"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'MPI_LIBDIR="-L $OPENMPI_LIB_DIR"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'MPI_LIB="-lmpi"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'HDF5_INCDIR="-I $INC_DIR"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'HDF5_LIBDIR="-Wl,-rpath,$LIB_DIR -L$LIB_DIR -L $ZLIB_DIR"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'HDF5_LIB="-lhdf5_hl -lhdf5 -lz"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'BOOST_INCDIR="-I $BOOST_INC_DIR"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'BOOST_LIBDIR="-L $BOOST_LIB_DIR"' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path && \
    echo 'BOOST_LIB=""' >> $LIB/XIOS2/arch/arch-GCC_LINUX.path

RUN sed -i 's/%BASE_FFLAGS[[:space:]]\+-D__NONE__/%BASE_FFLAGS    -D__NONE__ -ffree-line-length-none/' $LIB/XIOS2/arch/arch-GCC_LINUX.fcm

RUN cd $LIB/XIOS2 && \
    ./make_xios --full --prod --arch GCC_LINUX


# XIOS3
# -----
RUN svn co --non-interactive --trust-server-cert-failures=unknown-ca,cn-mismatch,expired,not-yet-valid,other \
    --config-option servers:global:http-max-connections=1 \
    --config-option servers:global:http-timeout=120 \
    https://forge.ipsl.jussieu.fr/ioserver/svn/XIOS3/trunk ${LIB}/XIOS3

RUN cp $LIB/XIOS2/arch/arch-GCC_LINUX.path $LIB//XIOS3/arch/ && \
    cp $LIB/XIOS2/arch/arch-GCC_LINUX.fcm $LIB//XIOS3/arch/ && \
    cp $LIB/XIOS2/arch/arch-GCC_LINUX.env $LIB//XIOS3/arch/

RUN cd $LIB/XIOS3 && \
    ./make_xios --full --prod --arch GCC_LINUX


# Python packages
# ---------------
RUN python3 -m venv $PYLIB
ENV PATH="${PYLIB}/bin:$PATH"
RUN pip install matplotlib numpy mpi4py Cython flax optax tqdm jax jaxlib notebook jupyterlab ipykernel ipywidgets pytest


# Eophis
# ------
RUN git clone --branch v1.0.1 https://github.com/meom-group/eophis ${LIB}/eophis && \
    cd ${LIB}/eophis && pip install .


# OASIS
# -----
ENV HOME=$LIB
RUN cd ${LIB} && \
    git clone https://gitlab.com/cerfacs/oasis3-mct.git ${LIB}/oasis3-mct && \
    cd ${LIB}/oasis3-mct/util/make_dir && \
    git checkout OASIS3-MCT_5.0 && \
    echo "include ${LIB}/eophis/.github/workflows/make.gnu" > make.inc && \
    make -f TopMakefileOasis3 pyoasis


# julia
# -----
ENV HOME=/home/jovyan
RUN cd ${LIB} && \
    wget https://julialang-s3.julialang.org/bin/linux/x64/1.11/julia-1.11.1-linux-x86_64.tar.gz && \
    tar -xzf julia-1.11.1-linux-x86_64.tar.gz -C /opt/ && \
    ln -s /opt/julia-1.11.1/bin/julia /usr/local/bin/julia && \
    rm julia-1.11.1-linux-x86_64.tar.gz

RUN julia -e 'using Pkg; Pkg.add.(["IJulia", "OrdinaryDiffEq", "Optimization", "OptimizationOptimJL", "Plots", "Statistics"])'


# Cleanup
# -------
RUN rm -rf ${LIB}/hdf5* ${LIB}/netcdf*

# bashrc
# ------
RUN echo "# Python Env\n############" >> ~/.bashrc && \
    echo "source $PYLIB/bin/activate" >> ~/.bashrc && \
    echo "source $LIB/oasis3-mct/BLD/python/init.sh" >> ~/.bashrc && \
    echo "\n# Easier Life\n#############" >> ~/.bashrc && \
    echo "alias ls='ls --color=auto'" >> ~/.bashrc && \
    echo "alias grep='grep --color=auto -H'\n" >> ~/.bashrc && \
    echo "\n# Permissions\n#############" >> ~/.bashrc && \
    echo "export OMPI_ALLOW_RUN_AS_ROOT=1" >> ~/.bashrc && \
    echo "export OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1" >> ~/.bashrc && \
    echo "cd $HOME" >> ~/.bashrc
