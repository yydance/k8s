记录k8s进群的问题。

### 1.存储etcd NOSPACE
该问题，出现于部署Loki+tempo使用etcd存储hash ring的场景，经确认，与参数`--quota-backend-bytes`有关，默认值为0，其对应的限制是2Gi，官网建议最大值为8Gi，这里调整为4Gi
