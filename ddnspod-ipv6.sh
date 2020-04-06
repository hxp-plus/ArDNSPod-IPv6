#!/bin/bash

#################################################
# ArDNSPod-IPv6 v0.1.0
# 使用API动态配置DNSPod的域名IPv6记录
# Github https://github.com/CongAn/ddnspod-ipv6
# 作者 anker<cong.an@qq.com>
# 原始作者 anrip<mail@anrip.com>, http://www.anrip.com/ddnspod ; ProfFan Github https://github.com/imki911/ArDNSPod
#################################################

# 1. Combine your token ID and token together as follows
LOGIN_TOKEN="184236,aa786f388f6cd138d5a53427bbf9d731"

# 2. Place each domain you want to check as follows
# you can have multiple checkDomainIP blocks
DOMAIN="github.com"
SUB_DOMAIN="router nas phone"

# Global Variables:
# 新的域名ip
newDomainIP=""
# ipv6的前缀
ipv6Prefix=""
# 记录类型
record_type='AAAA'

# OS Detection
case $(uname) in
  'Linux')
    echo "OS: Linux"
    arIpAddress() {

		  # 因为一般ipv6没有nat ipv6的获得可以本机获得
		  #ifconfig $(nvram get wan0_ifname_t) | awk '/Global/{print $3}' | awk -F/ '{print $1}'
      #ip addr show dev eth0 | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d' #如果没有nvram，使用这条，注意将eth0改为本机上的网口设备 （通过 ifconfig 查看网络接口）
      # 获得公网ipv6
      ip addr show | grep inet6 | grep 'scope global' | sed -n '1p' | sed -e's/^.*inet6 \([^ ]*\)\/.*$/\1/;t;d'
    }
    ;;
  'FreeBSD')
    echo 'OS: FreeBSD'
    exit 100
    ;;
  'WindowsNT')
    echo "OS: Windows"
    exit 100
    ;;
  'Darwin')
    echo "OS: Mac"
    arIpAddress() {
      ifconfig -a | grep 'inet6' | grep 'prefixlen 64 autoconf secured' | sed 's/^.*inet6 //' | sed 's/ .*//'
    }
    ;;
  'SunOS')
    echo 'OS: Solaris'
    exit 100
    ;;
  'AIX')
    echo 'OS: AIX'
    exit 100
    ;;
  *) ;;
esac

# Get data
# arg: type data
# see Api doc: https://www.dnspod.cn/docs/records.html#
dnsapi() {
    #local inter="https://dnsapi.cn/${1:?'Info.Version'}"
    local inter="https://dnsapi.cn/${1}"
    local param="login_token=${LOGIN_TOKEN}&format=json&${2}"
    echo "${inter}?${param}"
    #curl -Ss "${inter}" -d "${param}"
    wget --quiet --no-check-certificate --secure-protocol=TLSv1_2 --output-document=- --post-data $param $inter
}

# Get Domain IP
# arg: domain
getDomainIP() {
    local domainID recordID recordIP
    # Get domain ID
    domainID=$(dnsapi "Domain.Info" "domain=${1}")

    domainID=$(echo $domainID | sed 's/.*{"id":"\([0-9]*\)".*/\1/')

    # Get Record ID
    recordID=$(dnsapi "Record.List" "domain_id=${domainID}&sub_domain=${2}&record_type=${record_type}")

    recordID=$(echo $recordID | sed 's/.*\[{"id":"\([0-9]*\)".*/\1/')

    # Last IP
    recordIP=$(dnsapi "Record.Info" "domain_id=${domainID}&record_id=${recordID}&record_type=${record_type}")

    recordIP=$(echo $recordIP | sed 's/.*,"value":"\([0-9a-z\.:]*\)".*/\1/')

    # Output IP
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

# Update domain IP
# arg: main domain  sub domain
modifyDomainIP() {
    local domainID recordID recordRS recordCD recordIP

    # Get domain ID
    domainID=$(dnsapi "Domain.Info" "domain=${1}")
    domainID=$(echo $domainID | sed 's/.*{"id":"\([0-9]*\)".*/\1/')
    #echo $domainID
    # Get Record ID
    recordID=$(dnsapi "Record.List" "domain_id=${domainID}&record_type=${record_type}&sub_domain=${2}")
    recordID=$(echo $recordID | sed 's/.*\[{"id":"\([0-9]*\)".*/\1/')
    #echo $recordID
    # Update IP
    recordRS=$(dnsapi "Record.Modify" "domain_id=${domainID}&sub_domain=${2}&record_type=${record_type}&record_id=${recordID}&record_line=默认&value=${newDomainIP}")
    recordCD=$(echo $recordRS | sed 's/.*{"code":"\([0-9]*\)".*/\1/')
    recordIP=$(echo $recordRS | sed 's/.*,"value":"\([0-9a-z\.:]*\)".*/\1/')

    # Output IP
    if [ "$recordIP" = "$newDomainIP" ]; then
        if [ "$recordCD" = "1" ]; then
            echo $recordIP
            return 0
        fi
        # Echo error message
        echo $recordRS | sed 's/.*,"message":"\([^"]*\)".*/\1/'
        return 1
    else
        echo $recordIP #"Update Failed! Please check your network."
        return 1
    fi
}

# DDNS Check
# Arg: Main Sub
checkDomainIP() {
    local postRS
    local domainIP=$(getDomainIP $1 $2)
    newDomainIP="${ipv6Prefix}:"$(echo $domainIP | sed 's/^\([a-f0-9A-F]*:\)\{4\}//')

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

# ipv6批量动态域名解析
# Arg: Main Sub Sub Sub ……
 ddnspod() {
    local localIP=$(arIpAddress)
    # 获得ipv6的前缀
    ipv6Prefix=$(echo $localIP | sed 's/\(::1\)$//' | sed 's/\(:[a-f0-9A-F]*\)\{4\}$//')
    echo "localIP: ${localIP}"
    echo "ipv6Prefix: ${ipv6Prefix}"

    # 支持多个子域名
    # 兼容dash，for array 无法使用
    i=2
    while test $i -le $#; do
        local cmd="echo \$$i"
        local subDomain=$(eval $cmd)
        echo ''
        echo "Updating Domain: ${subDomain}.${1}"
        checkDomainIP $1 ${subDomain}
        i=$(( $i + 1 ))
    done

    return 1
}

ddnspod $DOMAIN $SUB_DOMAIN
