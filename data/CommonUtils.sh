#!/bin/bash



function printGitLog() {
    local repo="$1"
    local repoName="$2"
    if [ -z "$repoName" ];then
        echo "printGitLog: illegal parameter repoName!"
    fi
    if [ -z "$repo" ];then
        echo "printGitLog: illegal parameter repo dir!"
        return
    fi
    if [ ! -d "$repo" ];then
        echo "printGitLog: git repo $repo not exits"
        return
    fi
    which git > /dev/null 2>&1
    if [ $? != 0 ];then
        echo "printGitLog: git not installed"
        return
    fi
    cd "$repo"
    echo -ne "\n\n\n++++++++++++++++++[$repoName] Commit History Start++++++++++++++++++\n\n\n"
    git log -5 --pretty='format:[%h] [%ci] %<(20)%an [%s]'
    echo -ne "\n\n\n------------------[$repoName] Commit History End------------------\n\n\n"
    return 0
}

export -f printGitLog

function readFile() {
    local filePath=$1
    result=""
    if [ -f "$filePath" ];then
        result=$(cat "$filePath")
    fi
    eval $2="'${result}'"
}

export -f readFile

function writeFile() {
    local debug=0
    local filePath="$1"
    local writeContent="$2"
    if [ -z "$filePath" ];then
        echo "empty file path return"
        return
    fi
    local parentPath=""
    echo -n "$filePath" | grep -iE '/' > /dev/null 2>&1
    if [ $? != 0 ];then
        parentPath=""
    else
        parentPath=${filePath%/*}
    fi
    if [ ! -z "$parentPath" ] && [ ! -d "$parentPath" ];then
        mkdir -p "$parentPath"
    fi

    if [ -f "$filePath" ];then
        readFile "$filePath" originalContent
        if [ "x$originalContent" = "x$writeContent" ];then
            if [ ${debug} = 1 ];then
                echo "file: [$filePath] content not changed no need write"
            fi
            return
        fi
    fi
    echo -n "$writeContent" > "$filePath"
}

export -f writeFile

function displaySeconds() {
    local T=$1
    local D=$((T/60/60/24))
    local H=$((T/60/60%24))
    local M=$((T/60%60))
    local S=$((T%60))
    (( $D > 0 )) && printf '%d days ' ${D}
    (( $H > 0 )) && printf '%d hours ' ${H}
    (( $M > 0 )) && printf '%d minutes ' ${M}
    (( $D > 0 || $H > 0 || $M > 0 )) && printf 'and '
    printf '%d seconds\n' ${S}
}

export -f displaySeconds

function utcTimeFormat() {
    local time=$1
    date -u -d "1970-01-01 UTC $time seconds" '+%Y%m%d %H:%M:%S'
}

export -f utcTimeFormat

function findOptimizedTag() {
    #finding nearest tag to baseTime in this repo
    #the finding tag timestamp must <= baseTime
    local debug=1
    local repoName="$1"
    local repoPath="$2"
    local baseTime="$3" #UTC seconds time
    #tagsArray and timeArray length are same all the time
    local tagsArray=()
    local timeArray=()
    local index=0
    local optimizedIndex=-1
    local optimizedTag=""

    if [ ! -d "$repoPath" ];then
        echo "findOptimizedTag: error git repo path ---> $repoPath"
        return 0
    fi

    if [ -z "$baseTime" ];then
        echo "findOptimizedTag: error empty baseTime, please check!!!!"
        return 0
    fi

    echo "findOptimizedTag: baseTime = $(utcTimeFormat ${baseTime})"

    cd "$repoPath"

    local gitTag=$(git tag \
    | xargs -I@ git log --format=format:"%ct @%n" -1 @ \
    | sort)
    local tagNames=$(echo -ne "$gitTag" | awk '{print $2}')
    local timeStamps=$(echo -ne "$gitTag" | awk '{print $1}')

    index=0
    for tag in $(echo -ne "$tagNames")
    do
        tagsArray[$index]="$tag"
        ((index++))
    done
    index=0
    for timestamp in $(echo -ne "$timeStamps")
    do
        timeArray[$index]="$timestamp"
        ((index++))
    done

    local length=${#tagsArray[@]}
    local minIndex=0
    local maxIndex
    ((maxIndex=length-1))
    if [ ${debug} = 1 ];then
        echo "[findOptimizedTag]: [repoName = $repoName]: length = $length , maxIndex=$maxIndex"
    fi
    local minTime=${timeArray[0]}
    local maxTime=${timeArray[maxIndex]}
    if [ ${debug} = 1 ];then
        echo "[findOptimizedTag]: [repoName = $repoName]: minTime = $(utcTimeFormat ${minTime}) , maxTime=$(utcTimeFormat ${maxTime})"
    fi
    #print out timestamp and tag to screen for debug
    local i=0
    while [ ${i} -lt ${length} ]
    do
        printf "[findOptimizedTag]: [repoName = $repoName]: timestamp = %-15s tag = %-25s\n" \
        "$(utcTimeFormat ${timeArray[$i]})" \
        "${tagsArray[$i]}"
        let i++
    done

    if [ ${baseTime} -lt ${minTime} ];then
        optimizedIndex=-1
        echo "[findOptimizedTag]: [repoName = $repoName]: optimizedIndex --> $optimizedIndex"
        eval $4="'${optimizedTag}'"
        return 0
    fi

    optimizedIndex=${minIndex}
    i=0
    while [ ${i} -lt ${length} ]
    do
        if [ ${baseTime} -ge ${timeArray[$i]} ];then
            optimizedIndex=${i}
        else
            break
        fi
        let i++
    done

    optimizedTag="${tagsArray[$optimizedIndex]}"
    echo "[findOptimizedTag]: [repoName = $repoName]: optimizedIndex --> $optimizedIndex, optimizedTag --> $optimizedTag"
    eval $4="'${optimizedTag}'"

    return 0
}


export -f findOptimizedTag

function findOptimizedCommitId() {
    #finding nearest commit id to baseTime in this repo
    #the finding commit id timestamp must <= baseTime
    local debug=1
    local repoName="$1"
    local repoPath="$2"
    local baseTime="$3" #UTC seconds time

    #hashIds and timeArray length are same all the time
    local hashIds=()
    local timeArray=()
    local subjectArray=()
    local index=0
    local optimizedIndex=-1
    local optimizedId=""


    if [ ! -d "$repoPath" ];then
        echo "findOptimizedCommitId: error git repo path ---> $repoPath"
        return 0
    fi

    if [ -z "$baseTime" ];then
        echo "findOptimizedCommitId: error empty baseTime, please check!!!!"
        return 0
    fi

    echo "findOptimizedCommitId: baseTime = $(utcTimeFormat ${baseTime})"

    cd "$repoPath"

    local gitLog=$(git log --pretty='format:%ct %h %s' \
    | sort)

    local hashIds=$(echo -ne "$gitLog" | awk '{print $2}')
    local timeStamps=$(echo -ne "$gitLog" | awk '{print $1}')
    local subjects=$(echo -ne "$gitLog" | awk '{print $3}')

    index=0
    for id in $(echo -ne "$hashIds")
    do
        hashIds[$index]="$id"
        ((index++))
    done
    index=0
    for timestamp in $(echo -ne "$timeStamps")
    do
        timeArray[$index]="$timestamp"
        ((index++))
    done
    index=0
    for id in $(echo -ne "$subjects")
    do
        subjectArray[$index]="$id"
        ((index++))
    done

    local length=${#hashIds[@]}
    local minIndex=0
    local maxIndex
    ((maxIndex=length-1))
    if [ ${debug} = 1 ];then
        echo "[findOptimizedCommitId]: [repoName = $repoName]: length = $length , maxIndex=$maxIndex"
    fi
    local minTime=${timeArray[0]}
    local maxTime=${timeArray[maxIndex]}
    if [ ${debug} = 1 ];then
        echo "[findOptimizedCommitId]: [repoName = $repoName]: minTime = $(utcTimeFormat ${minTime}) , maxTime=$(utcTimeFormat ${maxTime})"
    fi
    #print out timestamp and tag to screen for debug
    local i=0
    while [ ${i} -lt ${length} ]
    do
        printf "[findOptimizedCommitId]: [repoName = $repoName]: timestamp = %-15s commitId = %-8s subject = %-20s\n" \
        "$(utcTimeFormat ${timeArray[$i]})" \
        "${hashIds[$i]}" \
        "${subjectArray[$i]}"
        let i++
    done

    if [ ${baseTime} -lt ${minTime} ];then
        optimizedIndex=-1
        echo "[findOptimizedCommitId]: [repoName = $repoName]: optimizedIndex --> $optimizedIndex"
        eval $4="'${optimizedId}'"
        return 0
    fi

    optimizedIndex=${minIndex}
    i=0
    while [ ${i} -lt ${length} ]
    do
        if [ ${baseTime} -ge ${timeArray[$i]} ];then
            optimizedIndex=${i}
        else
            break
        fi
        let i++
    done

    optimizedId="${hashIds[$optimizedIndex]}"
    echo "[findOptimizedCommitId]: [repoName = $repoName]: optimizedIndex --> $optimizedIndex, optimizedId --> $optimizedId"
    eval $4="'${optimizedId}'"


    return 0
}

export -f findOptimizedCommitId

function readFile() {
    local filePath=$1
    result=""
    if [ -f "$filePath" ];then
        result=$(cat "$filePath")
    fi
    eval $2="'${result}'"
}

export -f readFile

function writeFile() {
    local debug=0
    local filePath="$1"
    local writeContent="$2"
    if [ -z "$filePath" ];then
        echo "empty file path return"
        return
    fi
    local parentPath=""
    echo -n "$filePath" | grep -iE '/' > /dev/null 2>&1
    if [ $? != 0 ];then
        parentPath=""
    else
        parentPath=${filePath%/*}
    fi
    if [ ! -z "$parentPath" ] && [ ! -d "$parentPath" ];then
        mkdir -p "$parentPath"
    fi

    if [ -f "$filePath" ];then
        readFile "$filePath" originalContent
        if [ "x$originalContent" = "x$writeContent" ];then
            if [ ${debug} = 1 ];then
                echo "file: [$filePath] content not changed no need write"
            fi
            return
        fi
    fi
    echo -n "$writeContent" > "$filePath"
}

export -f writeFile

function restartService() {
    local serviceName=$1
    if [ -z "$serviceName" ];then
        return 0
    fi
    which systemctl > /dev/null 2>&1
    if [ $? != 0 ];then
        nohup service ${serviceName} restart > /dev/null 2>&1 &
    else
        systemctl daemon-reload
        systemctl restart ${serviceName}.service
    fi
    return 0
}

export -f restartService

findUnderUserHome() {
    #find the script's path under whose home
    #return the absolute path of the home path

    #provide override by jenkins or command line
    echo "override_under_home=$override_under_home"
    [[ -d "$override_under_home" ]] \
    && export under_home="$override_under_home" \
    && return 0
    local UNDER_USER_HOME="/root"
    local rootPath=$(pwd)
    echo "$rootPath" | grep -iE '/home' > /dev/null 2>&1
    if [ $? = 0 ];then
        echo "$rootPath under /home"
        local UNDER_USER=$(echo "$rootPath" | cut -d '/' -f3)
        if [ -z "$UNDER_USER" ];then
            UNDER_USER_HOME="/root"
        else
            UNDER_USER_HOME="/home/$UNDER_USER"
        fi
    else
        echo "$rootPath under other path"
        UNDER_USER_HOME="/root"
    fi

    [[ ! -d "$UNDER_USER_HOME" ]] && UNDER_USER_HOME="/root"
    export under_home="$UNDER_USER_HOME"
    return 0
}

export -f findUnderUserHome