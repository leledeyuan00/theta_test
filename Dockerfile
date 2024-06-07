FROM osrf/ros:foxy-desktop

RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null && \
    rm /etc/apt/sources.list.d/ros2-snapshots.list

ENV DEBIAN_FRONTEND noninteractive
# install dependencies via apt
ENV DEBCONF_NOWARNINGS yes

RUN set -x && \
  apt-get update -y -qq && \
  apt-get upgrade -y -qq --no-install-recommends && \
  : "basic dependencies" && \
  apt-get install -y -qq \
    build-essential \
    pkg-config \
    cmake \
    git \
    wget \
    curl \
    tar \
    unzip \
    libboost-all-dev && \
  : "gstreamer dependencies" && \
  apt-get install -y -qq \
    libgstreamer1.0-0 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-tools \
    gstreamer1.0-x \
    gstreamer1.0-alsa \
    gstreamer1.0-gl \
    gstreamer1.0-gtk3 \
    gstreamer1.0-qt5 \
    gstreamer1.0-pulseaudio \
    libgstreamer-plugins-base1.0-dev && \
  : "libuvc dependencies" && \
  apt-get install -y -qq \
    libusb-1.0-0-dev && \
  : "remove cache" && \
  apt-get autoremove -y -qq && \
  rm -rf /var/lib/apt/lists/*

ARG NUM_THREADS=1

RUN set -x && \
  apt-get update -y -qq && \
  : "install ROS packages" && \
  apt-get install -y -qq \
    ros-${ROS_DISTRO}-image-transport \
    ros-${ROS_DISTRO}-cv-bridge && \
  : "remove cache" && \
  apt-get autoremove -y -qq && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN git clone https://github.com/ricohapi/libuvc-theta.git && \
  cd libuvc-theta && \
  mkdir build && \
  cd build && \
  cmake -DCMAKE_BUILD_TYPE=Release .. && \
  make && \
  make install && \
  ldconfig && \
  cd ../.. && \
  rm -rf libuvc-theta

RUN set -x && \
  apt-get update -y -qq && \
  : "ci dependencies" && \
  apt-get install -y -qq \
    ccache \
    clang-format && \
  apt-get autoremove -y -qq && \
  rm -rf /var/lib/apt/lists/*

# Install cuda
RUN set -x && \
  apt-get update -y -qq && \
  apt-get install -y -qq \
    nvidia-cuda* && \
  apt-get autoremove -y -qq && \
  rm -rf /var/lib/apt/lists/*

RUN set -x && \
  apt-get update -y -qq && \
  : "dev dependencies" && \
  apt-get install -y -qq \
    rsync &&\
  apt-get autoremove -y -qq && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /ros2_ws
COPY . /ros2_ws/src/theta_driver

RUN set -x && \
  : "build ROS packages" && \
  bash -c "source /opt/ros/${ROS_DISTRO}/setup.bash; \
  colcon build --parallel-workers ${NUM_THREADS}"

# Build the gst plugin
WORKDIR /ros2_ws/src/theta_driver/3rd/
RUN set -x && \
  cd ./gst-plugins-bad && \
  git checkout 1.14.5 && \
  cp /usr/include/cuda.h ./sys/nvenc && \
  cp ../Video_Codec_SDK_11.0.10/Interface/nvEncodeAPI.h ./sys/nvenc && \
  cp ../Video_Codec_SDK_11.0.10/Interface/cuviddec.h ./sys/nvdec && \
  cp ../Video_Codec_SDK_11.0.10/Interface/nvcuvid.h ./sys/nvdec && \
  cp ../Video_Codec_SDK_11.0.10/Lib/linux/stubs/x86_64/* /usr/lib/x86_64-linux-gnu/ && \
  NVENCODE_CFLAGS="-I/ros2_ws/src/theta_driver/3rd/gst-plugins-bad/sys/nvenc" ./autogen.sh --with-cuda-prefix="/usr/lib/cuda" --disable-gtk-doc && \
  cd ./sys/nvenc && \
  make && \
  cp .libs/libgstnvenc.so /usr/lib/x86_64-linux-gnu/gstreamer-1.0/ && \
  cd ../nvdec && \
  make && \
  cp .libs/libgstnvdec.so /usr/lib/x86_64-linux-gnu/gstreamer-1.0/




RUN set -x && \
  sh -c "echo 'source /opt/ros/${ROS_DISTRO}/setup.bash \
  \nsource /ros2_ws/install/setup.bash \
  \nexport FASTRTPS_DEFAULT_PROFILES_FILE=/ros2_ws/src/theta_driver/ROS2_config.xml \
  \nexport ROS_DOMAIN_ID=12' >> ~/.bashrc"
  
CMD ["bash"]
