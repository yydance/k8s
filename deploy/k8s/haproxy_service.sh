#!/bin/bash
# install haproxy and make configure

haproxy_service() {
if $(rpm -q haproxy &>/dev/null);then
    echo "haproxy has been installed"
else
    yum -y install haproxy
fi

cd /etc/haproxy
mv haproxy.cfg{,.default}

cat >haproxy.cfg <<EOF
#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global

    log         127.0.0.1 local2

    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy.pid
    maxconn     4000
    user        haproxy
    group       haproxy
    daemon

    stats socket /var/lib/haproxy/stats

defaults
    mode                    tcp
    log                     global
    option                  tcplog
    option                  dontlognull
    option          http-server-close
    option          abortonclose
    option                  redispatch
    retries                 3
    #timeout http-request    10s
    timeout queue           5m
    timeout connect         10s
    timeout client          5m
    timeout server          5m
    #timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 30000


listen stats
    mode http
    bind *:10086
    stats enable
    stats uri /admin?stats
    stats auth admin:admin
    stats admin if TRUE


frontend k8s_apiserver
    bind *:8443
    mode tcp
    default_backend https_uri

backend https_uri
    balance roundrobin
    server apiserver1_192_168_0_7 192.168.0.7:6443 check inter 2000 fall 2 rise 2 weight 100
    server apiserver2_192_168_0_4 192.168.0.4:6443 check inter 2000 fall 2 rise 2 weight 100
    server apiserver3_192_168_0_5 192.168.0.5:6443 check inter 2000 fall 2 rise 2 weight 100
EOF

systemctl enable haproxy
systemctl start haproxy
}
