该文档较为仓促简单，后续将完善...
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
