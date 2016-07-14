#!/bin/bash -ex
#
source config_centos.cfg

LOCAL_IP=`ifconfig ens160 | grep 'inet' | cut -d: -f2 | awk '{print $2}'`
GAL_IP1=`grep CTL01 /etc/hosts | awk '{print $1}'`
GAL_IP2=`grep CTL02 /etc/hosts | awk '{print $1}'`
GAL_IP3=`grep CTL03 /etc/hosts | awk '{print $1}'`

##############################################
echo "Install and Config MariaDB"
sleep 3

echo "Enabling the repository"
cat > "/etc/yum.repos.d/MariaDB.repo" <<END
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
END

sleep 3
yum -y install rsync nmap lsof perl-DBI nc
yum -y install MariaDB-server MariaDB-client galera socat jemalloc MySQL-python rsync
echo "##### Configuring MYSQL #####"
sleep 3

## Start  service
/etc/init.d/mysql start

mysqladmin -u root password "$MYSQL_PASS"

## Xoa cac user trong va database test
mysql -u root -p"$MYSQL_PASS" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost')"
mysql -u root -p"$MYSQL_PASS" -e "DELETE FROM mysql.user WHERE User=''"
mysql -u root -p"$MYSQL_PASS" -e "DROP DATABASE test"
mysql -u root -p"$MYSQL_PASS" -e "GRANT ALL PRIVILEGES ON *.* TO 'cluster'@'%' IDENTIFIED BY 'clusterpw' WITH GRANT OPTION"
mysql -u root -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES"

## Stop MariaDB-Galera-server
/etc/init.d/mysql stop


cp /etc/my.cnf.d/server.cnf /etc/my.cnf.d/server.cnf_org

cat > "/etc/my.cnf.d/server.cnf" <<END
[galera]
datadir=/var/lib/mysql
user=mysql
binlog_format=ROW
default-storage-engine=innodb
innodb_file_per_table
innodb_autoinc_lock_mode=2
innodb_flush_log_at_trx_commit=0
innodb_buffer_pool_size=122M
query_cache_type=0
query_cache_size=0
bind-address=0.0.0.0

# Galera Provider Configuration
wsrep_on=ON
wsrep_provider=/usr/lib64/galera/libgalera_smm.so
wsrep_provider_options="pc.recovery=TRUE;gcache.size=300M"

# Galera Cluster Configuration
wsrep_cluster_name="Galera_cluster"
wsrep_cluster_address="gcomm://$GAL_IP1,$GAL_IP2,$GAL_IP3"

# Galera Synchronization Configuration
wsrep_sst_method=rsync
wsrep_sst_auth=cluster:clusterpw 

# Galera Node Configuration
wsrep_node_address="$LOCAL_IP"
wsrep_node_name="$(hostname)"

END

systemctl stop mysql 
sleep 3
