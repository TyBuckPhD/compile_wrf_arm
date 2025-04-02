#!/usr/bin/env zsh
set -euo pipefail

##################
# Set up logging #
##################
exec 3>> compile.log

# Logging function: writes to compile.log and stdout.
log() {
  printf "%b" "$@" >&3
  printf "%b" "$@"
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

#############################
# Check for Homebrew prefix #
#############################
# This loop will try once; if brew is not installed, it logs an error and exits.
if ! brew_prefix=$(brew --prefix 2>/dev/null); then
  log " ❌ Homebrew is not installed. Please install Homebrew before continuing.\n"
  exit 1
fi

###########################
# check_gcc functionality #
###########################
log "------------------\n"
log " ⏳ Checking gcc version\n"

# Check if gcc is installed.
if ! command -v gcc &>/dev/null; then
  log " ❌ GCC is not installed. Please install via Homebrew\n"
  exit 1
fi

# Get the currently used gcc path.
current_gcc=$(command -v gcc)
log " 🔄 Current gcc found: $current_gcc\n"


# If current gcc is not the Homebrew version (i.e. not from /opt/homebrew/bin/gcc-*)
brew_prefix=$(brew --prefix)
if [[ "$current_gcc" != *"/homebrew/"* ]]; then
  log " ❌ Current gcc is not the Homebrew version\n"
  log " 🔍 Searching system-wide for Homebrew GCC\n"
  # Check if any Homebrew GCC exists
  if compgen -G *"/homebrew/"* > /dev/null; then
    homebrew_gcc=$(ls "$brew_prefix/bin/gcc" 2>/dev/null | sort -V | tail -n 1)
    # Determine the main version from the Homebrew gcc executable
    main_version=$("$homebrew_gcc" -dumpversion | cut -d. -f1)
    log " ✅ Homebrew GCC found: $homebrew_gcc (version: $main_version)\n"
    
    # Build the symlinks in /usr/local/bin so that gcc and g++ point to the Homebrew version
    log " 🔄 Creating symlinks in /usr/local/bin for Homebrew GCC/G++\n"
    sudo ln -s gcc-$main_version gcc
    sudo ln -s g++-$main_version g++
  else
    log " ❌ Homebrew GCC not found system-wide. Please install GCC via Homebrew before continuing\n"
    exit 1
  fi
fi

# Test if 'which gcc' now points to the Homebrew symlink.
final_gcc=$(which gcc)
log " 🔄 Final gcc symlink: $final_gcc\n"
if [[ "$final_gcc" != "$brew_prefix/bin/gcc" ]]; then
  log " ❌ Symlink not properly set. 'which gcc' returns: $final_gcc\n"
  exit 1
fi

# Run gcc --version and log its output.
run_cmd gcc --version

# Check and display the main GCC version.
main_version=$(gcc -dumpversion | cut -d. -f1)
log " 🔄 GCC main version: $main_version\n"

log " ✅ Finished check_gcc script successfully.\n"
log " ✅ Using gcc from: $(which gcc)\n"
