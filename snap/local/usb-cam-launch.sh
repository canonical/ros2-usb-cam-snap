#!/bin/bash
# snap/local/usb-cam-launch.sh
#
# Entry point for the `usb-cam` daemon app. Reads snap configuration at
# startup and launches the upstream usb_cam node.
set -eu

if [ ! -d "$SNAP/opt/ros/underlay_ws/opt/ros/$ROS_DISTRO" ]; then
  echo "usb-cam: the 'ros-jazzy-ros-base' content interface is not connected (\$SNAP/opt/ros/underlay_ws is empty)." >&2
  echo "usb-cam: run: sudo snap connect $SNAP_NAME:ros-jazzy-ros-base ros-jazzy-ros-base && sudo snap restart $SNAP_NAME" >&2
  exit 1
fi

if ! command -v ros2 >/dev/null 2>&1; then
  echo "usb-cam: 'ros2' not found on PATH even though the content interface looks connected -- this is unexpected, please report a bug." >&2
  exit 1
fi

# Default config file seeded once by snap/hooks/install and kept in sync
# by snap/hooks/configure (video-device= patches its video_device line).
# This is the fallback used when no `config-file` override is set.
DEFAULT_CONFIG_FILE="$SNAP_COMMON/config/usb_cam.yaml"
PARAMS_FILE="$DEFAULT_CONFIG_FILE"

# Define a separate location for URL-fetched overrides so we don't override the default config file.
CONFIG_FILE_DOWNLOAD="$SNAP_COMMON/config/usb_cam.remote.yaml"

NAMESPACE="$(snapctl get namespace)"
CONFIG_FILE="$(snapctl get config-file)"
DOMAIN_ID="$(snapctl get domain-id)"

if [ -n "$CONFIG_FILE" ] && printf '%s' "$CONFIG_FILE" | grep -qE '^https?://'; then
  # Full-override config file served from a URL: re-download on every start
  # so an upstream update is picked up on the next launch/restart.
  mkdir -p "$(dirname "$CONFIG_FILE_DOWNLOAD")"
  echo "usb-cam: downloading config-file override from $CONFIG_FILE" >&2
  if ! curl --fail --silent --show-error --location \
      --output "$CONFIG_FILE_DOWNLOAD" "$CONFIG_FILE"; then
    echo "usb-cam: failed to download config-file from $CONFIG_FILE" >&2
    exit 1
  fi
  PARAMS_FILE="$CONFIG_FILE_DOWNLOAD"
elif [ -n "$CONFIG_FILE" ]; then
  PARAMS_FILE="$CONFIG_FILE"
fi

if [ ! -f "$PARAMS_FILE" ]; then
  echo "usb-cam: configuration file not found at $PARAMS_FILE" >&2
  echo "usb-cam: this is unexpected because the snap seeds a default config on install; check the file or reinstall the snap" >&2
  exit 1
fi

set -- ros2 run usb_cam usb_cam_node_exe --ros-args --params-file "$PARAMS_FILE"

if [ -n "$NAMESPACE" ]; then
  set -- "$@" -r __ns:="$NAMESPACE"
fi

if [ -n "$DOMAIN_ID" ]; then
  export ROS_DOMAIN_ID="$DOMAIN_ID"
fi

echo "usb-cam: exec: $*" >&2
exec "$@"
