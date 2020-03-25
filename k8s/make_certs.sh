#!/bin/bash
# make all cert and key file
# =======================
# - etcd                                              
# - root ca                                                  
# - kube-apiserver
# - kube-controller-manager
# - kube-schdeduler
# - kube-proxy
# - admin
# =======================

ca_dir_tmp="/data/certs"
ca_dir_etcd="/data/app/etcd/ssl"
ca_dir_k8s="/data/app/k8s/pki"


echo_msg(){
  echo -e "\033[32;1m$@\033[0m"
  echo
}

err_msg() {
  echo -e "\033[031;1m$@\033[0m"
  echo
}

exec_check() {
  RETVAL=$(echo $?)
  if [ $RETVAL -ne 0 ];then
    err_msg "Current Operation Fatal,Exit..."
    exit $RETVAL
  fi
}
# make etcd ca file
make_etcd_certs(){
cat >ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
         "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
    "expiry": "87600h"
      }
    }
  }
}
EOF

cat >etcd-ca-csr.sjon <<EOF
{
    "CN": "etcd",
    "key": {
    "algo": "rsa",
    "size": 2048
    },
    "names": [
    {
        "C": "CN",
        "ST": "Beijing",
        "L": "Beijing",
        "O": "etcd",
        "OU": "Etcd Security"
    }
    ]
}
EOF

cat >etcd-csr.sjon <<EOF
{
    "CN": "etcd",
    "hosts": [
    "127.0.0.1",
    "192.168.0.7",
    "192.168.0.5",
    "192.168.0.4",
    "192.168.0.254",
    "192.168.0.250"
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
        "O": "etcd",
        "OU": "Etcd Security"
    }
    ]
}
EOF

cfssl gencert -initca etcd-ca-csr.json |cfssljson -bare etcd-ca
cfssl gencert -ca=etcd-ca.pem -ca-key=etcd-ca-key.pem -config=ca-config.json -profile=kubernetes etcd-csr.json |cfssljson -bare etcd
}

# make the root ca cert file
make_ca_certs() {
cat >ca-csr.json <<EOF
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
        "expiry": "87600h"
    }
}
EOF

cfssl gencert -initca ca-csr.json|cfssljson -bare kube-ca
}

# make kube-apiserver cert file
make_kubeapiserver_certs() {
cat >kube-apiserver-csr.json <<EOF
{
    "CN": "kube-apiserver",
    "hosts": [
        "127.0.0.1",
    "192.168.0.7",
    "192.168.0.4",
    "192.168.0.5",
    "192.168.0.254",
    "192.168.0.250",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.work"
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
        "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json -profile=kubernetes kube-apiserver-csr.json |cfssljson -bare kube-apiserver
}

# make kube-controller-manager
make_kubecontroller_manager_certs() {
cat >kube-controller-manager-csr.json <<EOF
{
    "CN": "system:kube-controller-manager",
    "hosts": [
        "127.0.0.1",
    "192.168.0.7",
    "192.168.0.4",
    "192.168.0.5",
    "192.168.0.254",
    "192.168.0.250"
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
        "O": "system:kube-controller-manager",
        "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json -profile=kubernetes kube-controller-manager-csr.json |cfssljson -bare kube-controller-manager
}

# make kube-scheduler cert file
make_kubescheduler_certs() {
cat >kube-scheduler-csr.json<<EOF
{
    "CN": "system:kube-scheduler",
    "hosts": [
        "127.0.0.1",
    "192.168.0.7",
    "192.168.0.4",
    "192.168.0.5",
    "192.168.0.254",
    "192.168.0.250"
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
        "O": "system:kube-scheduler",
        "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json -profile=kubernetes kube-scheduler-csr.json |cfssljson -bare kube-scheduler
}

# make kube-proxy cert file
make_kubeproxy_certs() {
cat >kube-proxy-csr.json<<EOF
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
        "O": "system:kube-proxy",
        "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json -profile=kubernetes kube-proxy-csr.json |cfssljson -bare kube-proxy
}

# make admin cert file
make_admin_certs() {
cat >admin-csr.json <<EOF
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
        "OU": "System"
        }
    ]
}
EOF

cfssl gencert -ca=kube-ca.pem -ca-key=kube-ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json |cfssljson -bare admin
}

exec_main(){
  
  [ -d ${ca_dir_tmp} ] && rm -rf ${ca_dir_tmp}/* || mkdir -p ${ca_dir_tmp}
  cd ${ca_dir_tmp}
  echo_msg "make etcd cert file"
  make_etcd_certs
  exec_check
  echo_msg "================================================================="
  echo_msg "make the root ca cert file"
  make_ca_certs
  exec_check
  echo_msg "================================================================="
  echo_msg "make kube-apiserver cert file"
  make_kubeapiserver_certs
  exec_check
  echo_msg "================================================================="
  echo_msg "make kube-controller-manager"
  make_kubecontroller_manager_certs
  exec_check
  echo_msg "================================================================="
  echo_msg "make kube-scheduler cert file"
  make_kubescheduler_certs
  exec_check
  echo_msg "================================================================="
  echo_msg "make kube-proxy cert file"
  make_kubeproxy_certs
  exec_check
  echo_msg "================================================================="
  echo_msg "make admin cert file"
  make_admin_certs
  exec_check
  echo_msg "================================================================="

}