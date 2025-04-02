#!/usr/bin/env zsh
set -eo pipefail  # Exit immediately if any command fails
setopt sh_word_split

# Set timer
start_time=$(date +%s)

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

#####################
# Get Geography URL #
#####################
: ${GEOG_PAGE_URL:="https://www2.mmm.ucar.edu/wrf/users/download/get_sources_wps_geog.html"}

# Use the current working directory for extraction
EXTRACT_DIR=$(pwd)

# Temporary file to store the HTML page
TEMP_HTML=$(mktemp /tmp/geog_page.XXXXXX.html)

###########################################
# Download the WRF Geography Data details #
##########################################
log " ⏳ Downloading geography data page from $GEOG_PAGE_URL\n"
wget -O "$TEMP_HTML" "$GEOG_PAGE_URL"

# Find link containing the tarball
TARBALL_REL=$(grep -Eo 'href="[^"]*geog_high_res_mandatory\.tar\.gz' "$TEMP_HTML" | sed 's/href="//' | head -n 1)

if [ -z "$TARBALL_REL" ]; then
    log " ❌ Could not find geog_high_res_mandatory.tar.gz link on the page\n"
    rm "$TEMP_HTML"
    exit 1
fi

# Determine if the URL is absolute or relative
if [[ "$TARBALL_REL" == http* ]]; then
    TARBALL_URL="$TARBALL_REL"
elif [[ "$TARBALL_REL" == /* ]]; then
    TARBALL_URL="https://www2.mmm.ucar.edu${TARBALL_REL}"
else
    BASE_URL="${GEOG_PAGE_URL%/*}"
    TARBALL_URL="${BASE_URL}/${TARBALL_REL}"
fi

log " ✅ Found tarball URL: $TARBALL_URL\n"
rm "$TEMP_HTML"

####################################
# Download and Extract the Tarball #
####################################
TARBALL_FILE="geog_high_res_mandatory.tar.gz"

log " ⏳ Downloading the geography tarball\n"
wget -c "$TARBALL_URL" -O "$TARBALL_FILE"

log " ⏳ Extracting $TARBALL_FILE to current directory: $EXTRACT_DIR\n"
tar -xzvf "$TARBALL_FILE" -C "$EXTRACT_DIR"

# The tarball should extract a folder named "WPS_GEOG".
if [ -d "$EXTRACT_DIR/WPS_GEOG" ]; then
    log " 🔄 Renaming extracted directory 'WPS_GEOG' to 'geog'\n"
    if [ -d "$EXTRACT_DIR/geog" ]; then
        log " ⚠️  Warning: Directory 'geog' already exists - removing it\n"
        rm -rf "$EXTRACT_DIR/geog"
    fi
    mv "$EXTRACT_DIR/WPS_GEOG" "$EXTRACT_DIR/geog"
else
    log " ❌ Expected directory 'WPS_GEOG' not found\n"
fi

log " ⏳ Removing downloaded tarball: $TARBALL_FILE\n"
rm -f "$TARBALL_FILE"

log " ✅ Geography static data download and extraction complete\n"
log "------------------\n"
log " ⏳ Updating WPS/namelist.wps with new geog_data_path: ${EXTRACT_DIR}/geog\n"
sed -i.bak "s|geog_data_path *= *'[^']*'|geog_data_path = '${EXTRACT_DIR}/geog'|" WPS/namelist.wps
log "------------------\n"

# Total time
end_time=$(date +%s)
elapsed=$(( end_time - start_time ))
hours=$(( elapsed / 3600 ))
minutes=$(( (elapsed % 3600) / 60 ))
seconds=$(( elapsed % 60 ))

log " ⏰ WRF geog data download took: %02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
