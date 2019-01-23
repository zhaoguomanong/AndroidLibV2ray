#!/bin/bash

V2RAY_CORE_URL="v2ray.com/core"
V2RAY_EXT_URL="v2ray.com/ext"
LIBV2RAY_GIT_URL="github.com/zhaoguomanong/AndroidLibV2ray"
CMD_UPDATE="apt-get -y update"
CMD_INSTALL="apt-get -y install"
CMD_DIST_UPGRADE="apt-get -y dist-upgrade"

clearPb() {
    if [ -d ~/pbinst ];then
        rm -rf ~/pbinst
    fi
    if [ -d /root/pbinst ];then
        rm -rf /root/pbinst
    fi
    return 0
}

clearFiles() {
    cd ${INSTALL_CACHE_PATH}
    if [ -f "$LIB_AAR_FILE" ];then
        rm "$LIB_AAR_FILE"
    fi
    #must delete pbinst before compile
    clearPb
    [[ -f "$V2RAY_CORE_BUILD_TAG" ]] && rm -f "$V2RAY_CORE_BUILD_TAG"
}

installBasicDep() {
    which git > /dev/null 2>&1 || ${CMD_INSTALL} git
    which java > /dev/null 2>&1 || ${CMD_INSTALL} openjdk-8-jdk
    export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
    export PATH=${JAVA_HOME}/bin:$PATH
    if [ -d ${ANDROID_HOME} ] \
    && [ -d ${ANDROID_NDK_HOME} ];then
        #already install android sdk and ndk,
        # so basic deps must already be installed return now
        return
    fi
    dpkg --add-architecture i386
    ${CMD_UPDATE}
    ${CMD_DIST_UPGRADE}
    ${CMD_INSTALL} software-properties-common
    ${CMD_INSTALL} libc6:i386 libstdc++6:i386 zlib1g:i386 lib32z1 expect
    ${CMD_INSTALL} zip unzip make expect # NDK stuff
    ${CMD_INSTALL} build-essential wget
    ${CMD_INSTALL} gawk
    return 0
}

installGoEnv() {
    cd ${INSTALL_CACHE_PATH}
    export GOROOT=/usr/local/go
    export GOPATH="$under_home/gopath"
    echo "GOPATH=$GOPATH"
    export PATH=${GOPATH}/bin:${GOROOT}/bin:$PATH
    if [ -d ${GOROOT} ];then
        return
    fi
    go_Version="go1.11.linux-amd64.tar.gz"
    wget -O ${go_Version} https://dl.google.com/go/${go_Version}
    tar -C /usr/local -zxvf ${go_Version}
    rm ${go_Version}
    return 0
}

