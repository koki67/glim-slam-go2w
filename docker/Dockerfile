FROM dustynv/ros:humble-ros-base-l4t-r35.3.1

SHELL ["/bin/bash", "-c"]

# Set the environment to non-interactive
ENV DEBIAN_FRONTEND=noninteractive

# Refresh ROS 2 GPG key — dustynv base may ship an expired key
RUN apt-get update -q --fix-missing || true && \
    apt-get install -y --no-install-recommends curl ca-certificates gnupg && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
    | gpg --batch --dearmor -o /usr/share/keyrings/ros-archive-keyring.gpg

RUN apt-get update -q && \
    apt-get install -y apt-utils

RUN rm -f /etc/apt/apt.conf.d/docker-clean

# --- Common tools ---
RUN apt-get update && apt-get install -y \
    net-tools \
    iputils-ping \
    git \
    tmux \
    vim \
    nano \
    wget \
    software-properties-common \
    python3-pip && \
    python3 -m pip install transforms3d websocket-client catmux distro && \
    rosdep init || true && \
    rm -rf /var/lib/apt/lists/*

# --- Additional ROS 2 packages ---
RUN apt-get update -q && \
    apt-get install -y \
    python3-argcomplete \
    python3-colcon-common-extensions \
    python3-rosdep \
    python3-vcstool \
    ros-humble-tf-transformations \
    ros-humble-rqt* \
    ros-humble-pointcloud-to-laserscan && \
    echo "source /opt/ros/humble/setup.bash" >> ~/.bashrc

# --- CycloneDDS and PCL ---
RUN apt-get update -q && \
    apt-get install -y \
    ros-humble-rosidl-generator-dds-idl \
    ros-humble-rmw-cyclonedds-cpp \
    ros-humble-pcl-conversions \
    ros-humble-pcl-ros

# --- Livox SDK2 (required by some sensor packages) ---
RUN git clone https://github.com/Livox-SDK/Livox-SDK2.git && \
    cd ./Livox-SDK2 && \
    mkdir build && \
    cd build && \
    cmake .. && make -j$(nproc) && \
    make install && \
    cd ../.. && \
    rm -rf Livox-SDK2

RUN apt-get update && apt-get install -y \
    libpcap-dev

# --- koide3 PPA for non-CUDA GLIM dependencies ---
# L4T R35.3.1 is Ubuntu 20.04 (Focal), but the PPA has no ubuntu2004 repo.
# Use ubuntu2204 packages — ARM64 ABI is compatible since we build GTSAM
# and gtsam_points from source (the PPA is only used for Iridescence/Boost).
RUN curl -s --compressed "https://koide3.github.io/ppa/ubuntu2204/KEY.gpg" \
    | gpg --batch --dearmor -o /etc/apt/trusted.gpg.d/koide3_ppa.gpg && \
    echo "deb [signed-by=/etc/apt/trusted.gpg.d/koide3_ppa.gpg] https://koide3.github.io/ppa/ubuntu2204 ./" \
    > /etc/apt/sources.list.d/koide3_ppa.list && \
    apt-get update

# Install Iridescence, Boost, and other non-CUDA deps from PPA
# Note: Do NOT install libgtsam-dev from PPA — we build GTSAM from source below
RUN apt-get update && apt-get install -y \
    libiridescence-dev \
    libboost-all-dev \
    libglfw3-dev \
    libmetis-dev \
    libfmt-dev \
    libspdlog-dev \
    libopencv-dev && \
    rm -rf /var/lib/apt/lists/*

# --- GTSAM 4.3a0: build from source ---
# PPA libgtsam-dev targets Ubuntu 22.04; building from source is safer on L4T.
# GLIM v1.2.1 requires GTSAM >= 4.2; upstream recommends 4.3a0.
RUN git clone --branch 4.3a0 --depth 1 https://github.com/borglab/gtsam.git && \
    cd gtsam && mkdir build && cd build && \
    cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DGTSAM_BUILD_EXAMPLES_ALWAYS=OFF \
    -DGTSAM_BUILD_TESTS=OFF \
    -DGTSAM_WITH_TBB=OFF \
    -DGTSAM_USE_SYSTEM_EIGEN=ON \
    -DGTSAM_USE_SYSTEM_METIS=ON \
    -DGTSAM_BUILD_WITH_MARCH_NATIVE=OFF && \
    make -j$(nproc) && make install && ldconfig && \
    cd ../.. && rm -rf gtsam

# --- gtsam_points v1.2.1: build from source with CUDA 11.4 ---
# GLIM v1.2.1 requires gtsam_points >= 1.2.0
RUN git clone --branch v1.2.1 --depth 1 https://github.com/koide3/gtsam_points.git && \
    cd gtsam_points && mkdir build && cd build && \
    cmake .. \
    -DBUILD_WITH_CUDA=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES=87 && \
    make -j$(nproc) && make install && ldconfig && \
    cd ../.. && rm -rf gtsam_points

# --- GLIM v1.2.1 core library: build from source with CUDA 11.4 ---
RUN git clone --branch v1.2.1 --depth 1 https://github.com/koide3/glim.git && \
    cd glim && mkdir build && cd build && \
    cmake .. \
    -DBUILD_WITH_CUDA=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES=87 \
    -DBUILD_WITH_MARCH_NATIVE=OFF && \
    make -j$(nproc) && make install && ldconfig && \
    cd ../.. && rm -rf glim

# --- glim_ros2 v1.2.1: ROS 2 node wrapper, build with colcon ---
# Provides the glim_rosnode executable
RUN git clone --branch v1.2.1 --depth 1 https://github.com/koide3/glim_ros2.git \
    /opt/glim_ros2_ws/src/glim_ros && \
    cd /opt/glim_ros2_ws && \
    source /opt/ros/humble/setup.bash && \
    colcon build --cmake-args \
    -DBUILD_WITH_CUDA=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CUDA_ARCHITECTURES=87 && \
    rm -rf /opt/glim_ros2_ws/build /opt/glim_ros2_ws/log && \
    echo "source /opt/glim_ros2_ws/install/setup.bash" >> /root/.bashrc
