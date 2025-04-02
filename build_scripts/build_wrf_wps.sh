#!/usr/bin/env zsh
set -eo pipefail  # Exit immediately if any command fails
setopt sh_word_split

# Set timer
start_time=$(date +%s)

# Parse command-line arguments for --dir flag
DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      DIR="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1\n" >&2
      exit 1
      ;;
  esac
done

# Check if DIR was provided
if [[ -z "$DIR" ]]; then
  echo "Error: Installation directory not specified. Please provide the --dir flag\n" >&2
  exit 1
fi

##################
# Set up logging #
##################
exec 3>> compile.log

# Logging function: writes to compile.log and (optionally) stdout
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

log " ⏳ Building WPS and WRF\n"

#########################################
# Set Environment Variables for WRF/WPS #
#########################################
# Relevant PnetCDF exports
export HDF5="$DIR/netcdf"
export PHDF5="$DIR/netcdf"
export PNETCDF="$DIR/pnetcdf"

# Relevant MPI exports
export CC="$MPICH_DIR/bin/mpicc"
export CXX="$MPICH_DIR/bin/mpicxx"
export FC="$MPICH_DIR/bin/mpifort"

# Update PATH and library search path so MPI wrappers and netCDF utilities are found
export PATH="$NETCDF/bin:$PATH"
export PATH="$MPICH_DIR/bin:$NETCDF/bin:$PATH"
export DYLD_LIBRARY_PATH="$MPICH_DIR/lib:$NETCDF/lib:$PNETCDF/lib:$GRIB2/lib:${DYLD_LIBRARY_PATH:-}"

# Capture the output of the nc-config command.
nc_output=$("$NETCDF/bin/nc-config" --has-pnetcdf)
log " ⚠️  Does NetCDF have parallel enabled?: ${nc_output}\n"
log "------------------\n"

# Check if the output is "no", and exit if so.
if [[ "$nc_output" == "no" ]]; then
    log " ❌ pnetcdf support is not available - recompile libraries and try again\n"
    exit 1
fi

###########################
# Clone and Configure WRF #
###########################
log " ⏳ Cloning WRF repository\n"
if [ ! -d "WRF" ]; then
    git clone --recurse-submodule https://github.com/wrf-model/WRF.git || { log " ❌ WRF clone failed\n"; exit 1; }
fi

cd WRF || { log " ❌ Cannot enter WRF directory\n"; exit 1; }

model_config=35
compiler_opt=1
log " 🔄 Configuring WRF with model configuration: $model_config and compiler option: $compiler_opt\n"

./configure <<EOF
$model_config
$compiler_opt
EOF

###############
# Compile WRF #
###############
log " ⏳ Compiling WRF\n"
./compile em_real -j 4 >& log.compile_wrf
if [ $? -eq 0 ]; then
    log " ✅ WRF compiled successfully\n"
else
    log " ❌ WRF compilation failed - see log.compile_wrf for details\n"
    exit 1
fi

# Return to parent directory
cd ..

log " ✅ WRF build complete\n"
log "------------------\n"

###########################
# Clone and Configure WPS #
###########################
log " ⏳ Cloning WPS repository\n"
if [ ! -d "WPS" ]; then
    git clone --recurse-submodule https://github.com/wrf-model/WPS.git || { log " ❌ WPS clone failed\n"; exit 1; }
fi

cd WPS || { log " ❌ Cannot enter WPS directory\n"; exit 1; }

wps_config=19
log " 🔄 Configuring WPS with configuration: $wps_config\n"

./configure <<EOF
$wps_config
EOF

###############
# Compile WPS #
###############
log " ⏳ Compiling WPS\n"
./compile >& log.compile_wps
if [ $? -eq 0 ]; then
    log " ✅ WPS compiled successfully\n"
else
    log " ❌ WPS compilation failed. See log.compile_wps for details\n"
    exit 1
fi

# Return to parent directory
cd ..

log " ✅ WPS build complete\n"
log "------------------\n"

############################
# Test WRF/WPS Executables #
############################
log " 🔄 Running post-build tests for WRF/WPS executables\n"
log "------------------\n"
WRF_MAIN_DIR="WRF/main"

# List of expected WRF executables
wrf_executables=(wrf.exe real.exe ndown.exe tc.exe)

for exe in "${wrf_executables[@]}"; do
    exe_path="$WRF_MAIN_DIR/$exe"
    if [ -x "$exe_path" ] && [ -s "$exe_path" ]; then
        log " ✅ $exe_path exists and is built correctly\n"
    else
        log " ❌ Error: $exe_path is missing or invalid\n"
        exit 1
    fi
done

log " ✅ All WRF executable tests passed successfully\n"
log "------------------\n"
WPS_MAIN_DIR="WPS"

# List of expected WPS executables
wps_executables=(geogrid.exe ungrib.exe metgrid.exe)

for exe in "${wps_executables[@]}"; do
    exe_path="$WPS_MAIN_DIR/$exe"
    if [ -x "$exe_path" ] && [ -s "$exe_path" ]; then
        log " ✅ $exe_path exists and is built correctly\n"
    else
        log " ❌ Error: $exe_path is missing or invalid\n"
        exit 1
    fi
done

log " ✅ All WRF/WPS executable tests passed successfully\n"
log "------------------\n"

# Total time
end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
hours=$(( elapsed / 3600 ))
minutes=$(( (elapsed % 3600) / 60 ))
seconds=$(( elapsed % 60 ))

log " ⏰ WRF/WPS compilation took: %02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
