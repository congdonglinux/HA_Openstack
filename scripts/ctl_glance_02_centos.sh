#!/bin/bash -ex
#
source config_centos.cfg

echo "########## Install GLANCE ##########"
yum -y install openstack-glance python-glance python-glanceclient

echo "########## Configuring GLANCE API ##########"
sleep 5
#/* Back-up file glance-api.conf
cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf_org

#Configuring glance config file /etc/glance/glance-api.conf

cat > "/etc/glance/glance-api.conf" <<END
[DEFAULT]
notification_driver = noop
verbose = True

[database]
connection = mysql://glance:$GLANCE_DBPASS@$VIP_IP/glance
backend = sqlalchemy

[glance_store]
default_store = file
filesystem_store_datadir = /var/lib/glance/images/

[image_format]
[keystone_authtoken]
auth_uri = http://$VIP_IP:5000
auth_url = http://$VIP_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = glance
password = $GLANCE_PASS

[matchmaker_redis]
[matchmaker_ring]
[oslo_concurrency]
[oslo_messaging_amqp]
[oslo_messaging_qpid]
[oslo_messaging_rabbit]
[oslo_policy]
[paste_deploy]
flavor = keystone

[store_type_location_strategy]
[task]
[taskflow_executor]
END

chmod 640 /etc/glance/glance-api.conf 
chown glance:glance /etc/glance/glance-api.conf

sleep 5 

echo "########## Configuring GLANCE REGISTER ##########"
#/* Backup file file glance-registry.conf
cp /etc/glance/glance-registry.conf /etc/glance/glance-registry.conf_org

#Config file /etc/glance/glance-registry.conf
cat > "/etc/glance/glance-registry.conf" <<END
[DEFAULT]
notification_driver = noop
verbose = True

[database]
connection = mysql://glance:$GLANCE_DBPASS@$VIP_IP/glance
backend = sqlalchemy

[glance_store]

[keystone_authtoken]
auth_uri = http://$VIP_IP:5000
auth_url = http://$VIP_IP:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = glance
password = $GLANCE_PASS

[matchmaker_redis]
[matchmaker_ring]
[oslo_messaging_amqp]
[oslo_messaging_qpid]
[oslo_messaging_rabbit]
[oslo_policy]

[paste_deploy]
flavor = keystone
END

chmod 640 /etc/glance/glance-registry.conf
chown glance:glance /etc/glance/glance-registry.conf

echo "########## Restarting GLANCE service ... ##########"
systemctl start openstack-glance-api openstack-glance-registry 
systemctl enable openstack-glance-api openstack-glance-registry 

#
echo "export OS_IMAGE_API_VERSION=2" \
  | tee -a ~/admin-openrc.sh ~/demo-openrc.sh

echo "Remove glance.sqlite "
rm -f /var/lib/glance/glance.sqlite

