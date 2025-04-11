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
log " ⏳ Starting WPS/WRF executable tests\n"
log "------------------\n"

sed -i '' -E "s|(geog_data_path[[:space:]]*=[[:space:]]*)'.*'|\1'${GEOG_DIR}'|" "${SCRIPT_DIR}/namelist.wps"
sed -i '' -E "s|(history_outname[[:space:]]*=[[:space:]]*)'.*'|\1'${OUTPUT_DIR}/wrfout_d<domain>_<date>.nc'|" "${SCRIPT_DIR}/namelist.input"

log " ✅ Namelists updated with geography and output paths\n"
log "------------------\n"

###########
# Run WPS #
###########

log " ⏳ Running WPS\n"
log " ⏳ Copying namelist.wps to ${WPS_DIR}\n"
run_cmd cp "${SCRIPT_DIR}/namelist.wps" "${WPS_DIR}/" || { log " ❌ Copying namelist.wps failed. Check namelist.wps is present\n"; exit 1; }

log " ⏳ Linking vtable for ERA5 data\n"
cd "${WPS_DIR}" || { log " ❌ Could not cd into ${WPS_DIR}. Does it exist?\n"; exit 1; }
run_cmd ln -sf ungrib/Variable_Tables/Vtable.ECMWF Vtable || { log " ❌ Linking vtable failed. Check vtable directory\n"; exit 1; }

log " ⏳ Running link_grib with data directory ${DATA_DIR}\n"
run_cmd ./link_grib.csh "${DATA_DIR}/era5*" || { log " ❌ Linking data failed. Check data directory\n"; exit 1; }

log " ⏳ Running ungrib.exe\n"
run_cmd ./ungrib.exe || { log " ❌ ungrib.exe failed. Perhaps an issue with the executable or input data?\n"; exit 1; }

log " ⏳ Running geogrid.exe\n"
run_cmd ./geogrid.exe || { log " ❌ geogrid.exe failed. Perhaps an issue with the executabl or geography directory?\n"; exit 1; }

log " ⏳ Running metgrid.exe\n"
run_cmd mpirun -np 4 ./metgrid.exe || { log " ❌ metgrid.exe failed. Perhaps an issue with the executable?\n"; exit 1; }

log " ✅ WPS pipeline successfully completed\n"
log "------------------\n"

log " ⏳ Running WRF\n"
log " ⏳ Copying namelist.input to ${WRF_RUN_DIR}\n"
cd "${WRF_RUN_DIR}" || { log " ❌ Could not cd into ${WRF_RUN_DIR}. Does it exist?\n"; exit 1; }
run_cmd cp "${SCRIPT_DIR}/namelist.input" "${WRF_RUN_DIR}/" || { log " ❌ Copying namelist.input failed. Check namelist.input is present\n"; exit 1; }

log " ⏳ Linking met_em data\n"
run_cmd ln -sf ${WPS_DIR}/met_em* . || { log " ❌ Could not link met_em data to the WRF directory. Does it exist?\n"; exit 1; }

log " ⏳ Running real.exe\n"
run_cmd mpirun -np 4 ./real.exe || { log " ❌ real.exe failed. Perhaps an issue with the executable or namelist.input?\n"; exit 1; }

log " ⏳ Running wrf.exe\n"
run_cmd mpirun -np 4 ./wrf.exe || { log " ❌ wrf.exe failed. Perhaps an issue with the executable or hardware (e.g., CPU number)?\n"; exit 1; }

log " ✅ WRF pipeline successfully completed\n"
log " ✅ Output data can be found in ${OUTPUT_DIR}\n"
log "------------------\n"

# End timer and log execution time
end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
hours=$(( elapsed / 3600 ))
minutes=$(( (elapsed % 3600) / 60 ))
seconds=$(( elapsed % 60 ))
log "\n⏰ Total execution time: %02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
