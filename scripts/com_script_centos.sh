
#!/bin/bash -ex

source config_centos.cfg


LOCAL_IP=`ifconfig ens160 | grep 'inet' | cut -d: -f2 | awk '{print $2}'`

echo "### Configure hosts file ###"
cat << EOF > /etc/hosts
127.0.0.1 localhost
10.0.10.200 CTL
10.0.10.201 CTL01
10.0.10.202 CTL02
10.0.10.203 CTL03
10.0.10.206 COM01
10.0.10.207 COM02
EOF

echo "#### Update for CentOS7 #####"
#yum -y install centos-release-openstack-mitaka
yum -y install centos-release-openstack-liberty
sleep 3
yum -y update


echo "Install python client"
yum -y install python-openstackclient
sleep 5

echo "Install and config NTP"
yum -y install chrony
mv /etc/chrony.conf /etc/chrony.conf_bk
cat > "/etc/chrony.conf" <<END
server 10.0.10.201 iburst
server 0.vn.pool.ntp.org iburst
server 1.asia.pool.ntp.org iburst
server 2.asia.pool.ntp.org iburst iburst
stratumweight 0
driftfile /var/lib/chrony/drift
rtcsync
makestep 10 3
allow 10.0.0.0/24
bindcmdaddress 127.0.0.1
bindcmdaddress ::1
keyfile /etc/chrony.keys
commandkey 1
generatecommandkey
noclientlog
logchange 0.5
logdir /var/log/chrony

END

systemctl enable chronyd
systemctl start chronyd

sleep 3

echo "##### Installl package for NOVA"

yum -y install openstack-nova-compute 
yum -y install libguestfs-tools sysfsutils guestfsd python-guestfs

#fix loi chen pass tren hypervisor la KVM
#update-guestfs-appliance
#chmod 0644 /boot/vmlinuz*
#usermod -a -G kvm root

echo "############ Configuring in nova.conf ...############"
sleep 5
########
#Sao luu truoc khi sua file nova.conf

cp /etc/nova/nova.conf /etc/nova/nova.conf_org

#Chen noi dung file /etc/nova/nova.conf 
cat > "/etc/nova/nova.conf" <<END
[DEFAULT]
dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
force_dhcp_release=True
libvirt_use_virtio_for_bridges=True
verbose=True
ec2_private_dns_show_ip=True
api_paste_config=/etc/nova/api-paste.ini
enabled_apis=ec2,osapi_compute,metadata

rpc_backend = rabbit
auth_strategy = keystone
my_ip = $LOCAL_IP

network_api_class = nova.network.neutronv2.api.API
security_group_api = neutron
linuxnet_interface_driver = nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver

verbose = True

enable_instance_password = True

[oslo_messaging_rabbit]
rabbit_host = $VIP_IP
rabbit_userid = openstack
rabbit_password = $RABBIT_PASS

[keystone_authtoken]
auth_uri = http://$VIP_IP:5000
auth_url = http://$VIP_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = nova
password = $KEYSTONE_PASS

[vnc]
enabled = True
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = $my_ip
novncproxy_base_url = http://$VIP_IP:6080/vnc_auto.html

[glance]
host = $VIP_IP

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[neutron]
url = http://$VIP_IP:9696
auth_url = http://$VIP_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
region_name = RegionOne
project_name = service
username = neutron
password = $NEUTRON_PASS

[libvirt]
inject_key = True
inject_partition = -1
inject_password = True
END


echo "##### Start nova-compute #####"
sleep 5

systemctl enable libvirtd openstack-nova-compute
systemctl start libvirtd openstack-nova-compute

# Remove default nova db
#rm /var/lib/nova/nova.sqlite

echo "##### Install linuxbridge-agent (neutron) on COMPUTE NODE #####"
sleep 5

yum -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge python-neutronclient ebtables ipset

echo "Config file neutron.conf"
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf_org

cat > "/etc/neutron/neutron.conf" <<END
[DEFAULT]
core_plugin = ml2

rpc_backend = rabbit
auth_strategy = keystone
verbose = True

[matchmaker_redis]
[matchmaker_ring]
[quotas]
[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[keystone_authtoken]
auth_uri = http://$VIP_IP:5000
auth_url = http://$VIP_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $KEYSTONE_PASS

[database]

[nova]
[oslo_concurrency]
lock_path = \$state_path/lock
[oslo_policy]
[oslo_messaging_amqp]
[oslo_messaging_qpid]

[oslo_messaging_rabbit]
rabbit_host = $VIP_IP
rabbit_userid = openstack
rabbit_password = $RABBIT_PASS

[qos]
END


echo "############ Configuring Linux Bbridge AGENT ############"
sleep 7
cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini_org

cat > "/etc/neutron/plugins/ml2/linuxbridge_agent.ini" <<END
[linux_bridge]
physical_interface_mappings = public:ens192

[vxlan]
enable_vxlan = True
local_ip = $LOCAL_IP
l2_population = True

[agent]
prevent_arp_spoofing = True

[securitygroup]
enable_security_group = True
firewall_driver = neutron.agent.linux.iptables_firewall.IptablesFirewallDriver
END



echo "Reset service nova-compute,linuxbridge-agent"
sleep 5
systemctl enable openstack-nova-compute
systemctl restart openstack-nova-compute
systemctl enable neutron-linuxbridge-agent
systemctl restart neutron-linuxbridge-agent
