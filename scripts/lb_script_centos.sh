#!/bin/bash -ex

if [ $(hostname) = "LVS01" ]; then export priority="101"; else export priority="100"; fi

cat << EOF > /etc/hosts
127.0.0.1 localhost
10.0.10.204 LVS01
10.0.10.205 LVS02
EOF

cat >> "/etc/sysctl.conf" <<END
net.ipv4.ip_forward = 1
net.ipv4.ip_nonlocal_bind = 1
END

sysctl -p

yum install haproxy keepalived -y

echo "###### Configure keepalived #####"
sleep 3
cp /etc/keepalived/keepalived.conf /etc/keepalived/keepalived.conf_org

cat > "/etc/keepalived/keepalived.conf" <<END
vrrp_script chk_haproxy {
        script "killall -0 haproxy"
        interval 2
        weight 2
}
vrrp_instance VI_1 {
        virtual_router_id 51
        advert_int 1
        priority $priority
        state MASTER
        interface ens160
        virtual_ipaddress {
                10.0.10.200
        }
        track_script {
                chk_haproxy
        }
}
END



systemctl enable keepalived
systemctl restart keepalived
echo "###### Configure haproxy #####"
sleep 3


cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg_org

cat > "/etc/haproxy/haproxy.cfg" <<END
global
  chroot  /var/lib/haproxy
  daemon
  group  haproxy
  maxconn  4000
  pidfile  /var/run/haproxy.pid
  stats socket /var/lib/haproxy/stats
  user  haproxy

defaults
  log  global
  mode  tcp
  maxconn  4000
  option  redispatch
  retries  3
  timeout  http-request 10s
  timeout  queue 1m
  timeout  connect 10s
  timeout  client 1m
  timeout  server 1m
  timeout  check 10s

listen dashboard *:80
  balance  source
  option  tcpka
  option  httpchk
  option  tcplog
  server CTL01 10.0.10.201:80 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:80 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:80 check inter 2000 rise 2 fall 5

listen galera_cluster *:3306
  balance  source
  mode   tcp
  option tcpka
  server CTL01 10.0.10.201:3306 check
  server CTL02 10.0.10.202:3306 backup check
  server CTL03 10.0.10.203:3306 backup check

listen glance_api *:9292
  balance  source
  option  tcpka
  option  httpchk
  option  tcplog
  server CTL01 10.0.10.201:9292 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:9292 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:9292 check inter 2000 rise 2 fall 5

listen glance_registry *:9191
  balance  source
  option  tcpka
  option  tcplog
  server CTL01 10.0.10.201:9191 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:9191 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:9191 check inter 2000 rise 2 fall 5

listen keystone_admin *:35357
  balance  source
  option  tcpka
  option  httpchk
  option  tcplog
  server CTL01 10.0.10.201:35357 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:35357 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:35357 check inter 2000 rise 2 fall 5

listen keystone_public *:5000
  balance  source
  option  tcpka
  option  httpchk
  option  tcplog
  server CTL01 10.0.10.201:5000 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:5000 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:5000 check inter 2000 rise 2 fall 5

listen nova_compute_api *:8774
  balance  source
  option  tcpka
  option  httpchk
  option  tcplog
  server CTL01 10.0.10.201:8774 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:8774 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:8774 check inter 2000 rise 2 fall 5

listen nova_metadata_api *:8775
  balance  source
  option  tcpka
  option  tcplog
  server CTL01 10.0.10.201:8775 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:8775 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:8775 check inter 2000 rise 2 fall 5

listen cinder_api *:8776
  balance  source
  option  tcpka
  option  httpchk
  option  tcplog
  server CTL01 10.0.10.201:8776 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:8776 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:8776 check inter 2000 rise 2 fall 5

listen ceilometer_api *:8777
  balance  source
  option  tcpka
  option  tcplog
  server CTL01 10.0.10.201:8777 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:8777 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:8777 check inter 2000 rise 2 fall 5

listen nova_vncproxy *:6080
  balance  source
  option  tcpka
  option  tcplog
  server CTL01 10.0.10.201:6080 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:6080 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:6080 check inter 2000 rise 2 fall 5

listen neutron_api *:9696
  balance  source
  option  tcpka
  option  httpchk
  option  tcplog
  server CTL01 10.0.10.201:9696 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:9696 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:9696 check inter 2000 rise 2 fall 5

listen swift_proxy *:8080
  balance  source
  option  tcplog
  option  tcpka
  server CTL01 10.0.10.201:8080 check inter 2000 rise 2 fall 5
  server CTL02 10.0.10.202:8080 check inter 2000 rise 2 fall 5
  server CTL03 10.0.10.203:8080 check inter 2000 rise 2 fall 5

listen rabbitmq *:5672
    balance  source
    option clitcpka
    timeout client 900m
    server CTL01 10.0.10.201:5672 check inter 1s
    server CTL02 10.0.10.202:5672 check inter 1s
    server CTL03 10.0.10.203:5672 check inter 1s

listen stats *:1936
        mode http
        stats enable
        stats uri /stats
        stats realm HAProxy\ Statistics
        stats auth admin:admin@123456

END

systemctl enable haproxy
systemctl restart haproxy