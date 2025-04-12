#!/usr/bin/env zsh
set -eo pipefail  # Exit immediately if any command fails
setopt sh_word_split

# IMPORTANT FOR C COMPILERS IF CONDA IS INSTALLED!
# Would highly recommend leaving this section as is. Otherwise, YAML errors may occur when compiling MPICH.
# Source conda's initialization script so that conda commands work properly.
if [ -f "$(conda info --base)/etc/profile.d/conda.sh" ]; then
  source "$(conda info --base)/etc/profile.d/conda.sh"
fi

# Deactivate active conda environment if present.
if command -v conda &>/dev/null && [[ -n "${CONDA_DEFAULT_ENV}" ]]; then
  echo " ⚠️ Deactivating conda environment: ${CONDA_DEFAULT_ENV}"
  conda deactivate
fi

# Set timer
start_time=$(date +%s)

##################
# Set up logging #
##################
exec 3>> compile.log

# Logging function: writes to compile.log and stdout
log() {
  printf "$@" >&3
  printf "$@"
}

# Command wrapper: runs a command, captures its output, and logs error output if it fails.
run_cmd() {
  output=$("$@" 2>&1)
  ret=$?
  if [[ $ret -ne 0 ]]; then
    log "Error: Command '$*' failed with output:"
    log "$output"
    exit $ret
  fi
}

#########################################
# Detect Latest Stable Library Versions #
#########################################
# Uses GitHub API to fetch latest release tags

get_latest_github_tag() {
    local repo="$1"
    local prefix="$2"

    curl -s "https://api.github.com/repos/${repo}/tags?per_page=100" |
        grep '"name":' |
        sed -E 's/.*"name": *"([^"]+)".*/\1/' |
        grep -E "^${prefix}[0-9]+\.[0-9]+\.[0-9]+$" |
        grep -vE 'alpha|beta|rc' |
        sort -V |
        tail -n 1 || true
}

echo " 🔄 Fetching latest library versions"

#####################################
# Define libraries and tag prefixes #
#####################################
typeset -A LIB_REPOS=(
  MPICH "pmodels/mpich v"
  ZLIB "madler/zlib v"
  LIBPNG "pnggroup/libpng v"
  NETCDF_C "Unidata/netcdf-c v"
  NETCDF_FORTRAN "Unidata/netcdf-fortran v"
  HDF5 "HDFGroup/hdf5 hdf5-"
  PNETCDF "Parallel-NetCDF/Pnetcdf checkpoint."
)

typeset -A VERSIONS

#####################################
# Fetch versions and strip prefixes #
#####################################
for lib in ${(k)LIB_REPOS}; do
    IFS=' ' read -r repo prefix <<< "${LIB_REPOS[$lib]}"
    tag=$(get_latest_github_tag "$repo" "$prefix")
    stripped="${tag#$prefix}"
    VERSIONS[$lib]="$stripped"
done

# Hardcoded Jasper version for WRF compatibility
VERSIONS[JASPER]="1.900.1"

##################################
# Print detected versions safely #
##################################
log " 📦 Detected Versions:\n"
for lib in MPICH HDF5 NETCDF_C NETCDF_FORTRAN PNETCDF ZLIB LIBPNG JASPER; do
    version=" ❌ <not found>"
    if [[ -n "${VERSIONS[$lib]}" ]]; then
         version="${VERSIONS[$lib]}"
    fi
    # Print a green tick emoji (you can change it if you prefer) before the lib name
    log " ✅ %-17s %s\n" "$lib" "$version"
done
log "------------------\n"

###############
# Build MPICH #
###############
MPICH_VERSION="${VERSIONS[MPICH]}"
log " ⏳ Downloading and building MPICH v${MPICH_VERSION}\n"

# Use base compilers for MPICH build
export CC=gcc
export CXX=g++
export FC=gfortran
export F77=gfortran

run_cmd wget "https://www.mpich.org/static/downloads/${MPICH_VERSION}/mpich-${MPICH_VERSION}.tar.gz" -O "mpich-${MPICH_VERSION}.tar.gz"
run_cmd tar -xf "mpich-${MPICH_VERSION}.tar.gz"

if ! cd "mpich-${MPICH_VERSION}"; then
  log " ❌ Error: Failed to enter MPICH directory"
  exit 1
fi

run_cmd ./configure --prefix="$MPICH_DIR" \
            CC="${CC}" \
            FC="${FC}" \
            CXX="${CXX}" \
            --enable-fortran \
            --enable-shared
run_cmd make -j "$WRF_DEP_JOBS"
run_cmd make install

cd ..
rm -rf "mpich-${MPICH_VERSION}.tar.gz" "mpich-${MPICH_VERSION}"

# Set up MPI runtime environment
export PATH="$MPICH_DIR/bin:$PATH"
export DYLD_LIBRARY_PATH="$MPICH_DIR/lib:$NETCDF/lib:$PNETCDF/lib:$GRIB2/lib:${DYLD_LIBRARY_PATH:-}"

