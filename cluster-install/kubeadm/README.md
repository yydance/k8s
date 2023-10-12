### 依赖
1、内核
```
yum -y install ipvsadm ipset
cp 50-k8s.conf /etc/modules-load.d/50-k8s.conf
systemctl enable --now systemd-modules-load
```
