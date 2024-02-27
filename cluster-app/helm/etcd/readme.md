

### helm部署
```
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install loki-etcd bitnami/etcd -f values.yaml  -n loki
```

### 备份恢复
从已备份的数据部署etcd集群
```
startFromSnapshot:
  enabled: true
  existingClaim: etcd-backup-pvc
  snapshotFilename: db-2024-02-01_08-20
```
备份数据的方式，有以下两种：

1. 使用disasterRecovery选项

```
disasterRecovery:
  enabled: true
  pvc:
    size: 10Gi
    storageClassName: "nfs-client"
  cronjob:
    historyLimit: 3
    snapshotHistoryLimit: 3
    schedule: "*/10 * * * *"
```

2. 手动备份
```
kubectl apply -f etcd-backup-cronjob.yaml
```
