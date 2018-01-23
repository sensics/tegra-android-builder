#FROM ubuntu-14.04-openjdk-8
FROM ubuntu:16.04
MAINTAINER Ryan A. Pavlik <ryan@sensics.com>

# /bin/sh points to Dash by default, reconfigure to use bash until Android
# build becomes POSIX compliant
# from https://github.com/kylemanna/docker-aosp
RUN echo "dash dash/sh boolean false" | debconf-set-selections && \
    dpkg-reconfigure -p critical dash

# Install Essentials
RUN apt-get -q update
RUN DEBIAN_FRONTEND="noninteractive" apt-get -q upgrade -y -o Dpkg::Options::="--force-confnew" --no-install-recommends
RUN DEBIAN_FRONTEND="noninteractive" apt-get -q install -y -o Dpkg::Options::="--force-confnew" --no-install-recommends \
    wget \
    device-tree-compiler \
    rsync \
    ninja-build \
    python-networkx \
    ssh \
    bc \
    build-essential \
    bsdmainutils \
    bzip2 \
    ccache \
    coreutils \
    curl \
    gawk \
    git \
    git-gui \
    gitk \
    graphviz \
    kdiff3 \
    lib32z1-dev \
    lib32z-dev \
    lib32stdc++6 \
    libc6-dev-i386 \
    libesd0-dev \
    libgl1-mesa-dev \
    libncurses5-dev \
    libsdl1.2-dev \
    libwxgtk3.0-dev \
    libx11-dev \
    libxml2-utils \
    lzop \
    m4 \
    make \
    nano \
    openjdk-8-jdk \
    pngcrush \
    schedtool \
    software-properties-common \
    sudo \
    unzip \
    usbutils \
    x11proto-core-dev \
    xz-utils \
    zip

RUN apt-get -q autoremove
RUN apt-get -q clean -y && rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /tmp/* /var/tmp/*

ENV GOSU_VERSION=1.10
RUN dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')"; \
	wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch"; \
	wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc"; \
	\
	export GNUPGHOME="$(mktemp -d)"; \
	gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4; \
	gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu; \
	rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc; \
	\
	chmod +x /usr/local/bin/gosu; \
	gosu nobody true;

# Get latest version of "repo"
ADD https://commondatastorage.googleapis.com/git-repo-downloads/repo /usr/local/bin/
RUN chmod 755 /usr/local/bin/*

# Add oh-my-git
#ADD oh-my-git /opt/oh-my-git

# All builds will be done by user android
COPY content/gitconfig /root/.gitconfig
#COPY id_rsa /root/.ssh/id_rsa
COPY content/known_hosts /root/.ssh/known_hosts

# tnspec-workspace is for persistent NVIDIA Tegra tnspec data files
ENV TNSPEC_WORKSPACE=/opt/tnspec-workspace
VOLUME ["/tmp/ccache", "/opt/tegra-android", "/opt/tnspec-workspace"]

# Improve rebuild performance by enabling compiler cache
# from https://github.com/kylemanna/docker-aosp
ENV USE_CCACHE 1
ENV CCACHE_DIR /tmp/ccache

COPY content/docker_entrypoint.sh /root/docker_entrypoint.sh
ENTRYPOINT ["/root/docker_entrypoint.sh"]
