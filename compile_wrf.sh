#!/usr/bin/env zsh
set -euo pipefail  # Exit immediately if any command fails

# Set timer
start_time=$(date +%s)

##################
# Set up logging #
##################
exec 3>> compile.log

# Logging function: writes to compile.log and stdout.
log() {
  printf "$@" >&3
  printf "$@"
}

#############################
# WRF Compilation Pipeline  #
#############################
log "------------------\n"
log " ⏳ Starting WRF compilation pipeline\n"
log "------------------\n"

# Run check_gcc.sh
log " 🔄 Running check_gcc.sh\n"
./build_scripts/check_gcc.sh || { log " ❌ check_gcc.sh failed\n"; exit 1; }
log "------------------\n"

# Run build_env_file.sh
log " 🔄 Running build_env_file.sh\n"
./build_scripts/build_env_file.sh --dir "$(pwd)/wrf_dependencies" || { log " ❌ build_env_file.sh failed\n"; exit 1; }
log "------------------\n"

# Make sure all environment paramaters are passed to the pipeline
source "$(pwd)/wrf_dependencies/wrf_environment.sh"
log " 🔄 Testing environment\n"
log " 📦 NETCDF: $NETCDF \n"
log "------------------\n"

# Run build_libraries.sh
log " 🔄 Running build_libraries.sh\n"
./build_scripts/build_libraries.sh || { log " ❌ build_libraries.sh failed\n"; exit 1; }
log "------------------\n"

# Run build_wrf_wps.sh
log " 🔄 Running build_wrf_wps.sh\n"
./build_scripts/build_wrf_wps.sh --dir "$(pwd)/wrf_dependencies" || { log " ❌ build_wrf_wps.sh failed\n"; exit 1; }
log "------------------\n"

# Run build_geog.sh
log " 🔄 Running build_geog.sh\n"
./build_scripts/build_geog.sh || { log " ❌ build_geog.sh failed\n"; exit 1; }
log "------------------\n"

# Total time
end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
hours=$(( elapsed / 3600 ))
minutes=$(( (elapsed % 3600) / 60 ))
seconds=$(( elapsed % 60 ))

log " ⏰ Full compilation took: %02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
