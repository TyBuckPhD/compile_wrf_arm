#!/usr/bin/env zsh
set -eo pipefail
setopt sh_word_split

# Set timer
start_time=$(date +%s)

##################
# Set up logging #
##################
exec 3>> test_executables.log

# Logging function: writes to compile.log and (optionally) stdout
log() {
  printf "$@" >&3
  printf "$@"
}

# Command wrapper: run a command, capture its output, and log error output if it fails.
run_cmd() {
  output=$("$@" 2>&1)
  ret=$?
  if [[ $ret -ne 0 ]]; then
    log "Error: Command '$*' failed with output:\n"
    log "$output\n"
    exit $ret
  fi
}

##################################################
# Define key directories based on repo structure #
##################################################
SCRIPT_DIR="$(cd "$(dirname -- "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Directory containing compiled WRF executables and related subdirectories
WPS_DIR="${REPO_ROOT}/WPS"
WRF_RUN_DIR="${REPO_ROOT}/WRF/run"
GEOG_DIR="${REPO_ROOT}/geog"
DATA_DIR="${SCRIPT_DIR}/data"
OUTPUT_DIR="${SCRIPT_DIR}/output"

###########################
# Update namelist entries #
###########################

sed -i '' -E "s|(geog_data_path[[:space:]]*=[[:space:]]*)'.*'|\1'${GEOG_DIR}'|" "${SCRIPT_DIR}/namelist.wps"
sed -i '' -E "s|(history_outname[[:space:]]*=[[:space:]]*)'.*'|\1'${OUTPUT_DIR}/wrfout_d<domain>_<date>.nc'|" "${SCRIPT_DIR}/namelist.input"

###########
# Run WPS #
###########

log "\nCopying namelist.wps to ${WPS_DIR}\n"
run_cmd cp "${SCRIPT_DIR}/namelist.wps" "${WPS_DIR}/"

log "\nLinking vtable for ERA5 data in ${WPS_DIR}\n"
cd "${WPS_DIR}"
run_cmd ln -sf ungrib/Variable_Tables/Vtable.ECMWF Vtable

log "\nRunning link_grib with data directory ${DATA_DIR}\n"
run_cmd ./link_grib.csh "${DATA_DIR}/era5*"

log "\nRunning ungrib.exe\n"
run_cmd ./ungrib.exe

log "\nRunning geogrid.exe\n"
run_cmd ./geogrid.exe

log "\nRunning metgrid.exe\n"
run_cmd mpirun -np 4 ./metgrid.exe

log "\nWPS workflow completed.\n"

# End timer and log execution time
end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
hours=$(( elapsed / 3600 ))
minutes=$(( (elapsed % 3600) / 60 ))
seconds=$(( elapsed % 60 ))
log "\n⏰ Total execution time: %02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
