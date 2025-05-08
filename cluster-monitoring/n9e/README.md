夜莺监控使用记录
---

基本环境
- server，v8.0.0-beta.10版本
- categraf，v0.4.3，建议更新到v0.4.8或者最新版
- OS，rocky linux 9.2
- k8s，v1.28.15，小知识，k8s v1.28.2以下版本在cgroup v2下，cadvisor采集的数据不准确，强烈建议更新，或者不使用cgroup v2
- 存储使用victoriaMetrics

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

### 采集k8s集群数据指标
 
## 常用功能
- http 网站探测
- 系统指标
- 网络指标
- 大屏图标
- 分级告警
- 角色权限
- ...
