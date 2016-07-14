#!/bin/bash -ex
#
source config_centos.cfg

LOCAL_IP=`ifconfig ens160 | grep 'inet' | cut -d: -f2 | awk '{print $2}'`

echo "##### Install keystone #####"

yum -y install openstack-keystone openstack-utils python-openstackclient httpd mod_wsgi memcached python-memcache

# Start memcache
systemctl enable memcached
systemctl start memcached

#/* Back-up file keystone.conf
cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.org

#Config file /etc/keystone/keystone.conf
cat > "/etc/keystone/keystone.conf" <<END

[DEFAULT]
log_dir = /var/log/keystone

admin_token = $TOKEN_PASS
bind_host = $VIP_IP
public_bind_host = $VIP_IP
admin_bind_host = $VIP_IP

[assignment]
[auth]
[cache]
[catalog]
driver = keystone.catalog.backends.sql.Catalog
[cors]
[cors.subdomain]
[credential]
[database]
connection = mysql://keystone:$KEYSTONE_DBPASS@$VIP_IP/keystone

[domain_config]
[endpoint_filter]
[endpoint_policy]
[eventlet_server]
[eventlet_server_ssl]
[federation]
[fernet_tokens]
[identity]
driver = keystone.identity.backends.sql.Identity
[identity_mapping]
[kvs]
[ldap]
[matchmaker_redis]
[matchmaker_ring]
[memcache]
servers = localhost:11211

[oauth1]
[os_inherit]
[oslo_messaging_amqp]
[oslo_messaging_qpid]
[oslo_messaging_rabbit]
[oslo_middleware]
[oslo_policy]
[paste_deploy]
[policy]
[resource]
[revoke]
driver = sql

[role]
[saml]
[signing]
[ssl]
[token]
provider = uuid
driver = sql

[tokenless_auth]
[trust]
[extra_headers]
Distribution = Ubuntu

END

echo "ServerName $LOCAL_IP" >> /etc/httpd/httpd.conf

cat > "/etc/httpd/conf.d/wsgi-keystone.conf" <<END

Listen 5000
Listen 35357

<VirtualHost *:5000>
    WSGIDaemonProcess keystone-public processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-public
    WSGIScriptAlias / /usr/bin/keystone-wsgi-public
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined

    <Directory /usr/bin>
       Require all granted
    </Directory>
</VirtualHost>

<VirtualHost *:35357>
    WSGIDaemonProcess keystone-admin processes=5 threads=1 user=keystone group=keystone display-name=%{GROUP}
    WSGIProcessGroup keystone-admin
    WSGIScriptAlias / /usr/bin/keystone-wsgi-admin
    WSGIApplicationGroup %{GLOBAL}
    WSGIPassAuthorization On
    ErrorLogFormat "%{cu}t %M"
    ErrorLog /var/log/httpd/keystone-error.log
    CustomLog /var/log/httpd/keystone-access.log combined

    <Directory /usr/bin>
        Require all granted
    </Directory>
</VirtualHost>

END


systemctl enable httpd.service
systemctl start httpd.service

rm -f /var/lib/keystone/keystone.db


# Tao bien moi truong

cd
echo "export OS_PROJECT_DOMAIN_ID=default" > admin-openrc.sh
echo "export OS_USER_DOMAIN_ID=default" >> admin-openrc.sh
echo "export OS_PROJECT_NAME=admin" >> admin-openrc.sh
echo "export OS_TENANT_NAME=admin" >> admin-openrc.sh
echo "export OS_USERNAME=admin" >> admin-openrc.sh
echo "export OS_PASSWORD=$ADMIN_PASS" >> admin-openrc.sh
echo "export OS_AUTH_URL=http://$VIP_IP:35357/v3" >> admin-openrc.sh
echo "export OS_IDENTITY_API_VERSION=3" >> admin-openrc.sh

sleep 5
echo "########## Execute environment script ##########"
chmod +x admin-openrc.sh
cat admin-openrc.sh >> /etc/profile
source admin-openrc.sh

echo "export OS_PROJECT_DOMAIN_ID=default" > demo-openrc.sh
echo "export OS_USER_DOMAIN_ID=default" >> demo-openrc.sh
echo "export OS_PROJECT_NAME=demo" >> demo-openrc.sh
echo "export OS_TENANT_NAME=demo" >> demo-openrc.sh
echo "export OS_USERNAME=demo" >> demo-openrc.sh
echo "export OS_PASSWORD=$ADMIN_PASS"  >> demo-openrc.sh
echo "export OS_AUTH_URL=http://$VIP_IP:35357/v3" >> demo-openrc.sh
echo "export OS_IDENTITY_API_VERSION=3" >> demo-openrc.sh

chmod +x demo-openrc.sh


echo "#### Verify operation #####"
openstack --os-auth-url http://CTL:35357/v3 \
  --os-project-domain-id default --os-user-domain-id default \
  --os-project-name admin --os-username admin --os-auth-type password \
  token issue

openstack --os-auth-url http://CTL:5000/v3 \
  --os-project-domain-id default --os-user-domain-id default \
  --os-project-name demo --os-username demo --os-auth-type password \
  token issue
