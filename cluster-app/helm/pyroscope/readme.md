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
