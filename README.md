# ArDNSPod-IPv6

基于DNSPod用户API实现的纯Shell动态域名客户端，适配网卡地址。

万物互联，更新一个宽带下所有已配置域名的设备ipv6地址。
> 因为宽带运营商只动态ipv6地址的前缀，ipv6的后半部分是设备的唯一地址，永远不会变。

# Usage

## dnspod的配置
1. 在dnspod上增加ipv6的解析记录，请确保配置完成的ipv6地址测试通过可用
2. [在dnspod上创建密钥token](https://console.dnspod.cn/account/token)

## 更改`ddnspod-ipv6.sh`配置
```bash
# 填入获得密钥ID和密钥token，用逗号拼接
# LOGIN_TOKEN="密钥ID,密钥token"
LOGIN_TOKEN="184236,aa786f388f6cd138d5a53427bbf9d731"

# 需要动态解析的域名
DOMAIN="github.com"

# 需要动态解析的子域名，支持多个子域名，所有子域名需要事先配置好可用的ipv6记录
# SUB_DOMAIN="子域名1 子域名2 子域名3"
SUB_DOMAIN="router nas phone"
```

# ASUS-RT-AC86U 官方固件(3.0.0.4.384_81351)操作记录
1. [启用 SSH](http://router.asus.com/Advanced_System_Content.asp)
2. [添加用户脚本](https://github.com/RMerl/asuswrt-merlin.ng/wiki/User-scripts)：拷贝`ddnspod-ipv6.sh`文件到`/jffs/scripts/ddnspod-ipv6.sh`
3. [添加定时任务](https://github.com/RMerl/asuswrt-merlin.ng/wiki/Scheduled-tasks-(cron-jobs))
```bash
# 例如每天3点15分更新域名的解析记录
cru a ddnspod-ipv6 "15 3 0 * *  /bin/bash /jffs/scripts/ddnspod-ipv6.sh"
```

# Credit
作者：[CongAn](https://github.com/CongAn)
原始作者: anrip ProfFan
分支来源 imki911/ArDNSPod
