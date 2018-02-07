#!/bin/bash -e
BASE_ANDROID_DIR=/opt/android
SRC_SUBDIR=tegra-android
CCACHE_SUBDIR=ccache
TNSPEC_SUBDIR=tnspec-workspace
DOCKER_EXTRA_ARGS=

LINK_DIR=$(cd $(dirname $0) && pwd)
SCRIPT_DIR=$(cd $(dirname $(readlink -e $0)) && pwd)
# Figure out the default image name
DEFAULT_IMAGE_NAME=$(basename ${SCRIPT_DIR})

# Override from environment
AOSP_IMAGE=${AOSP_IMAGE:-${DEFAULT_IMAGE_NAME}}
AOSP_ARGS=${AOSP_ARGS:---rm -it}

if [ "$USBACCESS" ]; then
    echo "USBACCESS was non-empty: launching container as privileged and with /dev/bus/usb access"
    AOSP_ARGS="${AOSP_ARGS} --privileged -v /dev/bus/usb:/dev/bus/usb"
fi

AOSP_VOL_AOSP=${AOSP_VOL_AOSP:-$BASE_ANDROID_DIR/$SRC_SUBDIR}
AOSP_VOL_AOSP=${AOSP_VOL_AOSP%/} # Trim trailing slash if needed
AOSP_VOL_CCACHE=${AOSP_VOL_CCACHE:-$BASE_ANDROID_DIR/$CCACHE_SUBDIR}
AOSP_VOL_CCACHE=${AOSP_VOL_CCACHE%/} # Trim trailing slash if needed
TNSPEC_VOL=${TNSPEC_VOL:-$BASE_ANDROID_DIR/$TNSPEC_SUBDIR}
TNSPEC_VOL=${TNSPEC_VOL%/} # Trim trailing slash if needed

GROUP_FN=gid

# Extract from something like this: VOLUME ["/tmp/ccache", "/opt/android", "/opt/tnspec-workspace"]
VOLUMES=$(grep "^VOLUME" ${SCRIPT_DIR}/Dockerfile | sed -e 's/VOLUME [^"]*//' -e 's/]//' -e 's/",//g' -e 's/"//g')
CCACHE_MOUNT_POINT=$(echo $VOLUMES | cut -d " " -f 1)
AOSP_MOUNT_POINT=$(echo $VOLUMES | cut -d " " -f 2)
TNSPEC_MOUNT_POINT=$(echo $VOLUMES | cut -d " " -f 3)

find_config_file() {
	for candidate in "${LINK_DIR}/${1}" "${SCRIPT_DIR}/${1}"; do
        if [ -f "${candidate}" ]; then
            echo "${candidate}"
            return 0
        fi
    done
}

mkdir -p ${AOSP_VOL_AOSP}
mkdir -p ${AOSP_VOL_CCACHE}
mkdir -p ${TNSPEC_VOL}
echo ""
echo "Launching docker image ${AOSP_IMAGE} with mounts: "
echo -e "[Source Root]  ${AOSP_MOUNT_POINT}:\t${AOSP_VOL_AOSP}"
echo -e "[ccache]       ${CCACHE_MOUNT_POINT}:\t${AOSP_VOL_CCACHE}"
echo -e "[tnspec data]  ${TNSPEC_MOUNT_POINT}:\t${TNSPEC_VOL}"

CONFFILE=$(find_config_file buildconf)
if [ "${CONFFILE}" ]; then
    source "${CONFFILE}"
fi

# Set uid and gid to match host current user (and optional custom group)
# as long as NOT root
uid=$(id -u)

if [ $uid -ne "0" ]; then
    # Look for group ID file
    GROUPFILE=$(find_config_file ${GROUP_FN})

    if [ "${GROUPFILE}" ]; then
        # OK, we found a group. Remove all whitespace.
        GROUP=$(cat "${GROUPFILE}" | sed 's/\s//')
        # if the group is in the list of group numbers...
        if id -G | egrep -q "\b${GROUP}\b"; then
            echo "Using group ID ${GROUP} as loaded from ${GROUPFILE}"
            gid=${GROUP}
        else
            echo "The contents of ${GROUPFILE} ('${GROUP}') did not match any groups you are a member of!"
            exit 1
        fi
    else
        gid=$(id -g) # User's "main" group.
        echo "Using group ID ${gid} - the current user's 'main' group."
    fi

    AOSP_HOST_ID_ARGS="-e USER_ID=$uid -e GROUP_ID=$gid"
fi

config_fail=""
if git config user.name > /dev/null; then
    AOSP_GIT_USER_NAME_ARG="-e AOSP_GIT_USER_NAME"
    export AOSP_GIT_USER_NAME=$(git config user.name)
else
    echo "Error: you haven't set git config --global user.name"1>&2
    config_fail="true"
fi

if git config user.email > /dev/null; then
    AOSP_GIT_USER_EMAIL_ARG="-e AOSP_GIT_USER_EMAIL"
    export AOSP_GIT_USER_EMAIL="$(git config user.email)"
else
    echo "Error: you haven't set git config --global user.email"1>&2
    config_fail="true"
fi

if [ "${config_fail}" ]; then
    echo "Please fix your git config and run again!" 1>&2
    exit 1
fi

# Think this is for forwarding ssh agent
# from https://github.com/kylemanna/docker-aosp/blob/master/utils/aosp
if [ -S "$SSH_AUTH_SOCK" ]; then
    SSH_AUTH_ARGS="-v $SSH_AUTH_SOCK:/tmp/ssh_auth -e SSH_AUTH_SOCK=/tmp/ssh_auth"
fi

docker run \
    $AOSP_ARGS \
    $AOSP_HOST_ID_ARGS \
    $SSH_AUTH_ARGS \
    $AOSP_EXTRA_ARGS \
    $DOCKER_EXTRA_ARGS \
    $AOSP_GIT_USER_NAME_ARG \
    $AOSP_GIT_USER_EMAIL_ARG \
    -v "$AOSP_VOL_AOSP:$AOSP_MOUNT_POINT" \
    -v "$AOSP_VOL_CCACHE:$CCACHE_MOUNT_POINT" \
    -v "$TNSPEC_VOL:$TNSPEC_MOUNT_POINT" \
    -w $AOSP_MOUNT_POINT \
    --init \
    $AOSP_IMAGE \
    $@
