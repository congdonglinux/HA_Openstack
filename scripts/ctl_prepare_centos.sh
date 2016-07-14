#!/bin/bash -ex

echo "### Configure hosts file ###"
cat << EOF > /etc/hosts
127.0.0.1 localhost
10.0.10.200 CTL
10.0.10.201 CTL01
10.0.10.202 CTL02
10.0.10.203 CTL03
10.0.10.204 LVS01
10.0.10.205 LVS02
10.0.10.206 COM01
EOF

echo "#### Update for CentOS7 #####"
#yum -y install centos-release-openstack-mitaka
yum -y install centos-release-openstack-liberty
yum -y update
sleep 3

echo "Install python client"
yum -y install python-openstackclient
yum -y install openstack-selinux
sleep 5

echo "Install and config NTP"
sleep 3
yum -y install chrony
mv /etc/chrony.conf /etc/chrony.conf_bk
cat > "/etc/chrony.conf" <<END
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


echo "Reboot Server"

#sleep 5
init 6

