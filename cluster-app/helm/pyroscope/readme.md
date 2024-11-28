应用性能分析平台pyroscope
---

平台部署两套环境，因为使用华为云obs，均部署在华为云k8s集群。

### sit13
该环境用于sit13/uat14/im（含华为云）的应用数据采集分析。
### eeo
该环境用于生产的应用数据采集分析，包括自建k8s和华为云k8s集群。

### 部署

```
helm install agent grafana/grafana-agent -f values.yaml -n pyroscope

helm install pyroscope grafana/pyroscope -f values.yaml -n pyroscope
```

### 注意事项
- 对于一个pod多个container，agent会对每个container目标采集数据，这对于profile的cpu指标，下一个周期采集前采集数据会导致500，因此需要过滤container
