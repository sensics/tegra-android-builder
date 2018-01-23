#!/bin/bash
set -e

# This script designed to be used a docker ENTRYPOINT "workaround" missing docker
# feature discussed in docker/docker#7198, allow to have executable in the docker
# container manipulating files in the shared volume owned by the USER_ID:GROUP_ID.
#
# It creates a user named `aosp` with selected USER_ID and GROUP_ID (or
# 1000 if not specified).

# Example:
#
#  docker run -ti -e USER_ID=$(id -u) -e GROUP_ID=$(id -g) imagename bash
#

# Reasonable defaults if no USER_ID/GROUP_ID environment variables are set.
if [ -z ${USER_ID+x} ]; then USER_ID=1000; fi
if [ -z ${GROUP_ID+x} ]; then GROUP_ID=1000; fi

msg="docker_entrypoint: Creating user UID/GID [$USER_ID/$GROUP_ID]" && echo $msg
groupadd -g $GROUP_ID -r android && \
useradd -u $USER_ID --create-home -r -g android android
echo "$msg - done"

if [ "x${AOSP_GIT_USER_NAME}" != "x" ]; then
    msg="docker_entrypoint: Setting Git user.name to ${AOSP_GIT_USER_NAME}" && echo $msg
    git config --global user.name "${AOSP_GIT_USER_NAME}" && \
    echo "$msg - done"
fi

if [ "x${AOSP_GIT_USER_EMAIL}" != "x" ]; then
    msg="docker_entrypoint: Setting Git user.email to ${AOSP_GIT_USER_EMAIL}" && echo $msg
    git config --global user.email "${AOSP_GIT_USER_EMAIL}" && \
    echo "$msg - done"
fi

msg="docker_entrypoint: Copying .gitconfig and .ssh/ files to new user home" && echo $msg
cp /root/.gitconfig /home/android/.gitconfig && \
chown android:android /home/android/.gitconfig && \
mkdir -p /home/android/.ssh && \
cp /root/.ssh/* /home/android/.ssh/ && \
chown android:android -R /home/android/.ssh &&
echo "$msg - done"

msg="docker_entrypoint: Creating /tmp/ccache, /opt/tegra-android, and /opt/tnspec-workspace directories" && echo $msg
mkdir -p /tmp/ccache /opt/tegra-android /opt/tnspec-workspace
chown android:android /tmp/ccache /opt/tegra-android /opt/tnspec-workspace
echo "$msg - done"

msg="docker_entrypoint: Adding user to sudoers sans password" && echo msg
echo "android ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/android
chmod 0440 /etc/sudoers.d/android
echo "$msg - done"

echo ""

# Default to 'bash' if no arguments are provided
args="$@"
if [ -z "$args" ]; then
  echo "source /opt/oh-my-git/prompt.sh" >> /home/android/.bashrc
  args="bash"
fi

# Execute command as `aosp` user
export HOME=/home/android
export USER=android
# Files should be group-manageable
umask 002
#exec sudo -E -u android $args
exec gosu android $args
