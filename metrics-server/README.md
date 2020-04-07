## 部署说明

### version
metrics-server: v0.3.6  
k8s: 1.14.1
### kubelet依赖
需要kubelet开启webhook，在k8s 1.14.1版本中，kubelet启动参数由--config flag指定(详情见[官方](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/kubelet/config/v1beta1/types.go))，这里完整示例：
```
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
address: 10.10.3.27
port: 10250
readOnlyPort: 10255
cgroupDriver: cgroupfs
clusterDNS: ["172.16.0.254"]
clusterDomain: cluster.local.
resolvConf: /etc/resolv.conf
failSwapOn: false
authentication:
  anonymous:
    enabled: true
  webhook:
    enabled: true
  x509:
    clientCAFile: /data/app/k8s/certs/k8s-ca.pem
```

### 用户system:metrics-server证书
1.metrics-server-csr.json  
```
{
  "CN": "system:metrics-server",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
```

2.k8s-ca-config.json
```
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "expiry": "87600h",
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ]
      }
    }
  }
}
```

3.生成证书
```
cfssl gencert -ca=/data/app/k8s/certs/k8s-ca.pem -ca-key=/data/app/k8s/certs/k8s-ca-key.pem -config=/data/app/k8s/ca/k8s-ca-config.json -profile=kubernetes metrics-server-csr.json | cfssljson -bare metrics-server
```

### 部署
配置文件
1.metrics-server-deployment.yaml  
修改如下：  
```
image: mirrorgooglecontainers/metrics-server-amd64
args:
  - --cert-dir=/tmp
  - --secure-port=4443
  - --kubelet-preferred-address-types=InternalIP,Hostname,InternalDNS,ExternalDNS,ExternalIP #新增，避免使用hostname通信报错
  - --metric-resolution=45s #新增
  - --kubelet-insecure-tls #新增，避免证书hosts中没有node节点IP信息报错
```

2.新增metrics-server-crb.yaml  
```
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: metrics-server
rules:
  - apiGroups:
      - "metrics.k8s.io"
    resources:
      - pods
      - nodes
      - nodes/stats
      - namespaces
      - configmaps
    verbs:
      - get
      - list
      - watch
      - create
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: metrics-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: metrics-server
subjects:
- kind: User
  apiGroup: rbac.authorization.k8s.io
  name: system:metrics-server
```
因为我们使用证书用户为system:metrics-server,否则操作是报403
```
User "system:metrics-server" cannot list resource "pods" in API group "metrics.k8s.io"
```

3.kube-apiserver启动参数调整  
新增如下：  
```
--requestheader-client-ca-file=/data/app/k8s/certs/k8s-ca.pem \
--requestheader-allowed-names=aggregator,metrics-server \
--requestheader-extra-headers-prefix=X-Remote-Extra- \
--requestheader-group-headers=X-Remote-Group \
--requestheader-username-headers=X-Remote-User \
--proxy-client-cert-file=/data/app/metrics-server/certs/metrics-server.pem \
--proxy-client-key-file=/data/app/metrics-server/certs/metrics-server-key.pem"
```
如果apiserver没有kube-proxy进程，则需要添加如下：
```
--enable-aggregator-routing=true
```

4.部署应用yaml文件
```
kubectl apply -f metrics-server/
```
### 验测结果
```
kubectl top no
NAME            CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
bc-hy-master1   264m         6%     5002Mi          64%
bc-hy-node4     435m         10%    6134Mi          79%
k8s-node1       178m         4%     3111Mi          40%
k8s-node2       211m         5%     3829Mi          49%
k8s-node3       108m         2%     5430Mi          70%
k8s-node4       194m         4%     3829Mi          49%
```

