#!/bin/sh
# snap/local/reset-config.sh
#
# Manually overwrites the managed config at
# $SNAP_COMMON/config/usb_cam.yaml with the packaged default, discarding
# any local edits.
#
# Also unsets the `video-device` shortcut: if it stayed set, the configure
# hook would patch the old device back into the freshly reset file on the
# next `snap set` of any key.
set -eu

DEFAULT_CONFIG_FILE="$SNAP_COMMON/config/usb_cam.yaml"

mkdir -p "$SNAP_COMMON/config"
cp "$SNAP/etc/configuration/default-params.yaml" "$DEFAULT_CONFIG_FILE"
snapctl unset video-device

echo "usb-cam: reset $DEFAULT_CONFIG_FILE to packaged defaults (and unset 'video-device')" >&2
echo "usb-cam: run 'sudo snap restart $SNAP_NAME' to apply" >&2
