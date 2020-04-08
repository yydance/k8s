## K8S HPA部署配置说明
k8s version: 1.14.1
目录结构:
```
- /data/app/k8s/ # 根目录
  - /data/app/k8s/ca # 生成pem证书的必要json文件
  - /data/app/k8s/certs # 生成的pem证书
  - /data/app/k8s/cfg # 服务启动参数配置文件及其他相关配置文件
```
k8s使用示例: [HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/)

### 生成kube-controller-manager pem证书
kube-controller-manager-csr.json
```json
{
  "CN": "system:kube-controller-manager",
  "hosts": [
    "127.0.0.1",
    "10.10.3.27",
    "10.10.5.13",
    "10.10.5.10"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "L": "BeiJing",
      "ST": "BeiJing",
      "O": "system:kube-controller-manager",
      "OU": "System"
    }
  ]
}
```

生成pem证书
```shell
cfssl gencert -ca=../certs/k8s-ca.pem -ca-key=../certs/k8s-ca-key.pem -config=k8s-ca-config.json -profile=kubernetes kube-controller-manager-csr.json |cfssljson -bare kube-controller-manager
```

### 生成kube-controller-manager kubeconfig文件
```shell
#设置集群参数
kubectl config set-cluster kubernetes --certificate-authority=../certs/k8s-ca.pem --embed-certs=true --server=https://10.10.3.27:6443 --kubeconfig=kube-controller-manager.kubeconfig
#设置客户端认证参数,可是使用--token代替client-certificate
kubectl config set-credentials system:kube-controller-manager --client-certificate=../certs/kube-controller-manager.pem --client-key=../certs/kube-controller-manager-key.pem --embed-certs=true --kubeconfig=kube-controller-manager.kubeconfig
#设置上下文参数
kubectl config set-context system:kube-controller-manager --cluster=kubernetes --user=system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig
#设置默认上下文
kubectl config use-context system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig
```
### controller manager节点分发pem证书及kubeconfig文件
```
pem: kube-controller-manager.pem kube-controller-manager-key.pem
kubeconfig: kube-controller-manager.kubeconfig
```
### 调整kube-controller-manager服务启动参数
新增参数:
```
--authentication-kubeconfig=/data/app/k8s/cfg/kube-controller-manager.kubeconfig \
--authorization-kubeconfig=/data/app/k8s/cfg/kube-controller-manager.kubeconfig \
--tls-cert-file=/data/app/k8s/certs/kube-controller-manager.pem \
--tls-private-key-file=/data/app/k8s/certs/kube-controller-manager-key.pem \
```
完整kube-controller-manager.conf示例:
```
KUBE_CONTROLLER_MANAGER_OPTS="--logtostderr=false \
--log-file=/data/logs/k8s/kube-controller-manager.log \
--v=4 \
--leader-elect=true \
--master=127.0.0.1:8080 \
--service-cluster-ip-range=172.16.0.0/16 \
--cluster-cidr=172.20.0.0/16 \
--cluster-name=kubernetes \
--cluster-signing-cert-file=/data/app/k8s/certs/k8s-ca.pem \
--cluster-signing-key-file=/data/app/k8s/certs/k8s-ca-key.pem \
--root-ca-file=/data/app/k8s/certs/k8s-ca.pem \
--authentication-kubeconfig=/data/app/k8s/cfg/kube-controller-manager.kubeconfig \
--authorization-kubeconfig=/data/app/k8s/cfg/kube-controller-manager.kubeconfig \
--tls-cert-file=/data/app/k8s/certs/kube-controller-manager.pem \
--tls-private-key-file=/data/app/k8s/certs/kube-controller-manager-key.pem \
--service-account-private-key-file=/data/app/k8s/certs/k8s-ca-key.pem"
```

### 测试HPA
```
kubectl apply -f grafana-hpa-examplse.yaml
```
结果:
```
[root@bc-hy-master1 cfg]# kubectl get hpa -n monitoring
NAME         REFERENCE             TARGETS                  MINPODS   MAXPODS   REPLICAS   AGE
grafana-ui   StatefulSet/grafana   31469568/500Mi, 0%/60%   1         10        1          8h
```
> !注意
> 测试发现,如果定义两个cpu类型指标,则最后一个生效
> 初次部署完成后,TARGETS获取到值无限大,导致直接起了10个replicas,暂未明确原因

### 错误汇总
现象: kubectl top no/po 能获取到指标,但是hpa应用后TARGETS为Unknown,`kubectl describe hpa grafana -n monitoring`,
原因: controller-manager服务权限问题,需要授权系统用户system:kube-controller-manager rbac权限,详情参考`https://github.com/kubernetes-sigs/metrics-server/issues/329`
解决: 如上步骤生成kube-controller-manager证书及调整controller-manager服务启动参数

### 下一步
接下来,结合prometheus监控,利用自定义api(custom.metrics.k8s.io)配置服务水平伸缩
