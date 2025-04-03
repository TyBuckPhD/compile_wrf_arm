#!/usr/bin/env bash
set -euo pipefail

REGISTRY_FILE="WRF/Registry/registry.EM_COMMON"

if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo "❌ ERROR: Cannot find $REGISTRY_FILE"
    exit 1
fi

echo "Injecting CTT variable into Registry..."

# Check for exact match
if grep -Eq '^[[:space:]]*state[[:space:]]+real[[:space:]]+CTT[[:space:]]' "$REGISTRY_FILE"; then
    echo "⚠️  CTT already exists in Registry — skipping injection."
    exit 0
fi

# Match on the field description line, which is stable
awk '
    /"SURFACE SKIN TEMPERATURE"/ && !found {
        print
        print "state   real    CTT         ikj    misc        1         -         i3rh        \"CTT\"        \"Cloud top temperature\" \"K\""
        found=1
        next
    }
    { print }
' "$REGISTRY_FILE" > tmp && mv tmp "$REGISTRY_FILE"

echo "✅ CTT successfully injected into $REGISTRY_FILE"
