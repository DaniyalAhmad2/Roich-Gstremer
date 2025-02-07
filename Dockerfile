# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Disable interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies needed to build OpenCV with GStreamer support and for Python
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    pkg-config \
    libgtk-3-dev \
    libavcodec-dev \
    libavformat-dev \
    libswscale-dev \
    libv4l-dev \
    libxvidcore-dev \
    libx264-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    gfortran \
    openexr \
    libatlas-base-dev \
    python3-dev \
    python3-pip \
    python3-numpy \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    gstreamer1.0-tools \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gphoto2 \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN pip3 install --upgrade pip

# ---------------------------
# Build OpenCV from source with GStreamer support
# ---------------------------
WORKDIR /opt

# Clone the OpenCV and OpenCV Contrib repositories (using shallow clones for speed)
RUN git clone --depth 1 https://github.com/opencv/opencv.git && \
    git clone --depth 1 https://github.com/opencv/opencv_contrib.git

WORKDIR /opt/opencv/build

# Configure CMake:
#  - Build in RELEASE mode
#  - Install to /usr/local
#  - Generate pkg-config files
#  - Include opencv_contrib modules
#  - Disable examples
#  - Enable GStreamer support
#  - Use the system Python3 executable
RUN cmake -D CMAKE_BUILD_TYPE=RELEASE \
          -D CMAKE_INSTALL_PREFIX=/usr/local \
          -D OPENCV_GENERATE_PKGCONFIG=ON \
          -D OPENCV_EXTRA_MODULES_PATH=/opt/opencv_contrib/modules \
          -D BUILD_EXAMPLES=OFF \
          -D WITH_GSTREAMER=ON \
          -D PYTHON3_EXECUTABLE=$(which python3) \
          ..

# Build and install OpenCV using all available cores
RUN make -j$(nproc) && \
    make install && \
    ldconfig

# ---------------------------
# Python Dependencies for Ultralytics
# ---------------------------

# Install a pinned version of NumPy (ensuring compatibility with the custom-built OpenCV)
RUN pip3 install numpy==1.23.5

# Install ultralytics WITHOUT its bundled dependencies to avoid overwriting custom OpenCV and NumPy.
RUN pip3 install ultralytics --no-deps

# Now install the remaining required dependencies as specified in ultralytics' pyproject.toml.
# Note: We intentionally skip opencv-python and numpy.
RUN pip3 install \
    "matplotlib>=3.3.0" \
    "pillow>=7.1.2" \
    "PyYAML>=5.3.1" \
    "requests>=2.23.0" \
    "scipy>=1.4.1" \
    "torch>=1.8.0" \
    "torchvision>=0.9.0" \
    "tqdm>=4.64.0" \
    psutil \
    py-cpuinfo \
    "pandas>=1.1.4" \
    "seaborn>=0.11.0" \
    "ultralytics-thop>=2.0.0"

# ---------------------------
# Final container configuration
# ---------------------------

# Set the working directory to /code (this folder can be mounted from your host)
WORKDIR /code

# Default command to open an interactive shell
CMD ["/bin/bash"]
