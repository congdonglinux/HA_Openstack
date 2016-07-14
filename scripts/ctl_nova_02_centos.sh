#!/bin/bash -ex
#
source config_centos.cfg


LOCAL_IP=`ifconfig ens160 | grep 'inet' | cut -d: -f2 | awk '{print $2}'`

echo "########## Install NOVA in $VIP_IP ##########"
yum -y install openstack-nova-api openstack-nova-cert openstack-nova-conductor openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler python-novaclient

sleep 5
# Cai tu dong libguestfs-tools
yum -y install libguestfs-tools sysfsutils guestfsd python-guestfs

######## Backup configurations for NOVA ##########"
sleep 7
cp /etc/nova/nova.conf /etc/nova/nova.conf_org

## Config nova
cat > "/etc/nova/nova.conf" <<END
[DEFAULT]

rpc_backend = rabbit
auth_strategy = keystone

dhcpbridge_flagfile=/etc/nova/nova.conf
dhcpbridge=/usr/bin/nova-dhcpbridge
logdir=/var/log/nova
state_path=/var/lib/nova
lock_path=/var/lock/nova
force_dhcp_release=True
libvirt_use_virtio_for_bridges=True
ec2_private_dns_show_ip=True
api_paste_config=/etc/nova/api-paste.ini
enabled_apis=ec2,osapi_compute,metadata

my_ip = $LOCAL_IP

network_api_class = nova.network.neutronv2.api.API
security_group_api = neutron
linuxnet_interface_driver = nova.network.linux_net.NeutronLinuxBridgeInterfaceDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver

enabled_apis=osapi_compute,metadata
verbose = True

enable_instance_password = True

[database]
connection = mysql://nova:$NOVA_DBPASS@$VIP_IP/nova

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
password = $NOVA_PASS

[vnc]
vncserver_listen = $my_ip
vncserver_proxyclient_address = $my_ip

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

service_metadata_proxy = True
metadata_proxy_shared_secret = $METADATA_SECRET

END



echo "########## Start NOVA ... ##########"

systemctl enable openstack-nova-api openstack-nova-cert openstack-nova-consoleauth openstack-nova-scheduler openstack-nova-conductor openstack-nova-novncproxy
systemctl start openstack-nova-api openstack-nova-cert openstack-nova-consoleauth openstack-nova-scheduler openstack-nova-conductor openstack-nova-novncproxy

echo "########## Testing NOVA service ##########"
nova-manage service list
