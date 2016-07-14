#!/bin/bash -ex

source config_centos.cfg

###################
echo "########## START INSTALLING OPS DASHBOARD ##########"
###################
sleep 5

echo "########## Installing Dashboard package ##########"
yum -y install openstack-dashboard

## Backup file
cp /etc/openstack-dashboard/local_settings /etc/openstack-dashboard/local_settings_org

## Config OpenStack Dashboard
sed -i "s/ALLOWED_HOSTS = ['horizon.example.com', 'localhost']/ALLOWED_HOSTS = ['*', ]/g" \
	/etc/openstack-dashboard/local_settings

echo "########## Creating redirect page ##########"
cat > "/var/www/html/index.html" << END

<html>
<head>
<META HTTP-EQUIV="Refresh" Content="0.5; URL=http://$VIP_IP/dashboard">
</head>
<body>
<center> <h1>Dang chuyen den Dashboard cua OpenStack</h1> </center>
</body>
</html>
END

## /* Restarting httpd and memcached

systemctl enable httpd.service memcached.service
systemctl restart httpd.service memcached.service

echo "########## Finish setting up Horizon ##########"

echo "########## LOGIN INFORMATION IN HORIZON ##########"
echo "URL: http://$VIP_IP/dashboard"
echo "User: admin or demo"
echo "Password:" $ADMIN_PASS




