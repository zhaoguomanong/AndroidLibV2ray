#!/bin/bash

#for small disk size vps using
#using sshfs to mount folder for saving android sdk etc.
umountDisk() {
    [[ -z "$umountDiskCmd" || -z "$mountDiskCmd" || -z "$mountPoint" ]] \
    && echo "no need using extra disk" && return 0

    df | grep "$mountPoint" > /dev/null 2>&1 \
    || { echo "$mountPoint not mounted, return now"; return 0; }

    ${umountDiskCmd}

    df | grep "$mountPoint" > /dev/null 2>&1 \
    && echo "Fatal error: umount $mountPoint failed" \
    || { echo "umount $mountPoint success, disk info:"; df -h; }

    return 0
}

#for small disk size vps using
#using sshfs to mount folder for saving android sdk etc.
mountDisk() {
    [[ -z "$umountDiskCmd" || -z "$mountDiskCmd" || -z "$mountPoint" ]] \
    && echo "no need using extra disk" && return 0

    df | grep "$mountPoint" > /dev/null 2>&1 \
    && echo "$mountPoint already been mounted, try umount it first" \
    && umountDisk

    ${mountDiskCmd}

    df | grep "$mountPoint" > /dev/null 2>&1 \
    || { echo "Fatal error: mount $mountPoint failed, exit now"; exit 1; }

    echo "mount $mountPoint success, disk info:"
    df -h

    return 0
}

cd `dirname $0`
SCRIPT_PATH=`pwd`
find . -name "*.sh" | xargs chmod a+x
source ./CommonUtils.sh
source ./constants.sh
cd "$SCRIPT_PATH" && findUnderUserHome && cd "$SCRIPT_PATH"

export cleanGoCache="true"
INSTALL_CACHE_PATH="$under_home/$CACHE_FOLDER"
AAR="$libv2ray_aar"

#for cache build tag
V2RAY_CORE_BUILD_TAG="$INSTALL_CACHE_PATH/$v2ray_core_tag_file"

if [[ "$cleanGoCache" = "true" ]];then
    homeCache="/root/.cache"
    [[ -d "$homeCache" ]] && { echo "clean .cache now"; rm -rf "$homeCache"; }
else
    echo "no need clean gradle cache"
fi

export HOME=/root
mountDisk
./libv2ray.sh

[[ $? != 0 ]] \
&&  echo "fatal error occur exit 1" \
&& { umountDisk; exit 1; }

[[ ! -f "$INSTALL_CACHE_PATH/${AAR}" ]] \
&& echo "fatal error aar not exist" \
&& { umountDisk; exit 1; }

[[ ! -f "$V2RAY_CORE_BUILD_TAG" ]] \
&& echo "fatal v2ray core build tag not exist" \
&& { umountDisk; exit 1; }

[[ -z "${WORKSPACE}" || ! -d "${WORKSPACE}" ]] \
&& echo "fatal error jenkins workspace not exits" \
&& { umountDisk; exit 1; }

cp -f "$INSTALL_CACHE_PATH/${AAR}" ${WORKSPACE}/
cp -f "$V2RAY_CORE_BUILD_TAG" ${WORKSPACE}/

umountDisk
exit 0