# Check for mpirun file
log " ✅ MPICH was installed to: $MPICH_DIR\n"
log " ✅ mpirun points to: $(which mpirun)\n"
run_cmd mpicc --version || log " ❌ Warning: mpicc not working.\n"
log "------------------\n"

##############
# Build zlib #
##############
ZLIB_VERSION="${VERSIONS[ZLIB]}"
log " ⏳ Downloading and building zlib v${ZLIB_VERSION}\n"

run_cmd wget https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz -O zlib-${ZLIB_VERSION}.tar.gz
run_cmd tar xzvf zlib-${ZLIB_VERSION}.tar.gz

if ! cd "zlib-${ZLIB_VERSION}"; then
  log " ❌ Error: Failed to enter zlib directory"
  exit 1
fi

run_cmd ./configure --prefix="$GRIB2"
run_cmd make -j $WRF_DEP_JOBS
run_cmd make install
cd ..
rm -rf zlib-${ZLIB_VERSION} zlib-${ZLIB_VERSION}.tar.gz

# Check for the header file
if [[ -f "$GRIB2/include/zlib.h" ]]; then
  log " ✅ Found zlib header in $GRIB2/include\n"
else
  log " ❌ Warning: zlib header not found in $GRIB2/include\n"
fi
log "------------------\n"

###############
# Build PHDF5 #
###############
HDF5_VERSION="${VERSIONS[HDF5]}"
log " ⏳ Downloading and building parallel HDF5 v${HDF5_VERSION}\n"

run_cmd wget "https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-${HDF5_VERSION}.tar.gz" -O "hdf5-${HDF5_VERSION}.tar.gz"
run_cmd tar xzvf "hdf5-${HDF5_VERSION}.tar.gz"

if ! cd "hdf5-hdf5-${HDF5_VERSION}"; then
  log " ❌ Error: Failed to enter HDF5 directory"
  exit 1
fi

run_cmd ./configure --prefix="$NETCDF" \
                    CC=mpicc \
                    FC=mpifort \
                    --with-zlib="$GRIB2" \
                    --enable-fortran \
                    --enable-shared \
                    --enable-parallel
run_cmd make -j "$WRF_DEP_JOBS"
run_cmd make install

cd ..
rm -rf "hdf5-hdf5-${HDF5_VERSION}" "hdf5-${HDF5_VERSION}.tar.gz"

# Check for the header file
if [[ -f "$NETCDF/include/hdf5.h" ]]; then
  log " ✅ Found HDF5 header in $NETCDF/include\n"
else
  log " ❌ Warning: HDF5 header not found in $NETCDF/include\n"
fi
log "------------------\n"

################
# Build libpng #
################
LIBPNG_VERSION="${VERSIONS[LIBPNG]}"
log " ⏳ Downloading and building libpng v${LIBPNG_VERSION}\n"

run_cmd wget "https://download.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz" -O "libpng-${LIBPNG_VERSION}.tar.gz"
run_cmd tar xzvf "libpng-${LIBPNG_VERSION}.tar.gz"

if ! cd "libpng-${LIBPNG_VERSION}"; then
  log " ❌ Error: Failed to enter libpng directory"
  exit 1
fi

run_cmd ./configure --prefix="$GRIB2"
run_cmd make -j "$WRF_DEP_JOBS"
run_cmd make install

cd ..
rm -rf "libpng-${LIBPNG_VERSION}.tar.gz" "libpng-${LIBPNG_VERSION}"

# Check for the header file.
if [[ -f "$GRIB2/include/png.h" ]]; then
  log " ✅ Found libpng header in $GRIB2/include\n"
else
  log " ❌ Warning: libpng header not found in $GRIB2/include\n"
fi
log "------------------\n"

################
# Build jasper #
################
JASPER_VERSION=1.900.1
log " ⏳ Downloading and building jasper v${JASPER_VERSION}\n"

run_cmd wget "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-${JASPER_VERSION}.tar.gz" -O "jasper-${JASPER_VERSION}.tar.gz"
run_cmd tar xzvf "jasper-${JASPER_VERSION}.tar.gz"

if ! cd "jasper-${JASPER_VERSION}"; then
  log " ❌ Error: Failed to enter jasper directory"
  exit 1
fi

# Set additional CFLAGS to relax errors on ARM
export CFLAGS="-Wno-error=implicit-function-declaration -Wno-error=stringop-overflow"

run_cmd ./configure --prefix="$GRIB2" --build=aarch64-unknown-linux-gnu
run_cmd make -j "$WRF_DEP_JOBS"
run_cmd make install

cd ..
rm -rf "jasper-${JASPER_VERSION}.tar.gz" "jasper-${JASPER_VERSION}"

# Check for the Jasper header file.
if [[ -f "$GRIB2/include/jasper/jasper.h" ]]; then
  log " ✅ Found jasper header in $GRIB2/include\n"
else
  log " ❌ Warning: jasper header not found in $GRIB2/include\n"
fi
log "------------------\n"

#################
# Build PnetCDF #
#################
PNETCDF_VERSION="${VERSIONS[PNETCDF]}"
log " ⏳ Downloading and building PnetCDF v${PNETCDF_VERSION}\n"

