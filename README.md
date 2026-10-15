# ros2-usb-cam-snap

Snap packaging of the upstream [`ros-drivers/usb_cam`](https://github.com/ros-drivers/usb_cam)
ROS 2 (Jazzy) node. Runs `usb_cam_node_exe` as a
systemd daemon, sharing the ROS 2 Jazzy runtime from the `ros-jazzy-ros-base`
foundational snap (see [Foundational snap](#foundational-snap) below)
instead of bundling it.

## Install

```
snap install ros2-usb-cam
snap connect ros2-usb-cam:camera
```

**If installed from the Snap Store**, the `ros-jazzy-ros-base` content
interface (see [Foundational snap](#foundational-snap)) auto-connects on its
own.

**If sideloaded with `--install --dangerous`**, snapd
does **not** auto-connect it, and the daemon will fail to start.
Connect it manually:

```
sudo snap connect ros2-usb-cam:ros-jazzy-ros-base ros-jazzy-ros-base
sudo snap restart ros2-usb-cam
```

On install, a managed default ROS params file is seeded at
`$SNAP_COMMON/config/usb_cam.yaml`, matching upstream's own
[`params_1.yaml`](https://github.com/ros-drivers/usb_cam/blob/ros2/config/params_1.yaml)
defaults, including `video_device: "/dev/video0"`. If that matches your
setup, the managed file can be used as-is; otherwise override it below.

## Configure

Camera configuration always goes through a ROS params YAML file.

### Quick path: `video-device`

For the common case of just pointing the snap at a camera, `video-device`
patches the `video_device` line of the managed default file in place. It's
named after the ROS parameter it sets (`video_device`); snap configuration
keys must be dash-separated rather than underscore-separated, hence the
dash. This is just a convenience shortcut for editing the YAML when the
only thing you want to change is the device path:

```
snap set ros2-usb-cam video-device=/dev/video4
```

### Full control: edit the managed file directly

For anything else (resolution, framerate, pixel format, brightness,
`camera_info_url`, custom V4L2 controls, ...), edit the managed file
directly and restart:

```
sudo vim /var/snap/ros2-usb-cam/common/config/usb_cam.yaml
sudo snap restart ros2-usb-cam
```

### Advanced: `config-file` (separate file or URL)

To keep configuration in a completely separate file (or fetch it from a
URL), set `config-file`. When set, it **takes precedence over the managed
default entirely** (and `video-device` is ignored):

```
# Local file: must live under $SNAP_COMMON so the strictly-confined snap
# can read it (no extra `snap connect` needed).
sudo mkdir -p /var/snap/ros2-usb-cam/common/my-config
sudo cp my_params.yaml /var/snap/ros2-usb-cam/common/my-config/usb_cam.yaml
snap set ros2-usb-cam config-file=/var/snap/ros2-usb-cam/common/my-config/usb_cam.yaml

# URL: fetched fresh on every daemon start/restart, so an update to the
# upstream file is picked up on the next launch without re-running `snap set`.
snap set ros2-usb-cam config-file=https://example.com/usb_cam.yaml
```

To go back to the managed default file:

```
snap unset ros2-usb-cam config-file
```

### Other keys

| Key | Purpose |
|---|---|
| `namespace` | ROS namespace remap (`-r __ns:=...`) |

`namespace` must follow ROS 2 naming rules (start with `/`, segments of
letters/digits/underscores, no trailing `/` unless it is exactly `/`).
The configure hook validates it and rejects invalid values with a clear
error.

### ROS environment (`ROS_DOMAIN_ID`, `RMW_IMPLEMENTATION`, ...)

ROS environment variables are set through the
[env-injector extension](https://ubuntu.com/docs/snapcraft/8/how-to/extensions/use-the-env-injector-extension/)
rather than snap-specific keys. This covers `ROS_DOMAIN_ID`, explicitly
selecting the RMW, or pointing Fast DDS at a
custom XML profile:

```
snap set ros2-usb-cam env.ros-domain-id=5
snap set ros2-usb-cam env.rmw-implementation=rmw_fastrtps_cpp
snap set ros2-usb-cam env.fastdds-default-profiles-file=/var/snap/ros2-usb-cam/common/fastdds.xml
```

## Multiple cameras on one host

Use snapd parallel installs (experimental snapd feature — enable it first):

```
sudo snap set system experimental.parallel-instances=true
snap install ros2-usb-cam_wrist
```

The instance gets its own configuration, so point each camera at its own
device and namespace, e.g.:

```
snap set ros2-usb-cam_wrist video-device=/dev/video2 namespace=/wrist
```

## Topics

Publishes the standard usb_cam topics (`image_raw`, `image_raw/compressed`,
`camera_info`), scoped by the ROS namespace (`<namespace>/image_raw`, or
just `image_raw` in the global namespace). The `camera_name` parameter is
not part of the topic path -- upstream only uses it for camera metadata
(`CameraInfo`).

## Launch mechanism

The daemon (`snap/local/usb-cam-launch.sh`) launches the node via
`ros2 run usb_cam usb_cam_node_exe`, using the `ros2` CLI provided by the
`ros-jazzy-ros-base` content snap (see below) rather than exec'ing the
built executable directly. This requires the content interface to be
connected (see [Install](#install)); the launcher checks for this and fails
with a clear, actionable message if it isn't.

## CI

`.github/workflows/snap.yaml` uses the
[`canonical/robotics-actions-workflows`](https://github.com/canonical/robotics-actions-workflows)
reusable workflow to build, test, and publish the snap to the Snap Store.
