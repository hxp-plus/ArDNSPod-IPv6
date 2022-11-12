#!/bin/bash

#################################################
# ArDNSPod-IPv6 v0.1.0
# 使用API动态配置DNSPod的域名IPv6记录
# Github https://github.com/CongAn/ddnspod-ipv6
# 作者 anker<cong.an@qq.com>
# 原始作者 anrip<mail@anrip.com>, http://www.anrip.com/ddnspod ; ProfFan Github https://github.com/imki911/ArDNSPod
#################################################

# 1. Combine your token ID and token together as follows
LOGIN_TOKEN="358521,f92cc05af408d7c2e5c9b6cf6f9411c3"

# 2. Place each domain you want to check as follows
DOMAIN="hxp.plus"
SUB_DOMAIN="ipv6.rhel9"

# Global Variables
newDomainIP=""
ipv6Prefix=""
record_type='AAAA'

arIpAddress() {
  ip addr show | grep inet6 | grep 'scope global' | sed -n '1p' | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d'
}

dnsapi() {
  local inter="https://dnsapi.cn/${1}"
  local param="login_token=${LOGIN_TOKEN}&format=json&${2}"
  echo "${inter}?${param}"
  wget --quiet --no-check-certificate --secure-protocol=TLSv1_2 --output-document=- --post-data $param $inter
}

getDomainIP() {
  local domainID recordID recordIP
  domainID=$(dnsapi "Domain.Info" "domain=${1}")
  domainID=$(echo $domainID | sed 's/.*{"id":"\([0-9]*\)".*/\1/')
  recordID=$(dnsapi "Record.List" "domain_id=${domainID}&sub_domain=${2}&record_type=${record_type}")
  recordID=$(echo $recordID | sed 's/.*\[{"id":"\([0-9]*\)".*/\1/')
  recordIP=$(dnsapi "Record.Info" "domain_id=${domainID}&record_id=${recordID}&record_type=${record_type}")
  recordIP=$(echo $recordIP | sed 's/.*,"value":"\([0-9a-z\.:]*\)".*/\1/')
  case "$recordIP" in
    [1-9a-z]*)
      echo $recordIP
      return 0
      ;;
    *)
      echo "Get Record Info Failed!"
      return 1
      ;;
  esac
}

modifyDomainIP() {
  local domainID recordID recordRS recordCD recordIP
  domainID=$(dnsapi "Domain.Info" "domain=${1}")
  domainID=$(echo $domainID | sed 's/.*{"id":"\([0-9]*\)".*/\1/')
  recordID=$(dnsapi "Record.List" "domain_id=${domainID}&record_type=${record_type}&sub_domain=${2}")
  recordID=$(echo $recordID | sed 's/.*\[{"id":"\([0-9]*\)".*/\1/')
  recordRS=$(dnsapi "Record.Modify" "domain_id=${domainID}&sub_domain=${2}&record_type=${record_type}&record_id=${recordID}&record_line=默认&value=${newDomainIP}")
  recordCD=$(echo $recordRS | sed 's/.*{"code":"\([0-9]*\)".*/\1/')
  recordIP=$(echo $recordRS | sed 's/.*,"value":"\([0-9a-z\.:]*\)".*/\1/')
  if [ "$recordIP" = "$newDomainIP" ]; then
    if [ "$recordCD" = "1" ]; then
      echo $recordIP
      return 0
    fi
      echo $recordRS | sed 's/.*,"message":"\([^"]*\)".*/\1/'
      return 1
  else
    echo $recordIP #"Update Failed! Please check your network."
    return 1
  fi
}
checkDomainIP() {
  local postRS
  local domainIP=$(getDomainIP $1 $2)
  newDomainIP=${localIP}
  if [ $? -eq 0 ]; then
    echo "domainIP:    ${domainIP}"
    echo "newDomainIP: ${newDomainIP}"
    if [ "$domainIP" != "$newDomainIP" ]; then
      postRS=$(modifyDomainIP $1 $2)
      if [ $? -eq 0 ]; then
        echo "update to ${postRS} successed."
        return 0
      else
        echo "postRS: ${postRS}"
        return 1
      fi
    fi
    echo "Last IP is the same as current, no action."
    return 1
  fi
}

ddnspod() {
  local localIP=$(arIpAddress)
  ipv6Prefix=$(echo $localIP | sed 's/\(::1\)$//' | sed 's/\(:[a-f0-9A-F]*\)\{4\}$//')
    echo "localIP: ${localIP}"
    echo "ipv6Prefix: ${ipv6Prefix}"
    i=2
    while test $i -le $#; do
      local cmd="echo \$$i"
      local subDomain=$(eval $cmd)
      echo ''
      echo "Updating Domain: ${subDomain}.${1}"
      checkDomainIP $1 ${subDomain}
      i=$(( $i + 1 ))
    done
    echo
    return 1
}

ddnspod $DOMAIN $SUB_DOMAIN

