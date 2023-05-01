
[TOC]

### 一、环境说明 

#### 1、主机信息

- omt-yangguang1/10.0.9.198，k8s master，nginx tcp 6443，kubectl，nfs server 
- omt-yangguang2/10.0.9.199，k8s master/worker， node，nfs-utils
- omt-yangguang3/10.0.9.200，k8s master/worker，node，nfs-utils
- omt-yangguang4/10.0.9.201，k8s master/worker，node，nfs-utils
- 版本
  - 操作系统，centos7.9
  - 内核，5.4.188-lt
  - k8s，v1.27.1，注意：1.24版本后，k8s移除了dockershm支持，不建议使用docker作为container runtime
  - containerd
  - etcd，3.5.8
- 目录
  ```
  /data/app/k8s
  - certs，证书文件目录
  - conf，配置文件目录
  - logs，日志目录
  ```

  ```
  /data/app/etcd
  - certs
  - data
  - logs
  - wal
  ```

以下操作，主机以198/199/200/201标识

#### 2、kubectl客户端

- nginx，代理kube-apiserver
- kubectl
- kube-proxy，metrics 聚合器需要(因为已kube-proxy，不再需要)

#### 3、master节点组件

- etcd
- kube-apiserver
- kube-controller-manager
- kube-scheduler
- kube-proxy
- kubelet
- containerd


#### 4、node节点组件

- kubelet
- kube-proxy
- containerd


### 二、安装部署 

