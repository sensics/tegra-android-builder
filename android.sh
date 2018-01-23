#!/bin/bash
BASE_ANDROID_DIR=/opt/android
SRC_SUBDIR=tegra-android
CCACHE_SUBDIR=ccache
TNSPEC_SUBDIR=tnspec-workspace
LINK_DIR=$(cd $(dirname $0) && pwd)
SCRIPT_DIR=$(cd $(dirname $(readlink -e $0)) && pwd)
GROUP_FN=gid
# Figure out the default image name
DEFAULT_IMAGE_NAME=$(basename ${SCRIPT_DIR})

# Extract from something like this: VOLUME ["/tmp/ccache", "/opt/android", "/opt/tnspec-workspace"]
VOLUMES=$(grep VOLUME ${SCRIPT_DIR}/Dockerfile | sed -e 's/VOLUME [^"]*//' -e 's/]//' -e 's/",//g' -e 's/"//g')
CCACHE_MOUNT_POINT=$(echo $VOLUMES | cut -d " " -f 1)
AOSP_MOUNT_POINT=$(echo $VOLUMES | cut -d " " -f 2)
TNSPEC_MOUNT_POINT=$(echo $VOLUMES | cut -d " " -f 3)

# First look for group ID file
GROUPFILE=""
if [ -f "${LINK_DIR}/${GROUP_FN}" ]; then
    GROUPFILE="${LINK_DIR}/${GROUP_FN}"
elif [ -f "${SCRIPT_DIR}/${GROUP_FN}" ]; then
    GROUPFILE="${SCRIPT_DIR}/${GROUP_FN}"
fi

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


# Override from environment
AOSP_IMAGE=${AOSP_IMAGE:-${DEFAULT_IMAGE_NAME}}
AOSP_ARGS=${AOSP_ARGS:---rm -it}

AOSP_VOL_AOSP=${AOSP_VOL_AOSP:-$BASE_ANDROID_DIR/$SRC_SUBDIR}
AOSP_VOL_AOSP=${AOSP_VOL_AOSP%/} # Trim trailing slash if needed
AOSP_VOL_CCACHE=${AOSP_VOL_CCACHE:-$BASE_ANDROID_DIR/$CCACHE_SUBDIR}
AOSP_VOL_CCACHE=${AOSP_VOL_CCACHE%/} # Trim trailing slash if needed
TNSPEC_VOL=${TNSPEC_VOL:-$BASE_ANDROID_DIR/$TNSPEC_SUBDIR}
TNSPEC_VOL=${TNSPEC_VOL%/} # Trim trailing slash if needed

echo ""
echo "Launching docker image ${AOSP_IMAGE} with mounts: "
echo -e "[Source Root]  ${AOSP_MOUNT_POINT}:\t${AOSP_VOL_AOSP}"
echo -e "[ccache]       ${CCACHE_MOUNT_POINT}:\t${AOSP_VOL_CCACHE}"
echo -e "[tnspec data]  ${TNSPEC_MOUNT_POINT}:\t${TNSPEC_VOL}"

mkdir -p ${AOSP_VOL_AOSP}
mkdir -p ${AOSP_VOL_CCACHE}
mkdir -p ${TNSPEC_VOL}

uid=$(id -u)

# Set uid and gid to match host current user as long as NOT root
if [ $uid -ne "0" ]; then
    AOSP_HOST_ID_ARGS="-e USER_ID=$uid -e GROUP_ID=$gid"
fi

if git config user.name > /dev/null; then
    AOSP_GIT_USER_NAME_ARG="-e AOSP_GIT_USER_NAME"
    export AOSP_GIT_USER_NAME=$(git config user.name)
else
    echo "Warning: you haven't set git config --global user.name - so a (perhaps ill-fitting) default will be used!"
fi

if git config user.email > /dev/null; then
    AOSP_GIT_USER_EMAIL_ARG="-e AOSP_GIT_USER_EMAIL"
    export AOSP_GIT_USER_EMAIL="$(git config user.email)"
else
    echo "Warning: you haven't set git config --global user.email - so a (perhaps ill-fitting) default will be used!"
fi

# Think this is for forwarding ssh agent
# from https://github.com/kylemanna/docker-aosp/blob/master/utils/aosp
if [ -S "$SSH_AUTH_SOCK" ]; then
    SSH_AUTH_ARGS="-v $SSH_AUTH_SOCK:/tmp/ssh_auth -e SSH_AUTH_SOCK=/tmp/ssh_auth"
fi

docker run $AOSP_ARGS $AOSP_HOST_ID_ARGS $SSH_AUTH_ARGS $AOSP_EXTRA_ARGS \
    $AOSP_GIT_USER_NAME_ARG $AOSP_GIT_USER_EMAIL_ARG \
    -v "$AOSP_VOL_AOSP:$AOSP_MOUNT_POINT" \
    -v "$AOSP_VOL_CCACHE:$CCACHE_MOUNT_POINT" \
    -v "$TNSPEC_VOL:$TNSPEC_MOUNT_POINT" \
    -w $AOSP_MOUNT_POINT \
    --init \
    $AOSP_IMAGE \
    $@
