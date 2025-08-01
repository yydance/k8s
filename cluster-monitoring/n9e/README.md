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

功能使用上，基本可以满足绝大部分的监控需求，实际中，可以考虑在开源版本新增一些功能，比如操作审计，告警确认，同时需要考虑夜莺监控的API接口，但是，懂吧，API接口文档几乎为0，直接参考源码router.go，想接告警，就走callback，告警和恢复数据结构官网有说明，可以使用nc 启动一个server 监听，创建一个callback调试。

## server

- 部署基于helm，更新values.yaml中的镜像版本为8.0.0-beta.10
- 初始化SQL语句，[github](https://github.com/ccfos/nightingale/blob/v8.0.0-beta.10/docker/initsql/a-n9e.sql)，📢：这里es索引模式缺少字段，在main分支上的SQL里有，需要添加字段，[具体见这里](https://github.com/ccfos/nightingale/blob/main/docker/initsql/a-n9e.sql)

## categraf

### 物理机/宿主机
参考[官网](https://flashcat.cloud/docs/content/flashcat-monitor/categraf/2-installation/)

### 配置文件config.toml
- `providers`，开源版本保持local，http需要单独配置http_provider，但是web配置下发属于企业版功能
- 配置文件中可用的变量只有`hostname`和`ip`，似乎还有个`SN`，没测试，注意：在有虚拟网卡的情况下，如果server部署在k8s，categraf部署在k8s节点物理机，则上报探测的IP是虚拟网卡，并不是eth0
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

**通知规则**

通知规则，只有授权团队可以管理该规则，一个规则内可以添加多个通知设置，针对告警级别、时间段、标签、属性等条件设置。实际管理中，可以逻辑上以业务组来创建通知规则，请注意，只是人为定义的逻辑上名称。

通知规则，接收团队，可以被用于`订阅规则`中通知接收人。

**告警规则**

`级别抑制`，请注意，这里只适用于同一指标不同值对应的不同告警级别抑制，不能用于不同指标的条件抑制。
`只在本业务组生效`，需要主机带有ident标签，只有该业务组内的主机会触发告警，非该业务组内主机告警会被该规则丢弃。

**最终告警发送**

最终告警的触发有两个地方，`告警规则`和`订阅告警`，告警规则配置的较多，这里我们可以投机取巧，都是用`订阅告警`，第一接收人的`订阅事件持续时长超过(秒)`设置为0，告警升级对应不同的时间间隔，***实测设置为0，邮件告警延迟2分钟，且可能dial失败，企微触发即发送***。

关于告警触发的时间延迟，首先不考虑数据采集的周期，仅计算`告警评估周期`和`订阅策略`。

- 告警评估周期，取决于`告警规则`中的`执行频率`和`持续时长`
- 订阅策略，则是在`告警规则`第一触发告警后，再次触发告警的时间间隔大于等于`订阅事件持续时长超过(秒)`

## Issues

记录遇到的问题及开源夜莺系统不能实现或较弱的功能。

**告警数据**

夜莺监控数据存储在MySQL，告警历史和通知记录对应表分别`alert_his_event`和`notification_record`，需要定期删除表数据。

**web配置下发**

该功能非常有用，限于企业版，所以对于一些监控，不得不通过categraf配置插件实现，比如http网站探测。

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

**权限问题**

权限较复杂，默认的三个角色不满足需求，需要新建角色，将团队、业务组、告警规则、订阅规则等模块权限限制修改删除，仅限只读，不能修改模块资源，对于实际使用，举例：

角色
- 系统运维
- 业务运维
- 运维负责人

团队
- 系统运维人员，包括一个或多个管理员，对应读写角色
- 业务运维人员，包括一个或多个管理员，对应读写角色
- 运维负责人，超管角色

业务组
- 系统运维
- 业务运维
- 运维负责人

权限设计
- 团队各组之间人员没有成员之间交叉，如系统组和业务组运维不能同时存在一个组中
- 权限的只读，由业务组限定，业务组组中交叉，读写或只读
- 管理员创建好`通知规则`，分配好通知接收人，各成员自行订阅有权限的告警

夜莺系统，权限以业务组为核心展开。之所以需要新增一个只读角色，默认的角色，成员只要在团队和业务组，就可以修改、删除团队和业务组，权限过大。


**附加标签**

如何设计附加标签并用于告警规则、订阅告警及告警模版？