k8二进制包下载，详情见 [github](https://github.com/kubernetes/kubernetes/tree/master/CHANGELOG)

分发二进制执行文件，199/200/201都需要
```
wget https://dl.k8s.io/v1.27.1/kubernetes-server-linux-amd64.tar.gz
tar -xvf kubernetes-server-linux-amd64.tar.gz
cd kubernetes/server/bin/
cp kube-apiserver kube-controller-manager kube-scheduler kubectl kubelet kube-proxy /usr/local/bin/

```

创建节点工作目录
```
mkdir -p /data/app/k8s/{certs,conf,logs}
mkdir -p /data/app/k8s/kubelet /data/app/k8s/kube-proxy 
```

#### 1、公共部分

##### 1.1 所有节点，安装containerd及k8s依赖

containerd配置文件

安装ipvs依赖包
```
yum -y install ipvsadm ipset sysstat conntrack libseccomp nfs-utils
```

ipvs内核模块
```
cat >/etc/modules-load.d/ipvs.conf <<EOF 
ip_vs 
ip_vs_lc 
ip_vs_wlc 
ip_vs_rr 
ip_vs_wrr 
ip_vs_lblc 
ip_vs_lblcr 
ip_vs_dh 
ip_vs_sh 
ip_vs_fo 
ip_vs_nq 
ip_vs_sed 
ip_vs_ftp 
ip_vs_sh 
nf_conntrack 
ip_tables 
ip_set 
xt_set 
ipt_set 
ipt_rpfilter 
ipt_REJECT 
ipip 
EOF

systemctl enable --now systemd-modules-load.service
lsmod |grep ip_vs

```

关闭防火墙和selinux
```
systemctl stop firewalld
systemctl disable firewalld
```

关闭selinux
```
/etc/selinux/config
```

关闭交换分区
```
swapoff -a
sed -ri 's/.*swap.*/#&/' /etc/fstab
echo "vm.swappiness = 0" >> /etc/sysctl.conf 
sysctl -p
```

时间同步
```
使用chronyd服务
timedatectl
```
##### 1.2 系统初始化

```
#limit优化
ulimit -SHn 65535
​
cat <<EOF >> /etc/security/limits.conf
* soft nofile 655360
* hard nofile 131072
* soft nproc 655350
* hard nproc 655350
* soft memlock unlimited
* hard memlock unlimited
EOF

cat <<EOF > /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
fs.may_detach_mounts = 1
vm.overcommit_memory=1
vm.panic_on_oom=0
fs.inotify.max_user_watches=89100
fs.file-max=52706963
fs.nr_open=52706963
net.netfilter.nf_conntrack_max=2310720
​
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl =15
net.ipv4.tcp_max_tw_buckets = 36000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_orphans = 327680
net.ipv4.tcp_orphan_retries = 3
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.ip_conntrack_max = 131072
net.ipv4.tcp_max_syn_backlog = 16384
net.ipv4.tcp_timestamps = 0
net.core.somaxconn = 16384
EOF
sysctl --system
​
#所有节点配置完内核后，重启服务器，保证重启后内核依旧加载
reboot -h now
​
#重启后查看结果：
lsmod | grep --color=auto -e ip_vs -e nf_conntrack
```

> ipvs模块，在内核4.19+版本nf_conntrack_ipv4已经改为nf_conntrack， 4.18以下使用nf_conntrack_ipv4即可

##### 1.3 cfssl工具
略

##### 1.4 生成ca证书

创建ca请求文件
```ca-csr.json
{
    "CN": "kubernetes",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
            "O": "k8s",
            "OU": "System"
        }
    ],
    "ca": {
        "expiry": "876000h"
    }
}
```

创建ca证书
```
cfssl gencert -initca ca-csr.json | cfssljson -bare ca
```

配置ca证书策略
```ca-config.json
{
  "signing": {
    "default": {
        "expiry": "876000h"
    },
    "profiles": {
      "kubernetes": {
          "expiry": "876000h",
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

#### 2、etcd

##### 2.1 生成证书

创建csr请求文件
```etcd-server-csr.json
{
    "CN": "k8s-etcd",
    "hosts": [
        "localhost",
        "127.0.0.1",
        "10.0.9.198",
        "10.0.9.199",
        "10.0.9.200",
        "10.0.9.201"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "L": "Beijing",
            "ST": "Beijing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
```

生成证书
```
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes etcd-csr.json | cfssljson  -bare etcd
​
ls etcd*.pem
# etcd-key.pem  etcd.pem
```

##### 2.2 安装配置

下载etcd软件包，详见 [链接](https://github.com/etcd-io/etcd/releases/)

创建配置文件，详见 [官方](https://etcd.io/docs/v3.5/op-guide/configuration/)
```etcd.conf
ETCD_NAME=k8s-etcd-m2
ETCD_DATA_DIR="/data/app/etcd/data"
ETCD_SNAPSHOT_COUNT="10000"
ETCD_MAX_SNAPSHOTS="5"
ETCD_WAL_DIR="/data/app/etcd/wal"
ETCD_MAX_WALS="5"
ETCD_HEARTBEAT_INTERVAL="100"
ETCD_ELECTION_TIMEOUT="2000"
ETCD_LISTEN_PEER_URLS="https://localhost:2380,https://10.0.9.199:2380"
ETCD_LISTEN_CLIENT_URLS="https://localhost:2379,https://10.0.9.199:2379"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://10.0.9.199:2380"
ETCD_INITIAL_CLUSTER="k8s-etcd-m2=https://10.0.9.199:2380,k8s-etcd-m3=https://10.0.9.200:2380,k8s-etcd-m4=https://10.0.9.201:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://10.0.9.199:2379,https://localhost:2379"
ETCD_INITIAL_CLUSTER_TOKEN="k8s-etcd-cluster"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_CERT_FILE="/data/app/etcd/certs/etcd.pem"
ETCD_KEY_FILE="/data/app/etcd/certs/etcd-key.pem"
ETCD_CLIENT_CERT_AUTH="true"
ETCD_TRUSTED_CA_FILE="/data/app/etcd/certs/ca.pem"
ETCD_AUTO_TLS="true"
ETCD_PEER_CERT_FILE="/data/app/etcd/certs/etcd.pem"
ETCD_PEER_KEY_FILE="/data/app/etcd/certs/etcd-key.pem"
ETCD_PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_TRUSTED_CA_FILE="/data/app/etcd/certs/ca.pem"
ETCD_PEER_AUTO_TLS="true"
ETCD_LOG_OUTPUTS="/data/app/etcd/logs/etcd.log"
ETCD_LOG_LEVEL="warn"
ETCD_ENABLE_LOG_ROTATION=true
ETCD_LOG_ROTATION_CONFIG_JSON={"maxsize": 100, "maxage": 5, "maxbackups": 5, "localtime": true, "compress": true}
```

创建service管理文件
```/usr/lib/systemd/system/etcd.service
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
WorkingDirectory=/data/app/etcd/
EnvironmentFile=-/data/app/etcd/etcd.conf
User=etcd
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /usr/local/bin/etcd"
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

> 注意修改各个节点etcd.conf配置文件

etcdctl.sh

```
#!/bin/bash

etcd_ep="https://10.0.9.199:2379,https://10.0.9.200:2379,https://10.0.9.201:2379"
etcd_ca="/data/app/etcd/certs/ca.pem"
etcd_cert="/data/app/etcd/certs/etcd.pem"
etcd_key="/data/app/etcd/certs/etcd-key.pem"

etcdctl --endpoints=$etcd_ep --cacert=$etcd_ca --cert=$etcd_cert --key=$etcd_key --write-out="table" "$@"
```

查看集群状态，详见 [官方教程](https://etcd.io/docs/v3.5/tutorials/)
```
./etcdctl.sh endpoint health
./etcdctl.sh endpoint status
```

#### 3、master节点

##### 3.1 kube-apiserver

创建kube-apiserver-csr
```kube-apiserver-csr.json
{
"CN": "kube-apiserver",
  "hosts": [
    "127.0.0.1",
    "10.0.9.198",
    "10.0.9.199",
    "10.0.9.200",
    "10.0.9.201",
    "10.100.0.1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Beijing",
      "L": "Beijing",
      "O": "k8s",
      "OU": "system"
    }
  ]
}
```

生成证书和token
```
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-apiserver-csr.json | cfssljson -bare kube-apiserver
​
cat > token.csv << EOF
$(head -c 16 /dev/urandom | od -An -t x | tr -d ' '),kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
```

创建配置文件，命令参数详情参考 [官方](https://kubernetes.io/zh/docs/reference/command-line-tools-reference/kube-apiserver/)
```kube-apiserver.conf
略
```

服务管理service文件
```kube-apiserver.service
略
```

同步相关配置文件到各个节点，3个master节点
```
cp ca*.pem /data/app/k8s/certs
cp kube-apiserver*.pem /data/app/k8s/certs
cp token.csv /data/app/k8s/conf
cp kube-apiserver.conf /data/app/k8s/conf
cp kube-apiserver.service /usr/lib/systemd/system/
```

启动服务
```
systemctl daemon-reload
systemctl enable --now kube-apiserver
systemctl start kube-apiserver
```

##### 3.2 kube-controller-manager

创建csr请求文件
```kube-controller-manager-csr.json
{
    "CN": "system:kube-controller-manager",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "10.0.9.199",
      "10.0.9.200",
      "10.0.9.201"
    ],
    "names": [
      {
        "C": "CN",
        "ST": "Beijing",
        "L": "Beijing",
        "O": "system:kube-controller-manager",
        "OU": "system"
      }
    ]
}
```

生成证书
```
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
​
ls kube-controller-manager*.pem
```

创建kube-controller-manager的kubeconfig文件
```
kubectl config set-cluster kubernetes --certificate-authority=ca.pem --embed-certs=true --server=https://10.0.9.198:6443 --kubeconfig=kube-controller-manager.kubeconfig
​
kubectl config set-credentials system:kube-controller-manager --client-certificate=kube-controller-manager.pem --client-key=kube-controller-manager-key.pem --embed-certs=true --kubeconfig=kube-controller-manager.kubeconfig
​
kubectl config set-context system:kube-controller-manager --cluster=kubernetes --user=system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig
​
kubectl config use-context system:kube-controller-manager --kubeconfig=kube-controller-manager.kubeconfig
```

创建配置文件，命令行参数详见 [官方](https://kubernetes.io/zh/docs/reference/command-line-tools-reference/kube-controller-manager/)
```kube-controller-manager.conf
略
```

创建service管理文件
```kube-controller-manager.service
略
```

启动服务
```
systemctl daemon-reload 
systemctl enable --now kube-controller-manager
systemctl status kube-controller-manager
```

##### 3.3 kube-scheduler

创建csr请求文件
```kube-scheduler-csr.json
{
    "CN": "system:kube-scheduler",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "hosts": [
      "127.0.0.1",
      "10.0.9.199",
      "10.0.9.200",
      "10.0.9.201"
    ],
    "names": [
      {
        "C": "CN",
        "ST": "Beijing",
        "L": "Beijing",
        "O": "system:kube-scheduler",
        "OU": "system"
      }
    ]
}
```

生成证书
```
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json | cfssljson -bare kube-scheduler
```

创建kube-scheduler的kubeconfig
```
kubectl config set-cluster kubernetes --certificate-authority=ca.pem --embed-certs=true --server=https://10.0.9.198:6443 --kubeconfig=kube-scheduler.kubeconfig
​
kubectl config set-credentials system:kube-scheduler --client-certificate=kube-scheduler.pem --client-key=kube-scheduler-key.pem --embed-certs=true --kubeconfig=kube-scheduler.kubeconfig
​
kubectl config set-context system:kube-scheduler --cluster=kubernetes --user=system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig
​
kubectl config use-context system:kube-scheduler --kubeconfig=kube-scheduler.kubeconfig
```

创建配置文件，命令行参数见 [官方](https://kubernetes.io/zh/docs/reference/command-line-tools-reference/kube-scheduler/)
```kube-scheduler.conf
略
```

创建service管理文件
```kube-scheduler.service
略
```

启动服务
```
systemctl daemon-reload
systemctl enable --now kube-scheduler
systemctl status kube-scheduler
```

#### 4、kubectl
d
创建csr请求文件
```admin-csr.json
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "Beijing",
      "L": "Beijing",
      "O": "system:masters",
      "OU": "system"
    }
  ]
}
```

生成证书
```
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin
cp admin*.pem /data/app/k8s/certs
```

kubeconfig配置
```
kubectl config set-cluster kubernetes --certificate-authority=ca.pem --embed-certs=true --server=https://10.0.9.198:6443 --kubeconfig=admin.config

kubectl config set-credentials admin --client-certificate=admin.pem --client-key=admin-key.pem --embed-certs=true --kubeconfig=admin.config
​
kubectl config set-context kubernetes --cluster=kubernetes --user=admin --kubeconfig=admin.config
​
kubectl config use-context kubernetes --kubeconfig=admin.config
​
mkdir ~/.kube
cp kube.config ~/.kube/config
kubectl create clusterrolebinding kube-apiserver:kubelet-apis --clusterrole=system:kubelet-api-admin --user kube-apiserver --kubeconfig=~/.kube/config
> 这里--user 指向kube-apiserver证书中的CN字段
```

查看集群状态
```
export KUBECONFIG=$HOME/.kube/config
​
kubectl cluster-info
kubectl get componentstatuses
kubectl get all --all-namespaces
```

#### 5、node节点

##### 5.1 kubelet

创建kubelet-bootstrap.kubeconfig
```
BOOTSTRAP_TOKEN=$(awk -F "," '{print $1}' /data/app/k8s/conf/token.csv)
​
kubectl config set-cluster kubernetes --certificate-authority=ca.pem --embed-certs=true --server=https://10.0.9.198:6443 --kubeconfig=kubelet-bootstrap.kubeconfig
​
kubectl config set-credentials kubelet-bootstrap --token=${BOOTSTRAP_TOKEN} --kubeconfig=kubelet-bootstrap.kubeconfig
​
kubectl config set-context default --cluster=kubernetes --user=kubelet-bootstrap --kubeconfig=kubelet-bootstrap.kubeconfig
​
kubectl config use-context default --kubeconfig=kubelet-bootstrap.kubeconfig
​
kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap --kubeconfig=/root/.kube/config
```

创建配置文件，详见 [官方](https://kubernetes.io/zh/docs/tasks/administer-cluster/kubelet-config-file/)

kubelet.yaml
```
略
```

创建service管理文件

kubelet.service
```
略
```

kubelet.conf
```
略
```

启动服务
```
mkdir -p /data/app/k8s/kubelet
systemctl daemon-reload
systemctl enable --now kubelet
```

kubelet服务启动后，在master节点approve bootstrap请求
```
kubectl get csr | grep Pending | awk '{print $1}' | xargs kubectl certificate approve
```

##### 5.2 kube-proxy

创建csr请求文件

kube-proxy-csr.json
```
{
    "CN": "system:kube-proxy",
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
      {
        "C": "CN",
        "ST": "Beijing",
        "L": "Beijing",
        "O": "k8s",
        "OU": "system"
      }
    ]
}
```

生成证书
```
cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json | cfssljson -bare kube-proxy
ls kube-proxy*.pem
```

创建kubeconfig文件
```
kubectl config set-cluster kubernetes --certificate-authority=ca.pem --embed-certs=true --server=https://10.0.9.198:6443 --kubeconfig=kube-proxy.kubeconfig
​
kubectl config set-credentials kube-proxy --client-certificate=kube-proxy.pem --client-key=kube-proxy-key.pem --embed-certs=true --kubeconfig=kube-proxy.kubeconfig
​
kubectl config set-context default --cluster=kubernetes --user=kube-proxy --kubeconfig=kube-proxy.kubeconfig
​
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
```

创建kube-proxy配置文件，详见 [官方](https://kubernetes.io/zh/docs/reference/config-api/kube-proxy-config.v1alpha1/)

kube-proxy.yaml
```
略
```

创建service管理文件

kube-proxy.service
```
略
```

kube-proxy.conf
```
略
```

启动服务
```
mkdir -p /data/app/k8s/kube-proxy
systemctl daemon-reload
systemctl enable --now kube-proxy
​
systemctl status kube-proxy
```

#### 6、网络组件calico

官网清单见 [这里](https://docs.projectcalico.org/getting-started/kubernetes/installation/config-options)

```
curl https://projectcalico.docs.tigera.io/manifests/calico-etcd.yaml -O
```

需要调整的配置项

Secret
```
data:
  # Populate the following with etcd TLS configuration if desired, but leave blank if
  # not using TLS for etcd.
  # The keys below should be uncommented and the values populated with the base64
  # encoded contents of each file that would be associated with the TLS data.
  # Example command for encoding a file contents: cat <file> | base64 -w 0
  etcd-key: null
  etcd-cert: null
  etcd-ca: null
```

ConfigMap
```
data:
  # Configure this with the location of your etcd cluster.
  etcd_endpoints: "http://<ETCD_IP>:<ETCD_PORT>"
  # If you're using TLS enabled etcd uncomment the following.
  # You must also populate the Secret below with these files.
  etcd_ca: "/calico-secrets/etcd-ca"   # "/calico-secrets/etcd-ca"
  etcd_cert: "/calico-secrets/etcd-cert" # "/calico-secrets/etcd-cert"
  etcd_key: "/calico-secrets/etcd-key"  # "/calico-secrets/etcd-key"

```

DaemonSet
```
- name: CALICO_IPV4POOL_CIDR
  value: "192.168.0.0/16" # 调整为自己的pod地址池
```

其他配置根据实际调整

部署calico
```
kubectl apply -f calico-etcd.yaml
```

#### 7、coredns

```
git clone https://github.com/coredns/deployment.git

cd deployment/kubernetes
./deploy.sh -i 10.100.0.2 |kubectl apply -f -
```

测试DNS

dns-test.yaml
```
略
```

#### 8、metric-server
按照官方，部署前，先调整kube-apiserver启动参数，增加以下：

```
--requestheader-client-ca-file=/data/app/k8s/certs/ca.pem \
--proxy-client-cert-file=/data/app/k8s/certs/proxy-client.pem \
--proxy-client-key-file=/data/app/k8s/certs/proxy-client-key.pem \
--requestheader-allowed-names='' \
```

> 特别说明：这里--requestheader-allowed-names为空，表示允许所有，因为--requestheader-client-ca-file的证书与集群ca是同一个，如果不为空，建议不要使用同一ca证书，可能导致集群认证失败

部署ha metric-server，然后查看
```
kubectl top no
这时候报错，用户被禁止访问
```
这里官方yaml文件中SA账号用于内部账号授权，使用kubectl时，需要proxy-client-csr.json中CN用户绑定RBAC
```user-aggregator.yaml
略
注意：使用了特定用户aggregator
```


