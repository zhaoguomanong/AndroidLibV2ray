#!/bin/bash

cd `dirname $0`
SELF_CERT_PARENT=$(pwd)

export CERT_KEY_PATH="$cert_private"
export CERT_PATH="$cert_public"



selfSignedCert() {
    echo "[===selfSignedCert method===]"
    if [ ! -d "$SELF_CERT_PARENT" ];then
        mkdir -p ${SELF_CERT_PARENT}
    fi
    #self sign certs method
    DOMAIN_STRING=""
    for i in "${!ALL_DOMAIN_NAMES[@]}";
    do
        DOMAIN_STRING=${DOMAIN_STRING}"/CN=${ALL_DOMAIN_NAMES[$i]}"
    done
    echo "DOMAIN_STRING = $DOMAIN_STRING"

    openssl req -x509 -nodes -days 36500 -newkey rsa:4096 -keyout ${CERT_KEY_PATH} -out ${CERT_PATH} \
        -new -sha512 -subj "/C=US/ST=IN/L=Walton/O=github/OU=github${DOMAIN_STRING}" > /dev/null 2>&1
    [[ -f "$CERT_KEY_PATH" ]] && chmod 777 "$CERT_KEY_PATH"
    [[ -f "$CERT_PATH" ]] && chmod 777 "$CERT_PATH"
}

[[ -z "$domains" ]] && echo "provide at least one domain name" && exit 1

ALL_DOMAIN_NAMES=(${domains// / })

selfSignedCert