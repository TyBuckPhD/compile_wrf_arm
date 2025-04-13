#!/usr/bin/env zsh
set -eo pipefail  # Exit immediately if any command fails

# Parse command-line arguments for --dir flag
DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      if [[ -z "$2" ]]; then
        echo "Error: No directory specified after --dir" >&2
        exit 1
      fi
      DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Check if DIR was provided
if [[ -z "$DIR" ]]; then
  echo "❌ Error: Installation directory not specified. Please provide the --dir flag." >&2
  exit 1
fi

mkdir -p "$DIR"

##################
# Set up logging #
##################
exec 3>> compile.log
log() {
  printf "$@" >&3
  printf "$@"
}

# Command wrapper: runs a command, captures its output, and logs error output if it fails.
run_cmd() {
  output=$("$@" 2>&1)
  ret=$?
  if [[ $ret -ne 0 ]]; then
    log "Error: Command '$*' failed with output:\n"
    log "$output\n"
    exit $ret
  fi
}

log " ⏳ Setting Environment file\n"

# Define the environment file path
ENV_FILE="$DIR/wrf_environment.sh"

# Create the environment file if it doesn't exist.
# It will contain only the export commands.
if [ ! -f "$ENV_FILE" ]; then
  cat << EOF > "$ENV_FILE"
export REPO_DIR="$PWD"
export DIR="${DIR}"
export WRF_DEP_JOBS=8

export NETCDF="${DIR}/netcdf"
export GRIB2="${DIR}/grib2"
export PNETCDF="${DIR}/pnetcdf"
export MPICH_DIR="${DIR}/mpich"

export CFLAGS="-O2"
export FCFLAGS="-w -fallow-argument-mismatch -O2"
export FFLAGS="-w -fallow-argument-mismatch -O2"
export LDFLAGS="-L${NETCDF}/lib"
export CPPFLAGS="-I${NETCDF}/include"

export CC="${MPICH_DIR}/bin/mpicc"
export CXX="${MPICH_DIR}/bin/mpicxx"
export FC="${MPICH_DIR}/bin/mpifort"

export JASPERLIB="${GRIB2}/lib"
export JASPERINC="${GRIB2}/include"
export HDF5="${DIR}/netcdf"
export PHDF5="${DIR}/netcdf"
export PNETCDF="${DIR}/pnetcdf"

export PATH="${MPICH_DIR}/bin:${NETCDF}/bin:${PATH}"
export DYLD_LIBRARY_PATH="$MPICH_DIR/lib:$NETCDF/lib:$PNETCDF/lib:$GRIB2/lib:${DYLD_LIBRARY_PATH:-}"
EOF
  chmod +x "$ENV_FILE"
  log " ✅ Created environment file at $ENV_FILE\n"
else
  log " ⚠️ Environment file already exists at $ENV_FILE\n"
fi
