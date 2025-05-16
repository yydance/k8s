kube-prometheus
---

对社区清单做了微调
- 不部署np策略
- 使用夜莺监控，不部署promethues rules和alertmanage
- prometheus使用远程存储vm，和夜莺共用

数据保留
- prometheus仅保留24小时本地数据，用于支持告警规则和即时查询，注意：本地数据保留需要覆盖告警规则的评估周期
- vm保留3天
