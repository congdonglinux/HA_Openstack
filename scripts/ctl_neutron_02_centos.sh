#!/bin/bash -ex
#

source config_centos.cfg


LOCAL_IP=`ifconfig ens160 | grep 'inet' | cut -d: -f2 | awk '{print $2}'`

echo "########## Install NEUTRON in $VIP_IP or NETWORK node ############"
sleep 5
yum -y install openstack-neutron openstack-neutron-ml2 openstack-neutron-linuxbridge python-neutronclient ebtables ipset

######## Backup configuration NEUTRON.CONF in $VIP_IP################"
echo "########## Config NEUTRON in $VIP_IP/NETWORK node ##########"
sleep 7
cp /etc/neutron/neutron.conf /etc/neutron/neutron.conf_org

cat > "/etc/neutron/neutron.conf" <<END

[DEFAULT]
core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True
rpc_backend = rabbit

auth_strategy = keystone

notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
nova_url = http://$VIP_IP:8774/v2

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
password = $NEUTRON_PASS

[database]
connection = mysql://neutron:$NEUTRON_DBPASS@$VIP_IP/neutron

[nova]
auth_url = http://$VIP_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
region_name = RegionOne
project_name = service
username = nova
password = $NOVA_PASS

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


######## Backup configuration of ML2 in $VIP_IP##################"
echo "########## Configuring ML2 in $VIP_IP/NETWORK node ##########"
sleep 7
cp /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugins/ml2/ml2_conf.ini_org

cat > "/etc/neutron/plugins/ml2/ml2_conf.ini" <<END
[ml2]
tenant_network_types = vxlan
type_drivers = flat,vlan,vxlan
mechanism_drivers = linuxbridge,l2population
extension_drivers = port_security

[ml2_type_flat]
flat_networks = external

[ml2_type_vlan]

[ml2_type_gre]
[ml2_type_vxlan]
vni_ranges = 1:1000

[ml2_type_geneve]
[securitygroup]
enable_ipset = True
END



echo "############ Configuring Linux Bbridge AGENT ############"
sleep 7

cp /etc/neutron/plugins/ml2/linuxbridge_agent.ini /etc/neutron/plugins/ml2/linuxbridge_agent.ini_org

cat > "/etc/neutron/plugins/ml2/linuxbridge_agent.ini" <<END
[linux_bridge]
physical_interface_mappings = external:ens192

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

echo "############ Configuring L3 AGENT ############"
sleep 7

cp /etc/neutron/l3_agent.ini /etc/neutron/l3_agent.ini_org

cat > "/etc/neutron/l3_agent.ini" <<END
[DEFAULT]
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
external_network_bridge =
verbose = True

[AGENT]
END


echo "############ Configuring DHCP AGENT ############ "
sleep 7

cp /etc/neutron/dhcp_agent.ini /etc/neutron/dhcp_agent.ini_org

cat > "/etc/neutron/dhcp_agent.ini" <<END
[DEFAULT]
interface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
enable_isolated_metadata = True

verbose = True
dnsmasq_config_file = /etc/neutron/dnsmasq-neutron.conf

[AGENT]

END

#echo "Fix loi MTU"
#sleep 3
#echo "dhcp-option-force=26,1450" > /etc/neutron/dnsmasq-neutron.conf
#killall dnsmasq

echo "############ Configuring METADATA AGENT ############"
sleep 7

cp /etc/neutron/metadata_agent.ini /etc/neutron/metadata_agent.ini_org

cat > "/etc/neutron/metadata_agent.ini" <<END
[DEFAULT]
verbose = True

auth_uri = http://$VIP_IP:5000
auth_url = http://$VIP_IP:35357
auth_region = regionOne
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $NEUTRON_PASS

nova_metadata_ip = $VIP_IP

metadata_proxy_shared_secret = $METADATA_SECRET

END

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
    --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

echo "########## Restarting NOVA service ##########"
sleep 7

systemctl restart openstack-nova-api

echo "########## Restarting NEUTRON service ##########"
sleep 7

systemctl enable neutron-server neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent
systemctl start neutron-server neutron-linuxbridge-agent neutron-dhcp-agent neutron-metadata-agent
systemctl enable neutron-l3-agent
systemctl start neutron-l3-agent

echo "##### Verify operation ######"
neutron agent-list


