# glim-slam-go2w

GO2-W + Hesai PandarXT-16 + [GLIM](https://github.com/koide3/glim) SLAM on ROS 2 Humble, running in a Docker container on the robot-side computer (Jetson Orin NX).

This repository follows the same deployment pattern as [dlio-slam-go2w](https://github.com/koki67/dlio-slam-go2w).

## What Is Customized Here

This setup is adapted for GO2-W with Hesai PandarXT-16 LiDAR.

Main differences from a generic GLIM setup:
- **IMU source**: GO2-W does not provide usable IMU from `sportmodestate`. IMU is taken from `lowstate` and republished to `/go2/imu` by the `go2_demo` node.
- **LiDAR–IMU extrinsics**: `T_lidar_imu` in `config/config_sensors.json` is set to `[-0.171, 0.0, -0.0908, 0, 0, 0, 1]`, which is the IMU→LiDAR transform used by GLIM and derived from the Unitree mounting translation (x=0.171 m, y=0.0 m, z=0.0908 m).
- **GPU acceleration**: Configured for CUDA 11.4 on JetPack 5.1.1 (L4T R35.3.1). `gtsam_points` and GLIM are built from source inside the container using the Jetson's native CUDA toolchain.
- **L4T-based container**: Uses `dustynv/ros:humble-ros-base-l4t-r35.3.1` as the base image so that `nvcc` and CUDA headers are available at build time.

## Integration Approach

**Source build on L4T**: The Docker image is based on `dustynv/ros:humble-ros-base-l4t-r35.3.1`, which provides ROS 2 Humble and the full CUDA 11.4 development toolchain for JetPack 5.1.1. `gtsam_points` (v1.0.4) and GLIM (v1.2.1) are built from source inside the image with `BUILD_WITH_CUDA=ON`. Non-CUDA dependencies (GTSAM, iridescence, boost) are still installed from [koide3's PPA](https://koide3.github.io/ppa/).

> **Why not the PPA for GLIM?** The koide3 PPA only ships GLIM binaries for CUDA 12.2 and above. JetPack 5.1.1 provides CUDA 11.4, so a source build is required. Upgrading JetPack is not recommended as it could break Unitree's SDK and DDS stack.

## Repository Contents

This top-level repository tracks only wrapper/config files:

| Path | Description |
|------|-------------|
| `docker/Dockerfile` | L4T R35.3.1 image (Ubuntu 20.04 + CUDA 11.4) with ROS 2 Humble; GLIM built from source |
| `docker/humble.sh` | Starts the container with host network, NVIDIA runtime, and X11 |
| `config/config.json` | GLIM main config (selects GPU modules) |
| `config/config_ros.json` | Go2-W topic names, QoS, frame IDs |
| `config/config_sensors.json` | LiDAR–IMU extrinsics and IMU noise params |
| `config/config_preprocess.json` | Point cloud preprocessing (distance filters) |
| `humble_ws/src/test_catmux.yaml` | Launches IMU publisher + Hesai + GLIM |
| `humble_ws/src/record_catmux.yaml` | Same + bag recording |

Dependency source repos under `humble_ws/src/` are git submodules pointing to GO2-W forks:

| Submodule | Branch | Purpose |
|-----------|--------|---------|
| `go2w_unitree_ros2` | `imu_publisher` | IMU publisher from LowState |
| `unitree_ros2` | `master` | Unitree message definitions |
| `HesaiLidar_ROS2_techshare` | `main` | Hesai PandarXT-16 driver |

## Prerequisites

- Unitree GO2-W with Hesai PandarXT-16
- Jetson Orin NX (or equivalent ARM64 compute with CUDA)
- JetPack 5.1.1 (L4T R35.3.1) — Ubuntu 20.04 (Focal), CUDA 11.4
- Docker and NVIDIA container runtime (`nvidia-docker2`)
- Internet access for initial clone and Docker build
- Network: Hesai XT16 reachable (default: `192.168.123.20`)

## Setup

### 1. Clone with submodules

```bash
git clone --recurse-submodules https://github.com/koki67/glim-slam-go2w.git
cd glim-slam-go2w
```

If you already cloned without `--recurse-submodules`:
```bash
git submodule update --init --recursive
```

### 2. Build Docker image

```bash
cd docker
docker build -t go2-glim:latest .
cd ..
```

> **Note**: The build compiles `gtsam_points` and GLIM from source against CUDA 11.4 and takes **30–40 minutes** on the Jetson itself. Run on a host machine with fast internet for the best experience — the resulting image can then be transferred to the robot with `docker save / docker load`.

### 3. Start container

```bash
cd humble_ws
bash ../docker/humble.sh
```

`humble.sh` mounts the current directory to `/external` inside the container.

### 4. Build workspace (inside container)

```bash
cd /external
colcon build --symlink-install
```

## Run GLIM

Inside the container:

```bash
cd /external/src
catmux_create_session test_catmux.yaml
```

This starts three tmux windows:
1. **imu_publisher** — `ros2 run go2_demo imu_publisher`
2. **hesai_lidar** — `ros2 launch hesai_lidar hesai_lidar_launch.py`
3. **glim** — `ros2 run glim_ros glim_rosnode --ros-args -p config_path:=/external/config`

Use `Ctrl+B w` to switch between tmux windows.

## Topics / Interface

### Input Topics

| Topic | Type | Source | Expected Rate |
|-------|------|--------|---------------|
| `/go2/imu` | `sensor_msgs/Imu` | `go2_demo imu_publisher` | ~400 Hz |
| `/hesai/pandar` | `sensor_msgs/PointCloud2` | `hesai_lidar` | ~10 Hz |

### Output Topics

GLIM publishes odometry, path, and map outputs. Check with:

```bash
ros2 topic list | grep glim
```

### TF Frames

GLIM publishes two TF subtrees:
- `map` → `odom` → `imu_link` (odometry chain)
- `imu_link` → `hesai_lidar` (sensor extrinsic)

## Visualization

### From the robot
If visualizing locally in the container:
```bash
source /external/install/setup.bash
source /external/src/unitree_ros2/setup.sh
rviz2
```

### From an external PC
Configure CycloneDDS on the PC to use the same network interface as the robot, then:
```bash
export RMW_IMPLEMENTATION=rmw_cyclonedds_cpp
source /opt/ros/humble/setup.bash
rviz2
```

## Recording a SLAM Session

Inside the container, use the recording catmux session:

```bash
cd /external/src
catmux_create_session record_catmux.yaml
```

Bags are saved to `humble_ws/bags/` (= `/external/bags/` inside the container).

**Tip**: Use `screen -S slam` on the robot host before starting Docker, so recording survives SSH disconnections.

## Quick Checks

Inside container after startup:

```bash
source /external/install/setup.bash
source /external/src/unitree_ros2/setup.sh

# Check sensor topics
ros2 topic list | grep -E 'go2/imu|hesai'
ros2 topic hz /go2/imu          # Should be ~400 Hz
ros2 topic hz /hesai/pandar       # Should be ~10 Hz

# Check GLIM output
ros2 topic list | grep glim
```

## Configuration Tuning

### GPU vs CPU

The default `config/config.json` uses GPU modules (`config_odometry_gpu.json`, etc.). To switch to CPU-only:

```json
{
  "global": {
    "config_odometry": "config_odometry_cpu.json",
    "config_sub_mapping": "config_sub_mapping_cpu.json",
    "config_global_mapping": "config_global_mapping_cpu.json"
  }
}
```

### LiDAR–IMU Extrinsics

If your sensor mounting differs, edit `T_lidar_imu` in `config/config_sensors.json`. The transform is in TUM format `[x, y, z, qx, qy, qz, qw]` and represents the transformation from IMU frame to LiDAR frame. The default is `[-0.171, 0.0, -0.0908, 0, 0, 0, 1]`.

### IMU Noise

Tune `imu_acc_noise`, `imu_gyro_noise`, and `imu_bias_noise` in `config/config_sensors.json` based on your IMU characteristics.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `docker: Error response from daemon: unknown runtime "nvidia"` | Install `nvidia-docker2`: `sudo apt install nvidia-docker2 && sudo systemctl restart docker` |
| No sensor topics visible | Check that Hesai LiDAR is reachable: `ping 192.168.123.20`. Check `unitree_ros2/setup.sh` is sourced. |
| GLIM crashes with CUDA error | Verify JetPack CUDA version matches the GLIM package variant. Try CPU-only: rebuild with `--build-arg GLIM_PACKAGE=ros-humble-glim-ros`. |
| IMU topic missing | Ensure `go2_demo imu_publisher` is running. Check that GO2-W SDK connection is established. |
| Poor mapping quality | Verify extrinsics in `config_sensors.json`. Tune IMU noise parameters. Check that `/go2/imu` timestamps are synchronized. |
| Build fails on `colcon build` | Ensure `source /opt/ros/humble/setup.bash` was run. Try sequential build: `colcon build --executor sequential`. |
| X11 / RViz display issues | Run `xhost +local:docker` on the host before starting the container. |

## Acknowledgments

This repository builds on the work of the following projects:

- [GLIM](https://github.com/koide3/glim) — Kenji Koide (AIST). Versatile 3D LiDAR-IMU mapping framework. Licensed under MIT.
- [gtsam_points](https://github.com/koide3/gtsam_points) — Kenji Koide (AIST). GPU-accelerated scan matching factors. Licensed under MIT.
- [TechShare GO2 + XT16 integration](https://github.com/TechShare-inc/faq_go2_xt16) — TechShare Inc.
- [unitree_ros2](https://github.com/unitreerobotics/unitree_ros2) — Unitree Robotics. Licensed under BSD 3-Clause.
- [HesaiLidar_ROS2_techshare](https://github.com/TechShare-inc/HesaiLidar_ROS2_techshare) — TechShare Inc. / Hesai Technology. Licensed under Apache 2.0.

The orchestration files in this repository (Docker setup, catmux sessions, config tuning) are original work and released under the [MIT License](LICENSE).

## Notes on Version Control

- Dependency repos under `humble_ws/src/` are git submodules pinned to specific commits in koki67's forks.
- GO2-W modifications (lowstate IMU, DDS setup) are committed directly in those forks — no manual editing required after cloning.
- **GLIM is not a submodule** — it is cloned at a pinned tag and built from source inside Docker (`gtsam_points@v1.0.4`, `glim@v1.2.1`, `glim_ros2@v1.2.1`). To update, change the `--branch` tags in the Dockerfile.
- To update a submodule to its latest fork commit:
  ```bash
  cd humble_ws/src/<name> && git pull && cd ../../.. && git add humble_ws/src/<name> && git commit
  ```
