#/bin/bash

# Red Hat Labs
# Sets up a local repo server of RHEL 7.8 and 7.9
# RUN: chmod +x yumrepo_server.sh && ./yumrepo_server.sh

if ! rpm -q httpd > /dev/null
then
    echo "httpd service not found. You need to install and configure it before running this script."
    exit 1
fi
if [ ! -d "/var/www/html/" ]; then
    echo "The httpd document root /var/www/html/ does not exist.  Reconfigure your httpd service and try again."
    exit 1
fi

repoFolder="/mnt/RHEL7/u9/RedHatEnterpriseLinuxServer/x86_64"
mkdir -p $repoFolder
mkdir -p /var/www/html/RHEL7/u9/RedHatEnterpriseLinuxServer/x86_64/
mount -o loop /data/rhel-server-7.9-x86_64-dvd.iso $repoFolder
shopt -s dotglob
echo "Copying files from $repoFolder/ to /var/www/html/RHEL7/u9/RedHatEnterpriseLinuxServer/x86_64/"
cp -R $repoFolder/* /var/www/html/RHEL7/u9/RedHatEnterpriseLinuxServer/x86_64/
chmod a+rx -R /var/www/html/RHEL7/u9/RedHatEnterpriseLinuxServer/x86_64/
umount $repoFolder


repoFolder="/mnt/RHEL7/u8/RedHatEnterpriseLinuxServer/x86_64"
mkdir -p $repoFolder
mkdir -p /var/www/html/RHEL7/u8/RedHatEnterpriseLinuxServer/x86_64/
mount -o loop /data/rhel-server-7.9-x86_64-dvd.iso $repoFolder
shopt -s dotglob
echo "Copying files from $repoFolder/ to /var/www/html/RHEL7/u8/RedHatEnterpriseLinuxServer/x86_64/"
cp -R $repoFolder/* /var/www/html/RHEL7/u8/RedHatEnterpriseLinuxServer/x86_64/
chmod a+rx -R /var/www/html/RHEL7/u8/RedHatEnterpriseLinuxServer/x86_64/
umount $repoFolder


# Start Service
if ! service httpd status > /dev/null
then
    service httpd start
fi

# SELinux
chcon -R -t httpd_sys_content_t /var/www/html/RHEL7/u9/RedHatEnterpriseLinuxServer/x86_64/

chcon -R -t httpd_sys_content_t /var/www/html/RHEL7/u8/RedHatEnterpriseLinuxServer/x86_64/

