#!/bin/bash
# snap/local/reset-config.sh
#
# Manually overwrites the managed config at
# $SNAP_COMMON/config/usb_cam.yaml with the packaged default, discarding
# any local edits.
set -eu

DEFAULT_CONFIG_FILE="$SNAP_COMMON/config/usb_cam.yaml"

mkdir -p "$SNAP_COMMON/config"
cp "$SNAP/etc/configuration/default-params.yaml" "$DEFAULT_CONFIG_FILE"

echo "usb-cam: reset $DEFAULT_CONFIG_FILE to packaged defaults" >&2
echo "usb-cam: run 'sudo snap restart $SNAP_NAME' to apply" >&2
