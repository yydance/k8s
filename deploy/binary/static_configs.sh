#!/bin/bash
# configuration files and dir names
# k8s cluster master includes the components:
#   - kube-apiserver
#   - kube-controller-manager
#   - kube-scheduler
#   - kube-proxy
#   - docker, flannel
#   - keepalived, haproxy
# k8s node includes the components:
#   - kubelet
#   - kube-proxy
#   - docker, flannel
#   - node_exporter
# this config will be modified from time to time

os_version="CentOS.7.6.1810"
kernel_version="4.4.180"
k8s_version="1.14.1"
docker_version="18.09.6"
flannel_version="0.11.0"
etcd_version="3.3.12"
keepalived_version="1.3.5"
haproxy_version="1.5.18"
cfssl_version="1.2.0"

system_service_dir="/usr/lib/systemd/system"

docker_hosts="192.168.0.7
192.168.0.4
192.168.0.5"

flannel_hosts="${docker_hosts}"
etcd_hosts="${docker_hosts}"

k8s_apiserver_hosts="${docker_hosts}"
k8s_controller_manager_hosts="${docker_hosts}"
k8s_node_hosts="${docker_hosts}"
k8s_registy_hosts="${docker_hosts}"

k8s_ingress_hosts="192.168.0.7
192.168.0.4
192.168.0.5"
k8s_apiserver_vip="192.168.0.254"
k8s_ingress_vip="192.168.0.250"
k8s_dashboard_host="192.168.0.7"

k8s_cluster_ip="10.99.0.0/16"
k8s_pod_ip="10.244.0.0/16"
k8s_coredns_ip="10.99.110.110"

certs_tmp_dir="/data/certs"
script_dir="/data/scripts"
app_dir="/data/app"
etcd_dirs="${app_dir}/etcd
${app_dir}/etcd/bin
${app_dir}/etcd/data
${app_dir}/etcd/etc
${app_dir}/etcd/certs"

k8s_dirs="${app_dir}/k8s
${app_dir}/k8s/etc
${app_dir}/k8s/certs
${app_dir}/k8s/log"
