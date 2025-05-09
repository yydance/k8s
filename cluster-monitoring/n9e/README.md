夜莺监控
---

> 夜莺监控中，很多模版图表使用了一些标签，使用过程中缺失的需要在categraf中补齐

基本环境
- server，v8.0.0-beta.10版本
- categraf，v0.4.3，建议更新到v0.4.8或者最新版
- OS，rocky linux 9.2
- k8s，v1.28.15，小知识，k8s v1.28.2以下版本在cgroup v2下，cadvisor采集的数据不准确，强烈建议更新，或者不使用cgroup v2
- 存储使用victoriaMetrics

## 常用功能
- http 网站探测
- 系统指标
- 网络指标
- 大屏图标
- 分级告警
- 角色权限，体现在各个团队、业务组仅拥有部分主机监控项、dashboard、告警等权限.
- ...

## server

- 部署基于helm，更新values.yaml中的镜像版本为8.0.0-beta.10
- 初始化SQL语句，[github](https://github.com/ccfos/nightingale/blob/v8.0.0-beta.10/docker/initsql/a-n9e.sql)，📢：这里es索引模式缺少字段，在main分支上的SQL里有，需要添加字段，[具体见这里](https://github.com/ccfos/nightingale/blob/main/docker/initsql/a-n9e.sql)

## categraf

### 物理机/宿主机
参考[官网](https://flashcat.cloud/docs/content/flashcat-monitor/categraf/2-installation/)

### 配置文件config.toml
- `providers`，开源版本保持local，http需要单独配置http_provider，但是web配置下发属于企业版功能
- 配置文件中可用的变量只有`hostname`和`ip`，注意：在有虚拟网卡的情况下，如果server部署在k8s，categraf部署在k8s节点物理机，则上报探测的IP是虚拟网卡，并不是eth0
- `global.labels`，添加标签`ident = "$hostname"`，夜莺监控web控制台大量的模版使用ident做过滤条件，包括图标、告警等
- `heartbeat`，URL中添加gid可以自动添加业务组，但是只有第一个参数gid有效，页面可以为机器资源添加多个业务组

### 自定义采集
使用`exec`插件完成

### k8s集群数据指标
不推荐使用categraf插件采集k8s集群组件、pod、container、metrics等指标数据，原因：
- 插件标签处理不方便，且各插件文档描述较少，可能需要看源码确定，dashboard中面板不匹配，需要做变更
- 基于prometheus的生态，很多应用直接使用prometheus crd定义，便于对接生态应用

所以，这里使用prometheus采集k8s集群所有数据指标，数据存储到`victoriaMetrics`，在夜莺dashboard中使用vm数据源进行所有操作

## 监控规划
对于基于`夜莺`和`prometheus`生态的监控，重点处理两方面：`数据标签`和`告警`

### 数据标签


### 告警
告警设计，主要包括告警条件、级别、抑制/屏蔽、收敛、告警分组、分级策略、模版。

**告警渠道**

渠道以告警级别为基本条件划分，分别为：

- 邮件，info，仅用于测试，实际发送到企微、钉钉、飞书等企业内部IM系统
- 企微，warning
- 电话/短信，critical

**告警模版**

模板中包含必要的信息，如下：

- 告警系统链接地址
- 

## Issues

记录遇到的问题及开源夜莺系统不能实现或较弱的功能。

**web配置下发**

该功能非常有用，限于企业版

**告警收敛**

当前并不能配置类似alertmanage复杂的收敛规则，仅限于完全一样的条件，高级别抑制低级别，比如内存告警设置了30%、20%、10%三个条件告警，10%触发的情况下会抑制30%和20%的告警.

**监控取值与kubectl top不一致**

监控采集的node 内存使用与kubectl top no不一致，kubectl top no获取的内存使用率偏高

原因：k8s集群kubelet使用systemd cgroupDriver，containerd使用systemd，systemd未启用cgroupv2

解决：操作系统内核systemd启用cgroupv2，`GRUB_CMDLINE_LINUX`添加`systemd.unified_cgroup_hierarchy=1`

```
$ cat /etc/default/grub
GRUB_CMDLINE_LINUX="rhgb net.ifnames=0 biosdevname=0 console=ttyS0 quiet crashkernel=1G-4G:192M,4G-64G:256M,64G-:512M systemd.unified_cgroup_hierarchy=1"

$ grub2-mkconfig -o /boot/grub2/grub.cfg
$ reboot
```
