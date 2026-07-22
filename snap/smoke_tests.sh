#!/usr/bin/env bash
# Smoke tests for the usb-cam snap.
#
# Run this on a machine with snapd (the build container here has no
# passwordless sudo, so these must be run interactively by a human):
#
#   bash snap/smoke_tests.sh
#
# IMPORTANT: step 6+ actually opens a real camera device. Only point
# `device=` at real hardware (e.g. /dev/video4) once you're ready to use it;
# a non-existent path (e.g. /dev/video99) is safe for steps 1-5 and will just
# make the daemon fail to open the device (visible in `snap logs`) without
# touching any hardware.
set -euo pipefail

SNAP_FILE=$(ls "$(dirname "$0")"/../*.snap | head -1)
SNAP_NAME=usb-cam

echo "=== 1. Installing snap ==="
sudo snap install "$SNAP_FILE" --dangerous
sleep 3  # wait for AppArmor policies to load

echo "=== 1b. Connecting the ros-jazzy-ros-base content interface ==="
echo "    Sideloaded/--dangerous installs are not auto-connected by snapd (unlike"
echo "    Snap Store installs, which auto-connect via the content plug's"
echo "    default-provider) -- this manual step is only needed for local/CI testing:"
sudo snap connect "$SNAP_NAME":ros-jazzy-ros-base ros-jazzy-ros-base

echo "=== 2. Checking snap is installed ==="
snap list "$SNAP_NAME"

echo "=== 3. Checking confinement + interfaces (camera should be strict/manual, content should be connected) ==="
snap connections "$SNAP_NAME"

echo "=== 4. Checking the managed default config was seeded by the install hook ==="
sudo test -f /var/snap/"$SNAP_NAME"/common/config/usb_cam.yaml
echo "OK: /var/snap/$SNAP_NAME/common/config/usb_cam.yaml exists"
echo "--- initial health (expected: waiting, no video_device configured yet) ---"
snap info --verbose "$SNAP_NAME" | grep -A1 '^health:' || true

echo "=== 5. Configuring via the 'device' shortcut with a non-existent path (safe, no hardware touched) ==="
sudo snap set "$SNAP_NAME" device=/dev/video99
sleep 2
snap services "$SNAP_NAME"
grep -q 'video_device: "/dev/video99"' <(sudo cat /var/snap/"$SNAP_NAME"/common/config/usb_cam.yaml)
echo "OK: managed config file patched with device=/dev/video99"
echo "--- last 20 log lines (expected: node fails to open /dev/video99, then restarts) ---"
sudo snap logs "$SNAP_NAME" -n 20 || true

echo "=== 5b. Configuring via a separate config-file override (safe, no hardware touched) ==="
sudo mkdir -p /var/snap/"$SNAP_NAME"/common/my-config
cat <<'EOF' | sudo tee /var/snap/"$SNAP_NAME"/common/my-config/usb_cam.yaml >/dev/null
/**:
  ros__parameters:
    video_device: "/dev/video99"
    framerate: 30.0
    io_method: "mmap"
    pixel_format: "mjpeg2rgb"
    av_device_format: "YUV422P"
    image_width: 640
    image_height: 480
    frame_id: "cam_test"
    camera_name: "cam_test"
EOF
sudo snap set "$SNAP_NAME" config-file=/var/snap/"$SNAP_NAME"/common/my-config/usb_cam.yaml
sleep 2
snap services "$SNAP_NAME"
echo "--- last 20 log lines (expected: exec line references my-config/usb_cam.yaml) ---"
sudo snap logs "$SNAP_NAME" -n 20 || true
sudo snap logs "$SNAP_NAME" -n 20 | grep -q "my-config/usb_cam.yaml"
echo "OK: config-file override took precedence"

echo "=== 5c. Rejecting an invalid config-file path ==="
if sudo snap set "$SNAP_NAME" config-file=/tmp/not-allowed.yaml 2>/tmp/usb-cam-configure-stderr; then
  echo "expected 'snap set config-file=/tmp/not-allowed.yaml' to fail, but it succeeded" >&2
  exit 1
fi
cat /tmp/usb-cam-configure-stderr

echo "=== 5d. Reverting to the managed default file ==="
sudo snap unset "$SNAP_NAME" config-file
sudo snap set "$SNAP_NAME" device=/dev/video99
sleep 2

echo "=== 6. Connect the camera interface (grants access to real /dev/video* nodes) ==="
echo "    Not auto-connected in strict confinement -- do this only when ready to use real hardware:"
echo "    sudo snap connect $SNAP_NAME:camera"

echo "=== 7. Point at a real camera and verify it publishes (requires explicit go-ahead + camera interface connected) ==="
echo "    sudo snap set $SNAP_NAME device=/dev/video4 namespace=/static_camera"
echo "    ros2 topic hz /static_camera/camera/image_raw"

echo "=== Smoke tests (steps 1-5) passed ==="
