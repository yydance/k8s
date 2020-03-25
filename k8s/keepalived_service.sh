#!/bin/bash
# install keepalived and make configure

keepalived_service() {
if $(rpm -q keepalived &>/dev/null);then
    echo "keepalived has beend installed"
else
    yum -y install keepalived
fi

cd /etc/keepalived
mv keepalived.conf{,.default}
cat >keepalived.conf <<EOF
! Configuration File for keepalived

global_defs {
   notification_email {
     damon@halfsre.com
   }
   notification_email_from admin@halfsre.com
   smtp_server 127.0.0.1
   smtp_connect_timeout 30
   router_id MASTER_KUBE_APISERVER
   vrrp_mcast_group1 224.0.0.19
}

vrrp_script_check_haproxy {
    script "/data/scripts/check_haproxy.sh"
    interval 2
    weight 2
}

vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 60
    priority 100
    nopreempt
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass damon
    }
    unicast_src_ip 192.168.0.7
    unicast_peer {
    192.168.0.4
    192.168.0.5
    }
    virtual_ipaddress {
        192.168.0.254/24 label eth0
    }
    track_script {
    check_haproxy
    }
}
EOF

cat >/data/scripts/check_haproxy.sh <<EOF
#!/bin/bash
# check haproxy is alive or not
# if not, stop keepalived

flag=\$(systemctl status haproxy &>/dev/null;echo \$?)

if [ \$flag -ne 0 ];then
  echo "haproxy is down,stop the keepalived"
  systemctl stop keepalived
fi
EOF

if $(grep 'Requires=haproxy.service' /usr/lib/systemd/system/keepalived.service &>/dev/null);then
    echo "Nothing will be changed in 'keepalived.service'"
else
    sed -i '/After/a\Requires=haproxy.service' /usr/lib/systemd/system/keepalived.service
    systemctl daemon-reload
fi
systemctl enable keepalived
}
