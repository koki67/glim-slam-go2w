FROM dustynv/ros:humble-ros-base-l4t-r35.3.1

SHELL ["/bin/bash", "-c"]

# Set the environment to non-interactive
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -q && \
    apt-get install -y apt-utils

RUN rm /etc/apt/apt.conf.d/docker-clean

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
RUN curl -s https://koide3.github.io/ppa/setup_ppa.sh | bash

RUN apt-get update && apt-get install -y \
    libiridescence-dev \
    libboost-all-dev \
    libglfw3-dev \
    libmetis-dev \
    libgtsam-dev && \
    rm -rf /var/lib/apt/lists/*

# --- gtsam_points: build from source with CUDA 11.4 ---
# Pinned to v1.0.4 (latest stable)
RUN git clone --branch v1.0.4 --depth 1 https://github.com/koide3/gtsam_points.git && \
    cd gtsam_points && mkdir build && cd build && \
    cmake .. -DBUILD_WITH_CUDA=ON -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install && ldconfig && \
    cd ../.. && rm -rf gtsam_points

# --- GLIM core library: build from source with CUDA 11.4 ---
# Pinned to v1.2.1 (latest stable)
RUN git clone --branch v1.2.1 --depth 1 https://github.com/koide3/glim.git && \
    cd glim && mkdir build && cd build && \
    cmake .. -DBUILD_WITH_CUDA=ON -DCMAKE_BUILD_TYPE=Release && \
    make -j$(nproc) && make install && ldconfig && \
    cd ../.. && rm -rf glim

# --- glim_ros2: ROS 2 node wrapper, build with colcon ---
# Pinned to v1.2.1 (latest stable); provides the glim_rosnode executable
RUN git clone --branch v1.2.1 --depth 1 https://github.com/koide3/glim_ros2.git /opt/glim_ros2_ws/src/glim_ros && \
    cd /opt/glim_ros2_ws && \
    source /opt/ros/humble/setup.bash && \
    colcon build --cmake-args -DBUILD_WITH_CUDA=ON -DCMAKE_BUILD_TYPE=Release && \
    rm -rf /opt/glim_ros2_ws/build /opt/glim_ros2_ws/log && \
    echo "source /opt/glim_ros2_ws/install/setup.bash" >> /root/.bashrc
