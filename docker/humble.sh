#!/bin/bash

# Allow local X11 connections for GUI (RViz etc.)
xhost +local:docker

# Generate XAUTH file for X11 forwarding
XAUTH=/tmp/.docker.xauth
if [ ! -f $XAUTH ]; then
    touch $XAUTH
    xauth_list=$(xauth nlist :0 | sed -e 's/^..../ffff/')
    if [ ! -z "$xauth_list" ]; then
        echo $xauth_list | xauth -f $XAUTH nmerge -
    fi
    chmod a+r $XAUTH
fi

# Run the Docker container
docker run -it --rm \
  --privileged \
  --runtime=nvidia \
  --net=host \
  --env="DISPLAY=$DISPLAY" \
  --env="QT_X11_NO_MITSHM=1" \
  --env="XAUTHORITY=$XAUTH" \
  --env="RMW_IMPLEMENTATION=rmw_cyclonedds_cpp" \
  --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
  --volume="$XAUTH:$XAUTH" \
  --volume="${PWD}:/external:rw" \
  go2-glim:latest bash
