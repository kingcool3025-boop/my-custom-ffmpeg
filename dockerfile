# 使用一个较新的Ubuntu基础镜像
FROM ubuntu:22.04

# 将Ubuntu的软件源替换为国内阿里云镜像，加速后续apt-get下载
RUN sed -i 's@//.*archive.ubuntu.com@//mirrors.aliyun.com@g' /etc/apt/sources.list
# 避免安装过程中交互式提问
ENV DEBIAN_FRONTEND=noninteractive

# 1. 安装基础编译工具和依赖库
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    wget \
    pkg-config \
    libva-dev \
    libdrm-dev \
    # 以下是为FFmpeg安装的编解码器支持
    libx264-dev libx265-dev libvpx-dev libmp3lame-dev libopus-dev libfdk-aac-dev \
    # 管理软件包和清理
    && rm -rf /var/lib/apt/lists/*

# 2. 安装Intel QSV所需的运行时驱动
# RUN apt-get update && apt-get install -y intel-media-va-driver && rm -rf /var/lib/apt/lists/*

# 3. 编译安装NDI SDK（libndi）
WORKDIR /tmp
# 从NDI官网下载SDK，你需要替换URL为最新版本
RUN wget https://downloads.ndi.tv/SDK/NDI_SDK_Linux/Install_NDI_SDK_v5_Linux.tar.gz \
    && tar -xzf Install_NDI_SDK_v5_Linux.tar.gz \
    && cd NDI_SDK_v5_Linux \
    # 【修正点】将库和头文件安装到 /usr/local 标准目录
    && cp -r lib/x86_64-linux-gnu/* /usr/local/lib/ \
    && cp -r include/* /usr/local/include/ \
    && ldconfig

# 4. 编译安装FFmpeg（启用NDI和VAAPI/QSV支持）
WORKDIR /tmp
RUN git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg-src && cd ffmpeg-src \
    && ./configure \
        --prefix=/usr/local \
        --enable-gpl \
        --enable-nonfree \
        --enable-libndi_newtek \
        --enable-libx264 \
        --enable-libx265 \
        --enable-libfdk-aac \
        --enable-libmp3lame \
        --enable-libopus \
        --enable-libvpx \
        --enable-vaapi \
        # 【修正点】让编译器在正确路径查找NDI库
        --extra-cflags="-I/usr/local/include" \
        --extra-ldflags="-L/usr/local/lib" \
    && make -j$(nproc) \
    && make install \
    # 可选：清理编译产生的巨大中间文件，减小镜像体积
    && make clean

# 设置容器启动后的默认工作目录
WORKDIR /workspace
