#!/bin/bash
# deploy the service 'kube-apiserver'

[ -f /etc/profile.d/kubernetes.sh ] && source /etc/profile.d/kubernetes.sh || K8S_HOME="/data/app/k8s"
ETCD_HOME="/data/app/etcd"
make_config() {
cat >${K8S_HOME}/etc/kube-apiserver.conf <<EOF
KUBE_APISERVER_OPTS="--etcd-servers=https://192.168.0.7:2379,https://192.168.0.4:2379,https://192.168.0.5:2379 \
--etcd-cafile=${ETCD_HOME}/ssl/etcd-ca.pem \
--etcd-certfile=${ETCD_HOME}/ssl/etcd.pem \
--etcd-keyfile=${ETCD_HOME}/ssl/etcd-key.pem \
--advertise-address=192.168.0.7 \
--secure-port=6443 \
--logtostderr=false \
--log-dir=${K8S_HOME}/log/ --v=2 \
--audit-log-maxage=7 \
--audit-log-maxbackup=10 \
--audit-log-maxsize=100 \
--audit-log-path=${K8S_HOME}/log/kubernetes.audit --event-ttl=12h \
--service-cluster-ip-range=10.99.0.0/16 \
--enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,PersistentVolumeClaimResize,PodPreset \
--storage-backend=etcd3 \
--apiserver-count=3 \
--endpoint-reconciler-type=lease \
--runtime-config=api/all,settings.k8s.io/v1alpha1=true,admissionregistration.k8s.io/v1beta1 \
--allow-privileged=true \
--authorization-mode=Node,RBAC \
--enable-bootstrap-token-auth=true \
--token-auth-file=${K8S_HOME}/etc/token.csv \
--service-node-port-range=30000-40000 \
--tls-cert-file=${K8S_HOME}/pki/kube-apiserver.pem \
--tls-private-key-file=${K8S_HOME}/pki/kube-apiserver-key.pem \
--client-ca-file=${K8S_HOME}/pki/kube-ca.pem \
--service-account-key-file=${K8S_HOME}/pki/sa.pub \
--enable-swagger-ui=false \
--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname \
--anonymous-auth=false \
--kubelet-client-certificate=${K8S_HOME}/pki/admin.pem \
--kubelet-client-key=${K8S_HOME}/pki/admin-key.pem"
EOF

cat >/usr/lib/systemd/system/kube-apiserver.service <<EOF
[Unit]
Description=Kubernetes API Service
Documentation=https://github.com/kubernetes/kubernetes
After=network.target

[Service]
EnvironmentFile=-/data/app/k8s/etc/kube-apiserver.conf
ExecStart=/data/app/k8s/server/bin/kube-apiserver \$KUBE_APISERVER_OPTS
Restart=on-failure
Type=notify
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
}

kubeapiserver_service() {
  make_config
  systemctl daemon-reload
  systemctl enable kube-apiserver
  systemctl start kube-apiserver
}
