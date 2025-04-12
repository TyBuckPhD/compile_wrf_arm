#!/usr/bin/env bash
set -euo pipefail

##################
# Set up logging #
##################
LOG_FILE="compile.log"
exec 3>> "$LOG_FILE"

log() {
  printf "%b" "$@" | tee /dev/fd/3
}

run_cmd() {
  output=$("$@" 2>&1)
  ret=$?
  if [[ $ret -ne 0 ]]; then
    log " ❌ Error: Command '$*' failed with output:\n"
    log "$output\n"
    exit $ret
  fi
  log "$output\n"
}

##########################
# Check and configure GCC
##########################

log " 🔍 Checking for Homebrew GCC and G++...\n"

BREW_GCC_PREFIX=$(brew --prefix gcc)
GCC_BIN_DIR="${BREW_GCC_PREFIX}/bin"

LATEST_GCC=$(ls "${GCC_BIN_DIR}"/gcc-* 2>/dev/null | grep -Eo 'gcc-[0-9]+' | sort -V | tail -1 || true)
LATEST_GPP=$(ls "${GCC_BIN_DIR}"/g++-* 2>/dev/null | grep -Eo 'g\+\+-[0-9]+' | sort -V | tail -1 || true)

if [[ -z "$LATEST_GCC" || -z "$LATEST_GPP" ]]; then
  log " ❌ Could not detect versioned Homebrew GCC or G++ in ${GCC_BIN_DIR}\n"
  exit 1
fi

log " ✅ Found Homebrew GCC: $LATEST_GCC\n"
log " ✅ Found Homebrew G++: $LATEST_GPP\n"

# Create temp wrapper directory for unversioned gcc/g++
GCC_WRAPPER_DIR="$(mktemp -d)"
ln -s "${GCC_BIN_DIR}/${LATEST_GCC}" "${GCC_WRAPPER_DIR}/gcc"
ln -s "${GCC_BIN_DIR}/${LATEST_GPP}" "${GCC_WRAPPER_DIR}/g++"

export PATH="${GCC_WRAPPER_DIR}:${PATH}"

#############################
# Confirm configuration
#############################

log " 🔧 Overridden gcc and g++ using symlink wrappers\n"
log " 📦 which gcc: $(which gcc)\n"
log " 📦 which g++: $(which g++)\n"
log " 🧪 gcc version: $(gcc --version | head -n 1)\n"
log " 🧪 g++ version: $(g++ --version | head -n 1)\n"

log " ✅ GCC wrapper setup complete.\n"