run_cmd wget "https://parallel-netcdf.github.io/Release/pnetcdf-${PNETCDF_VERSION}.tar.gz" -O "pnetcdf-${PNETCDF_VERSION}.tar.gz"
run_cmd tar xzvf "pnetcdf-${PNETCDF_VERSION}.tar.gz"

if ! cd "pnetcdf-${PNETCDF_VERSION}"; then
  log " ❌ Error: Failed to enter PnetCDF directory"
  exit 1
fi

run_cmd ./configure --prefix="$PNETCDF" \
            CC=mpicc \
            CXX=mpicxx \
            F77=mpifort
run_cmd make -j "$WRF_DEP_JOBS"
run_cmd make install

cd ..
rm -rf "pnetcdf-${PNETCDF_VERSION}.tar.gz" "pnetcdf-${PNETCDF_VERSION}"

# Check for the PnetCDF header file.
if [[ -f "$PNETCDF/include/pnetcdf.h" ]]; then
  log " ✅ Found PnetCDF header in $PNETCDF/include\n"
else
  log " ❌ Warning: PnetCDF header not found in $PNETCDF/include\n"
fi
log "------------------\n"

##################
# Build netcdf-c #
##################
NETCDF_C_VERSION="${VERSIONS[NETCDF_C]}"
log " ⏳ Downloading and building netcdf-c v${NETCDF_C_VERSION}\n"

# Use MPI wrappers for netcdf-c when enabling parallel netCDF support
export CC=mpicc
export CXX=mpicxx
export FC=mpifort
export F77=mpifort

# Augment include and linker flags to locate HDF5 and PnetCDF installations
export CPPFLAGS="-I${NETCDF}/include -I${PNETCDF}/include"
export LDFLAGS="-L${NETCDF}/lib -L${PNETCDF}/lib"

run_cmd wget "https://github.com/Unidata/netcdf-c/archive/refs/tags/v${NETCDF_C_VERSION}.tar.gz" -O "netcdf-c-${NETCDF_C_VERSION}.tar.gz"
run_cmd tar xzvf "netcdf-c-${NETCDF_C_VERSION}.tar.gz"

if ! cd "netcdf-c-${NETCDF_C_VERSION}"; then
  log " ❌ Error: Failed to enter netcdf-c directory"
  exit 1
fi

run_cmd ./configure --prefix="$NETCDF" \
            --disable-dap \
            --enable-netcdf-4 \
            --enable-hdf5 \
            --enable-shared \
            --enable-pnetcdf \
            --enable-parallel-tests \
            LIBS="-L${PNETCDF}/lib -lpnetcdf"
run_cmd make -j "$WRF_DEP_JOBS"

log " ⏳ Running netcdf-c test suite\n"
run_cmd make check
run_cmd make install

cd ..
rm -rf "netcdf-c-${NETCDF_C_VERSION}.tar.gz" "netcdf-c-${NETCDF_C_VERSION}"

# Check for the NetCDF-c header file.
if [[ -f "$NETCDF/include/netcdf.h" ]]; then
  log " ✅ Found netcdf-c header in $NETCDF/include\n"
else
  log " ❌ Warning: netcdf-c header not found in $NETCDF/include\n"
fi
log "------------------\n"

########################
# Build netcdf-fortran #
########################
NETCDF_FORTRAN_VERSION="${VERSIONS[NETCDF_FORTRAN]}"
log " ⏳ Downloading and building netcdf-fortran v${NETCDF_FORTRAN_VERSION}\n"

# Use MPI wrappers so that nf-config is built correctly.
export CC=mpicc
export FC=mpifort
export PATH="$NETCDF/bin:$PATH"
export LIBS="-lnetcdf -lz"

run_cmd wget "https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v${NETCDF_FORTRAN_VERSION}.tar.gz" -O "netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz"
run_cmd tar xzvf "netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz"

if ! cd "netcdf-fortran-${NETCDF_FORTRAN_VERSION}"; then
  log " ❌ Error: Failed to enter netcdf-fortran directory"
  exit 1
fi

run_cmd ./configure --prefix="$NETCDF" \
            --disable-hdf5 \
            --enable-shared
run_cmd make -j "$WRF_DEP_JOBS"

log " ⏳ Running netcdf-fortran test suite\n"
run_cmd make check
run_cmd make install

cd ..
rm -rf "netcdf-fortran-${NETCDF_FORTRAN_VERSION}.tar.gz" "netcdf-fortran-${NETCDF_FORTRAN_VERSION}"

# Check for the NetCDF-c header file.
if ls "$NETCDF/lib" | grep -q -E 'libnetcdff\.(a|so)'; then
  log " ✅ Found netcdf-fortran library in $NETCDF/lib\n"
else
  log " ❌ Warning: netcdf-fortran library not found in $NETCDF/lib\n"
fi
log "------------------\n"

# Total time
end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
hours=$(( elapsed / 3600 ))
minutes=$(( (elapsed % 3600) / 60 ))
seconds=$(( elapsed % 60 ))

log " ⏰ Library compilation took: %02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
