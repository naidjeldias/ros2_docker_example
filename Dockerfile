FROM nvidia/cuda:11.0-base-ubuntu20.04


ARG OPENCV_VERSION=4.2.0
ARG OPENCV_CONTRIB_VERSION=4.2.0
ARG OPENCV_REPO=https://github.com/opencv/opencv.git
ARG OPENCV_CONTRIB_REPO=https://github.com/opencv/opencv_contrib.git

ENV ROS_DISTRO=foxy
ENV LANG=en_US.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ENV CATKIN_WS=/root/catkin_ws/

RUN apt update && apt install -y --no-install-recommends \
    apt-utils \
    locales \
    && rm -rf /var/lib/apt/lists/*
RUN locale-gen en_US en_US.UTF-8 && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

RUN apt update && apt install -y --no-install-recommends \
    curl \
    wget \
    gnupg2 \
    lsb-release \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

RUN apt update && apt install -y --no-install-recommends \
    ros-$ROS_DISTRO-ros-base \
    && rm -rf /var/lib/apt/lists/*

# Install build dependencies
RUN apt-get update \
    # Install build tools
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        build-essential \
        cmake \
        ninja-build \
    # Install opencv build dependencies
    && apt-get install -y --no-install-recommends \
        libeigen3-dev \
        python3-dev \
        python3-numpy \
        python3-dev \
        python3-numpy \
    && rm -rf /var/lib/apt/lists/*
    
RUN git clone $OPENCV_REPO opencv -b $OPENCV_VERSION \
    && git clone $OPENCV_CONTRIB_REPO opencv_contrib -b $OPENCV_CONTRIB_VERSION \
    && mkdir -p opencv/build \
    && cd opencv/build \
    && cmake -GNinja \
        -DCMAKE_BUILD_TYPE=RELEASE \
        -DOPENCV_ENABLE_NONFREE=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DWITH_EIGEN=ON \
        -DWITH_CUDA=ON \
        -DOPENCV_EXTRA_MODULES_PATH=../../opencv_contrib/modules \
        -DPYTHON3_EXECUTABLE=/usr/bin/python3 \
        -DPYTHON3_NUMPY_INCLUDE_DIRS=/usr/lib/python3/dist-packages/numpy/core/include/ \
        -DBUILD_EXAMPLES=OFF \
        -DINSTALL_PYTHON_EXAMPLES=OFF \
        -DINSTALL_C_EXAMPLES=OFF \
        -DBUILD_opencv_apps=OFF \
        -DBUILD_DOCS=OFF \
        -DBUILD_TESTS=OFF \
        -DBUILD_PERF_TESTS=OFF \
        .. \
    && ninja install \
    && ldconfig \
    && cd ../.. \
    && rm -rf opencv opencv_contrib

# Install ros packages dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libboost-dev \
        libboost-python-dev \
        libxss-dev \
        libxxf86vm-dev \
        libxkbfile-dev \
        libxv-dev \
        python3-colcon-common-extensions \
        python3-rosdep \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Initialize rosdep
RUN rosdep init && rosdep update

RUN echo "source /opt/ros/${ROS_DISTRO}/setup.bash" >> ~/.bashrc 

# setup entrypoint
COPY ./ros_entrypoint.sh /
RUN chmod +x /ros_entrypoint.sh
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]

ENV LIBRARY_PATH=/usr/local/cuda/lib64/stubs
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=all   