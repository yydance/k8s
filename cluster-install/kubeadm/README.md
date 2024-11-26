
---
本节记录使用kubeadm部署高可用k8s集群，其环境：

1、操作系统  
centos7.9，内核6.1.38
2、k8s集群
- 组件版本, 1.28.2
- kubeadm, 1.28.2
- cilium, 1.14.2, 完全无kube-proxy


### 依赖
1、内核
```
yum -y install ipvsadm ipset
cp 50-k8s.conf /etc/modules-load.d/50-k8s.conf
systemctl enable --now systemd-modules-load
```

### 安装
安装前，所有节点先拉取镜像
```
kubeadm config images pull --config kubeadm-config.yaml
```

1、所有节点安装containerd
```
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install containerd.io
```

2、所有节点安装kubeadm、kubelet、kubectl
```
yum -y install kubeadm kubelet kubectl
```
3、初始化控制平面

> 这里不按照kube-proxy，后面将部署cilium完全替代kube-proxy

```
kubeadm init --config kubeadm-config.yaml --upload-certs --skip-phases=addon/kube-proxy
```
如上，如有异常，根据提示解决预检错误即可，然后将其他节点加入集群

4、cilium
```
helm install cilium cilium/cilium -f ./values.yaml -n kube-system
```

更新cilium
```
helm upgrade cilium -n kube-system --reuse-values --set bpf.Masquerade=true
```

5、部署后
部署完成后，根据提示的信息，添加control-plane和worker节点。默认，控制平面节点不能用于pod调度，取消taint即可
```
kubectl get no --show-taint
kubectl taint no pre-k8msre2 node-role.kubernetes.io/control-plane-
```

### 问题记录
1. 证书更新后查看pod日志失败，tls internal error
```
问题：kubelet server/client证书未更新，当kubelet证书到期后，会自动发起csr证书请求，但是集群不会自动批准csr请求，通过`kubectl get csr`可查看
解决：手动批准证书，`kubectl get csr|grep Pending|awk '{print $1}'|xargs -n1 kubectl certificate approve`

自动批准csr，尚未测试
```
2. 
