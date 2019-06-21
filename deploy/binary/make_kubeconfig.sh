#!/bin/bash
# make all kubeconfig for kubernetes cluster
#

[ -f /etc/profile.d/kubernetes.sh ] && source /etc/profile.d/kubernetes.sh || K8S_HOME="/data/app/k8s"
if [ -f ${K8S_HOME}/etc/token.csv ];then
    BOOTSTRAP_TOKEN=$(cut -d, -f1 ${K8S_HOME}/etc/token.csv)
else
    BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom |od -An -t x |tr -d ' ')
    echo "${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,\"system:kubelet-bootstrap\"" >${K8S_HOME}/etc/token.csv
fi

KUBE_APISERVER="https://192.168.0.254"

# make kubelet bootstrap kubeconfig
make_bootstrap_kubeconfig() {
kubectl config set-cluster kubernetes \
--certificate-authority=${K8S_HOME}/pki/kube-ca.pem \
--embed-certs=true \
--server=${KUBE_APISERVER} \
--kubeconfig=${K8S_HOME}/kubelet-bootstrap.kubeconfig

kubectl config set-credentials kubelet-bootstrap \
--token=${BOOTSTRAP_TOKEN} \
--kubeconfig=${K8S_HOME}/etc/kubelet-bootstrap.kubeconfig

kubectl config set-context default \
--cluster=kubernetes \
--user=kubelet-bootstrap \
--kubeconfig=${K8S_HOME}/etc/kubelet-bootstrap.kubeconfig

kubectl config use-context default --kubeconfig=${K8S_HOME}/etc/kubelet-bootstrap.kubeconfig
}

# make kube-controller-manager kubeconfig
make_kube_controller_manager_kubeconfig() {
kubectl config set-cluster kubernetes \
--certificate-authority=${K8S_HOME}/pki/kube-ca.pem \
--embed-certs=true \
--server=${KUBE_APISERVER} \
--kubeconfig=${K8S_HOME}/etc/kube-controller-manager.kubeconfig

kubectl config set-credentials kube-controller-manager \
--client-certificate=${K8S_HOME}/pki/kube-controller-manager.pem \
--client-key=${K8S_HOME}/pki/kube-controller-manager-key.pem \
--embed-certs=true \
--kubeconfig=${K8S_HOME}/etc/kube-controller-manager.kubeconfig

kubectl config set-context default \
--cluster=kubernetes \
--user=kube-controller-manager \
--kubeconfig=${K8S_HOME}/etc/kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=${K8S_HOME}/etc/kube-controller-manager.kubeconfig
}

# make kube-scheduler kubeconfig
make_kube_scheduler_kubeconfig() {
kubectl config set-cluster kubernetes \
--certificate-authority=${K8S_HOME}/pki/kube-ca.pem \
--embed-certs=true \
--server=${KUBE_APISERVER} \
--kubeconfig=${K8S_HOME}/etc/kube-scheduler.kubeconfig

kubectl config set-credentials kube-scheduler \
--client-certificate=${K8S_HOME}/pki/kube-scheduler.pem \
--client-key=${K8S_HOME}/pki/kube-scheduler-key.pem \
--embed-certs=true \
--kubeconfig=${K8S_HOME}/etc/kube-scheduler.kubeconfig

kubectl config set-context default --kubeconfig=${K8S_HOME}/etc/kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=${K8S_HOME}/etc/kube-scheduler.kubeconfig
}

# make kube-proxy kubeconfig
make_kube_proxy_kubeconfig() {
kubectl config set-cluster kubernetes \
--certificate-authority=${K8S_HOME}/pki/kube-ca.pem \
--embed-certs=true \
--server=${KUBE_APISERVER} \
--kubeconfig=${K8S_HOME}/etc/kube-proxy.kubeconfig

kubectl config set-credentials kube-proxy \
--client-certificate=${K8S_HOME}/etc/kube-proxy.pem \
--client-key=${K8S_HOME}/etc/kube-proxy-key.pem \
--embed-certs=true \
--kubeconfig=${K8S_HOME}/etc/kube-proxy.kubeconfig

kubectl config set-context default \
--cluster=kubernetes \
--user=kube-proxy \
--kubeconfig=${K8S_HOME}/etc/kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=${K8S_HOME}/etc/kube-proxy.kubeconfig
}

# make admin kubeconfig
make_admin_kubeconfig() {
kubectl config set-cluster kubernetes \
--certificate-authority=${K8S_HOME}/pki/kube-ca.pem \
--embed-certs=true \
--server=${KUBE_APISERVER} \
--kubeconfig=${K8S_HOME}/etc/admin.kubeconfig

kubectl config set-credentials admin \
--client-certificate=${K8S_HOME}/etc/admin.pem \
--client-key=${K8S_HOME}/etc/admin-key.pem \
--embed-certs=true \
--kubeconfig=${K8S_HOME}/etc/admin.kubeconfig

kubectl config set-context default \
--cluster=kubernetes \
--user=admin \
--kubeconfig=${K8S_HOME}/etc/admin.kubeconfig

kubectl config use-context default --kubeconfig=${K8S_HOME}/etc/admin.kubeconfig
}
# make sa.pub sa.key
make_sa() {
openssl genrsa -out ${K8S_HOME}/pki/sa.key 2048
openssl rsa -in ${K8S_HOME}/pki/sa.key -pubout -out ${K8S_HOME}/pki/sa.pub
}

exec_main() {
  make_bootstrap_kubeconfig
  make_kube_controller_manager_kubeconfig
  make_kube_scheduler_kubeconfig
  make_kube_proxy_kubeconfig
  make_admin_kubeconfig
  make_sa
}