本节概述centos7.9升级到rocky 9.2的步骤。

## 概述
### 升级流程
centos7.9升级到rocky9.2，利用第三方工具[leapp](https://github.com/AlmaLinux/leapp-repository/tree/almalinux)，先升级到rocky8.8，然后在原地升级到9.2。

### 注意事项
- 系统内核必须是redhat系列(包括衍生操作系统)原repo库自带的kernel，任何其他自行安装的kernel，在检查时都会被忽略
- 系统内核开发包，即kernel-devel只能有一个，多余的需要先卸载
- rocky8升级到rocky9后，系统网卡会被NetworkManager管理，原network不受支持，请确保系统升级到rocky9重启前服务NetworkManager开机自启`systemctl enable NetworkManager`
- centos7.9升级到rocky8.8后，系统默认会安装`make-devel`包，该包在升级rocky9.2时会有冲突，需要先卸载`rpm -e make-devel`
- rocky8升级rocky9，需要卸载rocky-logos包

## 详细步骤
1、原系统update
```
yum update -y
```

2、安装leapp包的yum源
```
yum install -y http://repo.almalinux.org/elevate/elevate-release-latest-el7.noarch.rpm
```

3、安装leapp包
```
yum install -y leapp-upgrade leapp-data-rocky
```

> 这里升级到rocky系统，选择包`leapp-data-rocky`，其他可选`leapp-data-almalinux`，`leapp-data-centos`，`leapp-data-eurolinux`，`leapp-data-oraclelinux`

4、检查是否满足升级条件
```
leapp preupgrade
```
根据提示，解决相关问题，常见的问题：
- leapp answers，执行`leapp answer --section remove_pam_pkcs11_module_check.confirm=True`即可，
- btrfs，从rhel8开始，btrfs将被废弃，升级系统会提示，需要卸载该内核module`modprobe -r btrfs`

5、升级到rocky8.8
```
leapp upgrade
```
升级完成后，`reboot`

6、升级rocky9.2

6.1、移除原rocky repo
```
cd /etc/yum.repos.d
mv Rocky-* bak/
```

6.2、安装rocky9 repo
[rocky9 packages](https://download.rockylinux.org/pub/rocky/9/BaseOS/x86_64/os/Packages/r/)，下载rocky-gpg-keys、rocky-release、rocky-repos三个包，然后安装
```
rpm -ivh --nodeps --force rocky-*.rpm
```

6.3、升级rocky9
```
dnf clean all
dnf -y --releasever=9 --allowerasing --setopt=deltarpm=false distro-sync
```
如果有冲突，根据提示找到对应包卸载即可。

6.4、重建rpm数据库，重启系统
```
systemctl enabel NetworkManager
rpm --rebuilddb
reboot
```

愉快的玩耍吧，题外话，不要原地升级(除非不得已苦衷)，太麻烦，不如直接更换操作系统，且原地升级后，系统原安装的包和服务均会被卸载重置为系统初始状态。
