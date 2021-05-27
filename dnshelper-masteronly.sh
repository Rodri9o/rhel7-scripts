#!/bin/bash

# Server version: Red Hat Enterprise Linux 7
# DNS type: Authoritative DNS server with one Master node
# Using Multi-view: false
# Using default firewall: true

# Run: chmod +x dnshelper-masteronly.sh && ./dnshelper-masteronly.sh

# NOTE: In this configuration, any remote server can query this DNS server.
# Take additional security measures using a network FW or restrict further using OS FW.
# See port FW rules at end of script.

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

        listen-on port 53 { any; };
        listen-on-v6 port 53 { any; };
        directory       "/var/named";
        dump-file       "/var/named/data/cache_dump.db";
        statistics-file "/var/named/data/named_stats.txt";
        memstatistics-file "/var/named/data/named_mem_stats.txt";
        allow-query     { any; };
        allow-query-cache { any; };
        recursion no;
        allow-transfer  { none; };
};
logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};




zone "." IN {
        type hint;
        file "named.ca";
};

zone "example1.com" IN {
        type master;
        file "named.example1.com";
};

zone "example2.com" IN {
        type master;
        file "named.example2.com";
};

EOF
chown root:named $configFile

configFile=$prefix/var/named/named.ca
if [ ! -s $configFile ]; then
cat > $configFile <<EOF
; <<>> DiG 9.9.4-P2-RedHat-9.9.4-12.P2 <<>> +norec NS . @a.root-servers.net
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 26229
;; flags: qr aa; QUERY: 1, ANSWER: 13, AUTHORITY: 0, ADDITIONAL: 24

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 1472
;; QUESTION SECTION:
;.              IN  NS

;; ANSWER SECTION:
.           518400  IN  NS  a.root-servers.net.
.           518400  IN  NS  b.root-servers.net.
.           518400  IN  NS  c.root-servers.net.
.           518400  IN  NS  d.root-servers.net.
.           518400  IN  NS  e.root-servers.net.
.           518400  IN  NS  f.root-servers.net.
.           518400  IN  NS  g.root-servers.net.
.           518400  IN  NS  h.root-servers.net.
.           518400  IN  NS  i.root-servers.net.
.           518400  IN  NS  j.root-servers.net.
.           518400  IN  NS  k.root-servers.net.
.           518400  IN  NS  l.root-servers.net.
.           518400  IN  NS  m.root-servers.net.

;; ADDITIONAL SECTION:
a.root-servers.net. 518400  IN  A   198.41.0.4
b.root-servers.net. 518400  IN  A   192.228.79.201
c.root-servers.net. 518400  IN  A   192.33.4.12
d.root-servers.net. 518400  IN  A   199.7.91.13
e.root-servers.net. 518400  IN  A   192.203.230.10
f.root-servers.net. 518400  IN  A   192.5.5.241
g.root-servers.net. 518400  IN  A   192.112.36.4
h.root-servers.net. 518400  IN  A   128.63.2.53
i.root-servers.net. 518400  IN  A   192.36.148.17
j.root-servers.net. 518400  IN  A   192.58.128.30
k.root-servers.net. 518400  IN  A   193.0.14.129
l.root-servers.net. 518400  IN  A   199.7.83.42
m.root-servers.net. 518400  IN  A   202.12.27.33
a.root-servers.net. 518400  IN  AAAA    2001:503:ba3e::2:30
c.root-servers.net. 518400  IN  AAAA    2001:500:2::c
d.root-servers.net. 518400  IN  AAAA    2001:500:2d::d
f.root-servers.net. 518400  IN  AAAA    2001:500:2f::f
h.root-servers.net. 518400  IN  AAAA    2001:500:1::803f:235
i.root-servers.net. 518400  IN  AAAA    2001:7fe::53
j.root-servers.net. 518400  IN  AAAA    2001:503:c27::2:30
k.root-servers.net. 518400  IN  AAAA    2001:7fd::1
l.root-servers.net. 518400  IN  AAAA    2001:500:3::42
m.root-servers.net. 518400  IN  AAAA    2001:dc3::35

;; Query time: 58 msec
;; SERVER: 198.41.0.4#53(198.41.0.4)
;; WHEN: Wed Apr 23 14:52:37 CEST 2014
;; MSG SIZE  rcvd: 727
EOF
chown root:named $configFile
fi


configFile=$prefix/var/named/named.example1.com
configFileBackup=$configFile.backup.${currentTimestamp}
if [ -f $configFile ]; then
    echo backup $configFile $configFileBackup
    cp $configFile $configFileBackup
fi
echo "Write RR to $configFile"
cat > $configFile <<EOF
\$TTL    600
@   IN SOA  master.example1.com. admin.email.example1.com. (
                     2021052600   ; serial
                     1800  ; refresh
                     1800  ; retry
                     604800  ; expire
                     86400 )    ; minimum

@ IN NS master.example1.com.

master.example1.com. IN A 10.162.34.10

EOF
chown root:named $configFile

configFile=$prefix/var/named/named.example2.com
configFileBackup=$configFile.backup.${currentTimestamp}
if [ -f $configFile ]; then
    echo backup $configFile $configFileBackup
    cp $configFile $configFileBackup
fi
echo "Write RR to $configFile"
cat > $configFile <<EOF
\$TTL    600
@   IN SOA  master.example2.com. admin.email.example2.com. (
                     2021052600   ; serial
                     1800  ; refresh
                     1800  ; retry
                     604800  ; expire
                     86400 )    ; minimum

@ IN NS master.example2.com.

master.example2.com. IN A 10.162.34.10

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




systemctl status firewalld
if [ $? == 0 ]; then
  firewall-cmd --permanent --add-port=53/udp
  firewall-cmd --permanent --add-port=53/tcp
  firewall-cmd --reload
fi
