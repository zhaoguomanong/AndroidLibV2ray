#!/bin/bash

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
./libv2ray.sh

[[ $? != 0 ]] &&  echo "fatal error occur exit 1" && exit 1

[[ ! -f "$INSTALL_CACHE_PATH/${AAR}" ]] && { echo "fatal error aar not exist"; exit 1; }

[[ ! -f "$V2RAY_CORE_BUILD_TAG" ]] && { echo "fatal v2ray core build tag not exist"; exit 1; }

[[ -z "${WORKSPACE}" || ! -d "${WORKSPACE}" ]] \
&& echo "fatal error jenkins workspace not exits" && exit 1

cp -f "$INSTALL_CACHE_PATH/${AAR}" ${WORKSPACE}/
cp -f "$V2RAY_CORE_BUILD_TAG" ${WORKSPACE}/

exit 0