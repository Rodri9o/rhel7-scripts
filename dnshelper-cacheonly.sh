#!/bin/bash

# Source: RHEL Labs
# Server version: Red Hat Enterprise Linux 7
# DNS type: Recursive DNS server for caching
# Using forwarder: true
# Using default firewall: true

# Req: yum install -y bind bind-chroot 
# Run: chmod +x dnshelper-cacheonly.sh && ./dnshelper-cacheonly.sh

# NOTE: In this configuration, any remote server can query this DNS server.
# Take additional security measures using a network FW or restrict further using OS FW.

currentTimestamp=`date +%y-%m-%d-%H:%M:%S`

prefix=""

rpm -q bind bind-chroot
if [ $? -ne 0 ]; then
  echo "You didn't install the bind bind-chroot package, please install it before running this script"
  echo "The command is 'yum install bind bind-chroot -y'"
  exit 1
fi

configFile=$prefix/etc/named.conf
configFileBackup=$configFile.backup.${currentTimestamp}
if [ -f $configFile ]; then
    echo backup $configFile $configFileBackup
    cp $configFile $configFileBackup
fi

echo "Write the configure to bind configuration file $configFile"
cat > $configFile <<EOF
options {
        listen-on port 53  { any; };
        listen-on-v6 port 53 { any; };
        directory          "/var/named";
        dump-file          "/var/named/data/cache_dump.db";
        statistics-file    "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        allow-query        { any; };
        allow-query-cache  { any; };
        recursion yes;

        forward only;
        forwarders {               
                8.8.8.8;     
                8.8.4.4;               
        };

};
logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};
EOF
chown root:named $configFile

echo "Start named service, and set it to run on startup"
systemctl status named-chroot
if [ $? == 0 ]; then
  systemctl restart named-chroot
else
  systemctl start named-chroot
fi
# Check the result of starting/restarting service
if [ $? -ne 0 ]; then
 echo "Can't start named service, make sure you have the right permission and SELinux setting"
 exit 1
fi
systemctl enable named-chroot

## Enable FW rules
systemctl status firewalld
if [ $? == 0 ]; then
  firewall-cmd --permanent --add-port=53/udp
  firewall-cmd --permanent --add-port=53/tcp
  firewall-cmd --reload
else
  echo "Make sure to enable OS FW"
fi