installAndroidSDKNDK() {
    cd ${INSTALL_CACHE_PATH}
    export ANDROID_HOME=${INSTALL_CACHE_PATH}/android-sdk-linux
    export PATH=${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools:$PATH
    export NDK_HOME=${INSTALL_CACHE_PATH}/android-ndk-r15c
    export ANDROID_NDK_HOME=${NDK_HOME}
    if [ -d ${ANDROID_HOME} ] \
    && [ -d ${ANDROID_NDK_HOME} ];then
        #already install android sdk and ndk return now
        return
    fi

    # Get SDK tools (link from https://developer.android.com/studio/index.html#downloads)
    sdk_version="sdk-tools-linux-3859397.zip"
    wget -O ${sdk_version} https://dl.google.com/android/repository/${sdk_version}
    mkdir -p ${ANDROID_HOME}
    unzip -o ${sdk_version} -d ${ANDROID_HOME}
    rm ${sdk_version}

    # Get NDK (https://developer.android.com/ndk/downloads/index.html)
    ndk_version="android-ndk-r15c-linux-x86_64.zip"
    wget -O ${ndk_version} https://dl.google.com/android/repository/${ndk_version}
    unzip -o ${ndk_version}
    rm ${ndk_version}

    ACCEPT_LICENSES_ITEM="android-sdk-license-bcbbd656|intel-android-sysimage-license-1ea702d1|android-sdk-license-2742d1c5"

    cp -f ${SCRIPT_PATH}/accept-licenses ${ANDROID_HOME}/tools/
    cd ${ANDROID_HOME}/tools
    chmod +x accept-licenses
    ./accept-licenses "./android update sdk --use-sdk-wrapper --all --no-ui" ${ACCEPT_LICENSES_ITEM}  >/dev/null

    cd ${INSTALL_CACHE_PATH}

    platform_tools_version="platform-tools_r28.0.1-linux.zip"
    wget -O ${platform_tools_version} https://dl.google.com/android/repository/${platform_tools_version}
    unzip -o ${platform_tools_version} -d ${ANDROID_HOME}
    rm ${platform_tools_version}

    cd ${ANDROID_HOME}/tools/bin
    cp -f ${SCRIPT_PATH}/reduce.awk ./
    yes | ./sdkmanager --verbose "platform-tools" "platforms;android-28" | awk -f reduce.awk
    return 0
}

initGoMobileNDK() {
    cd ${INSTALL_CACHE_PATH}
    GOMOBILE_NDK_PATH="${GOPATH}/pkg/gomobile/ndk-toolchains"
    if [ -d ${GOMOBILE_NDK_PATH} ];then
        #already init NDK return now
        return 0
    fi
    gomobile init -ndk ${ANDROID_NDK_HOME}
    return 0
}

getGeoDat() {
    local GEOIP_DEFAULT_TAG="20181213.1"
    local GEO_SITE_DEFAULT_TAG="20181213.2"
    local geoIpTag=""
    local geoSiteTag=""
    local geo_cache_timestamp="0"
    local ONE_DAY=86400

    if [ ! -d ${GEO_DAT_CACHE_PATH} ];then
        mkdir -p ${GEO_DAT_CACHE_PATH}
    fi

    cd ${GOPATH}/src/${LIBV2RAY_GIT_URL}
    if [ -d assets ];then
        rm -rf assets
    fi
    mkdir assets
    cd assets

    if [ -f "$GEO_DAT_TIMESTAMP" ];then
        readFile "$GEO_DAT_TIMESTAMP" geo_cache_timestamp
    fi
    if [ -z "$geo_cache_timestamp" ];then
        geo_cache_timestamp="0"
    fi

    nowTime=$(date +%s)
    ((cacheTime=$nowTime-$geo_cache_timestamp))
    local formatCacheTime=$(displaySeconds ${cacheTime})

    if [ ${cacheTime} -gt ${ONE_DAY} ] \
    || [ ! -f ${GEO_DAT_CACHE_PATH}/geoip.dat ] \
    || [ ! -f ${GEO_DAT_CACHE_PATH}/geosite.dat ];then
        echo "getGeoDat: geo tags cache need update > one day, cacheTime = $formatCacheTime"
        echo "getGeoDat: get geo tags from github release api"
        geoIpTag=$(curl --silent "https://api.github.com/repos/v2ray/geoip/releases/latest" \
        | grep '"tag_name":' \
        | sed -E 's/.*"([^"]+)".*/\1/')
        geoSiteTag=$(curl --silent "https://api.github.com/repos/v2ray/domain-list-community/releases/latest" \
        | grep '"tag_name":' \
        | sed -E 's/.*"([^"]+)".*/\1/')

        if [ -z "$geoIpTag" ] \
        || [ -z "$geoSiteTag" ];then
            echo "getGeoDat: github release api op failed, abuse reject, please check! too fast???"
            echo "getGeoDat: use default tag for temp"
            geoIpTag=${GEOIP_DEFAULT_TAG}
            geoSiteTag=${GEO_SITE_DEFAULT_TAG}
        fi

        local GEOIP_RELEASE="https://github.com/v2ray/geoip/releases/download/${geoIpTag}/geoip.dat"
        local GEOSITE_RELEASE="https://github.com/v2ray/domain-list-community/releases/download/${geoSiteTag}/dlc.dat"
        echo "getGeoDat: geoip.dat   ---> $GEOIP_RELEASE"
        echo "getGeoDat: geosite.dat ---> $GEOSITE_RELEASE"
        curl -L -o geoip.dat ${GEOIP_RELEASE}
        curl -L -o geosite.dat ${GEOSITE_RELEASE}
        #backup cache
        cp -f geoip.dat ${GEO_DAT_CACHE_PATH}/
        cp -f geosite.dat ${GEO_DAT_CACHE_PATH}/
        writeFile "$GEO_DAT_TIMESTAMP" "$nowTime"
    else
        echo "getGeoDat: geo dat from local cache, cacheTime = $formatCacheTime"
        cp -f ${GEO_DAT_CACHE_PATH}/geoip.dat geoip.dat
        cp -f ${GEO_DAT_CACHE_PATH}/geosite.dat geosite.dat
    fi
}

processSpecialVersions() {
    #some old v2ray-core compile dependency
    local core_TAG_V_3_10="v3.10"
    local core_TAG_V_3_17="v3.17"
    local core_TAG_V_4_1="v4.1"
    local current_timestamp="$1"
    local isEmpty=""

    #fix bug for empty vendor websocket & socks (v3.28,v3.29 etc.) start
    if [ -d ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/websocket ] \
    && [ -d ${GOPATH}/src/github.com/gorilla/websocket/ ];then
        isEmpty=""
        isEmpty=$(ls ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/websocket)
        if [ -z "$isEmpty" ];then
            cp -rf ${GOPATH}/src/github.com/gorilla/websocket/* \
            ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/websocket/
        fi
    fi

    if [ -d ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/h12.me/socks ] \
    && [ -d ${GOPATH}/src/${LIBV2RAY_GIT_URL}/vendor/github.com/h12w/socks/ ];then
        isEmpty=""
        isEmpty=$(ls ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/h12.me/socks)
        if [ -z "$isEmpty" ];then
            cp -rf ${GOPATH}/src/${LIBV2RAY_GIT_URL}/vendor/github.com/h12w/socks/* \
            ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/h12.me/socks/
        fi
    fi
    #fix bug for empty vendor websocket & socks (v3.28,v3.29 etc.) end

    cd ${GOPATH}/src/${V2RAY_CORE_URL}
    local v3_10=$(git log -1 --format=%ct "$core_TAG_V_3_10")
    local v3_17=$(git log -1 --format=%ct "$core_TAG_V_3_17")
    local v4_1=$(git log -1 --format=%ct "$core_TAG_V_4_1")
    if [ ${current_timestamp} -ge ${v3_10} ] \
    && [ ${current_timestamp} -lt ${v3_17} ];then
    #[v3.10, v3.17) ext has no tags during this time
    #use commit id to select ext version
        findOptimizedCommitId "v2ray-ext" "${GOPATH}/src/${V2RAY_EXT_URL}" "${current_timestamp}" extId
        if [ -z "$extId" ];then
            echo "processSpecialVersions: could not found optimized v2ray-ext version please check"
            exit -1
        fi
        if [ -d ${GOPATH}/src/${V2RAY_EXT_URL} ];then
            cd ${GOPATH}/src/${V2RAY_EXT_URL}
            git checkout "$extId"
            echo "processSpecialVersions: v2ray-ext checkout to ---> $extId"
        fi
    elif [ ${current_timestamp} -lt ${v3_10} ];then
    #<v3.10 not support
        echo "processSpecialVersions: prior to $core_TAG_V_3_10 not support current"
        exit -1
    fi
    local coreEmptyVendors=( \
        "github.com/Yawning/chacha20" \
        "github.com/shadowsocks/go-shadowsocks2" \
    )
    for i in "${!coreEmptyVendors[@]}";
    do
        local vendorName=${coreEmptyVendors[$i]}
        isEmpty=""
        if [ -d ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/${vendorName} ];then
            isEmpty=$(ls ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/${vendorName})
            if [ -z "$isEmpty" ];then
                echo "${V2RAY_CORE_URL}/vendor/${vendorName} exits and empty"
                #remove it first
                rm -rf ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/${vendorName}
                #download now
                echo "processSpecialVersions: download ${vendorName} now"
                go get -v -u ${vendorName}
                findOptimizedCommitId "${vendorName}" "${GOPATH}/src/${vendorName}" "${current_timestamp}" vendorId

                if [ -z "$vendorId" ];then
                    echo "processSpecialVersions: could not find optimized commit id for ${vendorName}, use master for temp!!!"
                    continue
                fi

                cd "${GOPATH}/src/${vendorName}"
                git checkout "$vendorId"
                echo "processSpecialVersions: ${vendorName} checkout to ---> $vendorId"

            else
                echo "processSpecialVersions: ${V2RAY_CORE_URL}/vendor/${vendorName} not empty no need process"
                continue
            fi
        fi
    done
    return 0
}

isPreReleaseTag() {
    local tag="$1"
    if [ -z "$tag" ];then
        return 1
    fi
    if [[ ${tag} == v* ]] || [[ ${tag} == V* ]];then
        echo "tag starts with v/V"
    else
        echo "Error: not recognized tag ---> $tag"
        return 1
    fi
    local numTag=${tag:1}
    local dots=2
    dots=$(echo -n "$numTag" | awk -F "." '{print NF-1}')
    if [ $? != 0 ];then
        #not found dot error
        echo "not found dot in tag"
        return 1
    fi
    if [ ${dots} = 1 ];then
        #only one dot not preRelease
        echo "vx.y version not preRelease"
        return 0
    fi

    if [ ${dots} -gt 2 ] || [ ${dots} -lt 1 ];then
        #dots > 2 || < 1
        echo "too many dots or no dot, dot num = $dots"
        return 1
    fi
    if [ ${dots} = 2 ];then
        v1=$(echo ${numTag} | awk -F . '{print $1}')
        v2=$(echo ${numTag} | awk -F . '{print $2}')
        v3=$(echo ${numTag} | awk -F . '{print $3}')
        echo "v1=$v1, v2=$v2, v3=$v3"
        if [ ${v3} = 0 ];then
            echo "vx.y.0 release tag"
            return 0
        else
            echo "vx.y.^0 preRelease tag"
            return 1
        fi
    fi
    return 0
}

findLatestReleaseTag() {
    cd ${GOPATH}/src/${V2RAY_CORE_URL}
    local tags=$(git tag \
    | xargs -I@ git log --format=format:"%ct @%n" -1 @ \
    | sort -r \
    | awk '{print $2}')
    for tag in $(echo -ne "$tags")
    do
        isPreReleaseTag "$tag"
        if [ $? = 0 ];then
            eval $1="'${tag}'"
            break
        fi
    done
}

checkoutV2rayCoreVersion() {
    local version="master"
    local coreVendors=( \
        "github.com/miekg/dns" \
        "github.com/gorilla/websocket" \
    )
    local coreTagTimestamp=0
    if [ ! -d ${GOPATH}/src/${V2RAY_CORE_URL} ] \
    || [ ! -d ${GOPATH}/src/${V2RAY_EXT_URL} ];then
        echo "checkoutV2rayCoreVersion: fatal error tag v2ray source code not found"
        exit -1
    fi

    cd ${GOPATH}/src/${V2RAY_CORE_URL}
    git fetch \
    && git reset --hard origin/master \
    && git checkout master

    if [[ -z "$v2ray_core_version" || "$v2ray_core_version" = "LatestRelease" ]];then
        findLatestReleaseTag latestReleaseTag
        [[ -z "$latestReleaseTag" ]] \
        && echo "checkoutV2rayCoreVersion: fatal error could not found latest release tag" \
        && exit 1
        v2ray_core_version="$latestReleaseTag"
    fi
    git tag | grep -iE "^$v2ray_core_version$" > /dev/null 2>&1
    [[ $? != 0 ]] \
    && echo "checkoutV2rayCoreVersion: fatal error tag $v2ray_core_version not found in v2ray-core" \
    && exit 1
    version="$v2ray_core_version"
    #cache build tag maybe for ci use
    writeFile "$V2RAY_CORE_BUILD_TAG" "$version"
    coreTagTimestamp=$(git log -1 --format=%ct "$version")

    #checkout v2ray tag start
    cd ${GOPATH}/src/${V2RAY_CORE_URL}
    git checkout ${version}
    cd ${GOPATH}/src/${V2RAY_EXT_URL}
    git checkout ${version}
    #checkout v2ray tag end

    #checkout vendor for v2ray-core start
    local isEmpty=""
    for i in "${!coreVendors[@]}";
    do
        local vendorName=${coreVendors[$i]}

        if [ -d ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/${vendorName} ];then
            isEmpty=""
            isEmpty=$(ls ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/${vendorName})
            if [ -z "$isEmpty" ];then
            #exception process -> delete empty vendor folder
                echo "checkoutV2rayCoreVersion: ${vendorName} has been vendor with empty folder, delete it..."
                rm -rf ${GOPATH}/src/${V2RAY_CORE_URL}/vendor/${vendorName}
            else
                echo "checkoutV2rayCoreVersion: ${vendorName} has already been vendor by v2ray-core, no need checking out"
                continue
            fi
        fi

        if [ ! -d ${GOPATH}/src/${vendorName} ];then
            echo "checkoutV2rayCoreVersion: not found ${vendorName} in $GOPATH/src, download now"
            go get -v -u ${vendorName}
        fi

        if [ ! -d ${GOPATH}/src/${vendorName} ];then
            echo "checkoutV2rayCoreVersion: fatal error download ${vendorName} failed"
            exit -1
        fi
        findOptimizedTag "$vendorName" "${GOPATH}/src/$vendorName" "$coreTagTimestamp" OPTIMIZEDTAG

        if [ -z "$OPTIMIZEDTAG" ];then
            echo "checkoutV2rayCoreVersion: not found any matching tag in ${vendorName} using master for temp!!!!"
            continue
        fi
        cd ${GOPATH}/src/${vendorName}
        git tag | grep -iE "^$OPTIMIZEDTAG$" > /dev/null 2>&1
        if [ $? != 0 ];then
            echo "checkoutV2rayCoreVersion: found error tag $OPTIMIZEDTAG for ${vendorName} using master for temp!!!!"
            continue
        fi

        git checkout "$OPTIMIZEDTAG"
        echo "checkoutV2rayCoreVersion: checking ${vendorName} ----> $OPTIMIZEDTAG"
    done
    processSpecialVersions "$coreTagTimestamp"
    #checkout vendor for v2ray-core end
    cd ${INSTALL_CACHE_PATH}
    return 0
}

startTime=$(date +%s.%N)
cd `dirname $0`
SCRIPT_PATH=`pwd`
find . -name "*.sh" | xargs chmod a+x
source ./CommonUtils.sh
source ./constants.sh
cd "$SCRIPT_PATH" && findUnderUserHome && cd "$SCRIPT_PATH"
#all tmp files will be install under here, sdk, ndk build tag etc.
export INSTALL_CACHE_PATH="$under_home/$CACHE_FOLDER"
if [ ! -d ${INSTALL_CACHE_PATH} ];then
    mkdir -p ${INSTALL_CACHE_PATH}
fi

#for cache build tag
V2RAY_CORE_BUILD_TAG="$INSTALL_CACHE_PATH/$v2ray_core_tag_file"
LIB_AAR_FILE="${INSTALL_CACHE_PATH}/$libv2ray_aar"

GEO_DAT_CACHE_PATH="${INSTALL_CACHE_PATH}/geo_data"
GEO_DAT_TIMESTAMP="$GEO_DAT_CACHE_PATH/geo_timestamp"

clearFiles
installBasicDep
installGoEnv

if [ -d "${GOPATH}/src" ];then
    #force update all source code
    rm -rf "${GOPATH}/src"
fi
go get -v -u github.com/golang/protobuf/protoc-gen-go
go get -v -u ${LIBV2RAY_GIT_URL}
go get -v -u golang.org/x/mobile/cmd/...
go get -v -u ${LIBV2RAY_GIT_URL}/vendor/github.com/jteeuwen/go-bindata/...
checkoutV2rayCoreVersion

getGeoDat

if [ -d ${GOPATH}/src/github.com/xiaokangwang ];then
    #we have already vendor it
    #no need use under ${GOPATH}
    rm -rf ${GOPATH}/src/github.com/xiaokangwang
fi

cd ${GOPATH}/src/${LIBV2RAY_GIT_URL}
cd configure && make pb

cd ${GOPATH}/src/${LIBV2RAY_GIT_URL}
cd shippedBinarys; make shippedBinary

cd ${GOPATH}/src/${LIBV2RAY_GIT_URL}/vendor/github.com/xiaokangwang/V2RayConfigureFileUtil;make all
cd ${GOPATH}/src/${LIBV2RAY_GIT_URL}/vendor/github.com/xiaokangwang/libV2RayAuxiliaryURL;make all
cd ${GOPATH}/src/${LIBV2RAY_GIT_URL}/vendor/github.com/xiaokangwang/waVingOcean/configure;make

cd ${INSTALL_CACHE_PATH}

installAndroidSDKNDK
initGoMobileNDK

printGitLog ${GOPATH}/src/${LIBV2RAY_GIT_URL} "AndroidLibV2ray"
printGitLog ${GOPATH}/src/${V2RAY_CORE_URL} "v2ray-core"
printGitLog ${GOPATH}/src/${V2RAY_EXT_URL} "v2ray-ext"


cd ${INSTALL_CACHE_PATH}

gomobile bind -v  -tags json ${LIBV2RAY_GIT_URL}
clearPb
cd ${INSTALL_CACHE_PATH}
EXT_CODE=1
if [ -f ${LIB_AAR_FILE} ];then
    echo "generate $libv2ray_aar success, path = ${LIB_AAR_FILE}"
    EXT_CODE=0
else
    echo "generate $libv2ray_aar failed!!!"
    EXT_CODE=1
fi
endTime=$(date +%s.%N)
usedTime=$(echo "$endTime" "$startTime" | awk '{printf ("%.4f\n",$1-$2)}');

[[ ${EXT_CODE} = 0 ]] && echo  "build aar used time = ${usedTime}s"
exit ${EXT_CODE}
