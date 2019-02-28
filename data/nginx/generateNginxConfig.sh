#!/bin/bash

#this script can only be execute manually, cannot be called by jenkins
#or nginx will be killed by jenkins after jobs done
#
#Usage:
#sudo ./generateNginxConfig.sh your.ssl.domain.name1 your.ssl.domain.name2 ...
#at least one domain name should be provided

cd `dirname $0`
cd ..
projectRoot=$(pwd)
source ${projectRoot}/CommonUtils.sh
source ${projectRoot}/constants.sh

export domains="$@"

[[ -z "$domains" ]] && echo "provide at least one domain name" && exit 1

yourSSLDomainName=$(echo "$domains" | awk '{print $1}')

export override_under_home="/home/jenkins/share_disk"
findUnderUserHome
nginxRuntimePath="$under_home/.libv2ray/nginx/.runtime"

NGNIX_CONFIG_TEMPLET="$projectRoot/nginx/jenkins.nginx.conf"
NGINX_JENKINS_RUNTIME="$nginxRuntimePath/nginx/jenkins.nginx.conf"
CONFIG_PATH="/etc/nginx/conf.d"

certsParent="$nginxRuntimePath/nginx/certs"

[[ ! -d "$certsParent" ]] && mkdir -p "$certsParent" && chmod -R 777 "$nginxRuntimePath"

export cert_public="$certsParent/fullchain.pem"
export cert_private="$certsParent/privkey.pem"

${projectRoot}/nginx/selfSignedCertsUtil.sh

[[ ! -f "$cert_public" || ! -f "$cert_private" ]] && echo "generate certs failed" && exit 1

template_file_content=$(cat ${NGNIX_CONFIG_TEMPLET})
template_file_content_replaced=$(echo -n "$template_file_content" \
    | sed "s+\$yourSSLDomainName+${yourSSLDomainName}+g" \
    | sed "s+\$cert_public+${cert_public}+g" \
    | sed "s+\$cert_private+${cert_private}+g")

originalRuntime=""
[[ -f ${NGINX_JENKINS_RUNTIME} ]] && originalRuntime=$(cat ${NGINX_JENKINS_RUNTIME})
writeFile ${NGINX_JENKINS_RUNTIME} "$template_file_content_replaced"
chmod 777 ${NGINX_JENKINS_RUNTIME}
#write include file and pointer to ${NGINX_JENKINS_RUNTIME}
writeFile "${CONFIG_PATH}/jenkins.conf" "include ${NGINX_JENKINS_RUNTIME};"

[[ "$originalRuntime" != "$template_file_content_replaced" ]] \
&& echo "jenkins nginx config changed restart nginx service now" \
&& restartService "nginx"









