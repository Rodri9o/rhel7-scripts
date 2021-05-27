#!/bin/bash

# Script for client side NFS v4.x configuration on RHEL 7


#### IMPORTANT

# This script only configures file /etc/fstab, and it won't mount NFS server 
# automatically, you need to mount it manully given by the comment in the script.

#### NOTES

## NFS Server Hostname or IP
# Replace NFS Server IP 10.10.10.1 with yours

## NFS Server Directory Export
# Replace /export_data with yours
# Can be an array - ie: ('/export' '/export2')

## NFS Client Mountpoint Path
# Replace /data with yours

## NFS V4 Domain Name
# This value needs to be identical on the NFS Server and NFS Clients. 
# Check with the NFS Server administrator, if unsure or unknown, leave blank. 
# If left blank, the NFSv4 domain name will default to the DNS domain name.

## Customize Mountpoint Options 
# Note: The recommended default options have been pre-selected for you. 
# Please proceed with caution. 
# For more detailed information on NFS Client mount options, refer 'man nfs'.

package_query() {
    if rpm -q $1 >/dev/null; then
        echo "Package $1 currently installed, proceeding."
    else
        read -p "Package $1 is not installed, would you like to install it? (y/n) " choice
        while :
        do
            case "$choice" in
                y|Y) yum -y install "$1"; break;;
                n|N) echo "ERROR: Package $1 required to continue, exiting..."; exit 1;;
                * ) read -p "Please enter 'y' or 'n': " choice;;
            esac
        done
    fi
    if ! rpm -q $1 >/dev/null; then
        echo "Package $1 failed to install, exiting..."; exit 1
    fi
}

replaceInFile() {
    local search=$1
    local replace=$2
    local replaceFile=$3
    if [[ $(grep -e "${search}" $replaceFile) == "" ]]; then
      echo 1;
    else
      sed -i "s/${search}/${replace}/g" $replaceFile
      echo 0
    fi
}

updateDomainInIdmapdconf(){
    local domain=$1
    if [[ $domain == "" ]]; then
        return 1;
    fi

    local idmapdFile="/etc/idmapd.conf"
    cp $idmapdFile ${idmapdFile}.orginal-"$(date +%Y%m%d%H%M%S)"
    if [[ $(replaceInFile "^Domain=.*$" "Domain=${domain}" $idmapdFile) == 1 ]]; then
        if [[ $(replaceInFile "^#\s*Domain\s*=\s*.*$" "&\nDomain=${domain}" $idmapdFile) == 1 ]]; then
             if [[ $(replaceInFile "^\[General\]$" "&\nDomain=${domain}" $idmapdFile) == 1 ]]; then
                 echo "Domain=${domain}">>$idmapdFile
             fi
        fi
    fi
}

mount_array=('/data') # array of local mount targets
options_array=('defaults') # array of mount options for local mounts
remote_array=('10.10.10.1:/export_data') # array of remote address:/export targets
nfs_vers=nfs4
nfsv4_domain="redhat.com"

for mountpoint in "${mount_array[@]}"; do
    if grep -q "$mountpoint" /etc/fstab ; then
        echo "ERROR: Mount already configured in fstab, exiting to ensure none of your configurations are altered"; exit 1
    fi
done

for mountpoint in "${mount_array[@]}"; do
    if [[ ! -d "$mountpoint" ]]; then
        read -p "Local mountpoint $mountpoint not found. Would you like to create it? (y/n) " choice
        while :
        do
            case "$choice" in
                y|Y ) mkdir -p "$mountpoint" ; break;;
                n|N ) echo "ERROR: Mountpoint $mountpoint must exist to continue, exiting..."; exit 1;;
                * ) read -p "Please enter 'y' or 'n': " choice;;
            esac
        done
    fi
done

package_query nfs-utils
package_query libnfsidmap

if [[ $nfs_vers != 'nfs3' ]]; then
    package_query nfs4-acl-tools
    opts='vers=4,_netdev'
elif [[ $nfs_vers == 'nfs3' ]]; then
    opts='vers=3,_netdev'
else
    opts='_netdev'
fi

# NFS client configuration
cp /etc/fstab /etc/fstab.orginal-"$(date +%Y%m%d%H%M%S)"

for i in $(seq 0 $(( ${#mount_array[@]}-1 ))); do
    cat <<- EOF >>/etc/fstab
${remote_array[i]}     ${mount_array[i]} nfs ${options_array[i]},$opts 0 0
EOF
done

if [[ $nfs_vers != 'nfs3' ]]; then
    updateDomainInIdmapdconf "$nfsv4_domain"
fi

if ! pgrep rpcbind >/dev/null; then
    read -p "rpcbind daemon required to continue, Would you like to start it? (y/n) " choice
    while :
    do
        case "$choice" in
            y|Y ) systemctl start rpcbind; chkconfig rpcbind on; break;;
            n|N ) echo "ERROR: rpcbind daemon not started. Exiting..."; exit 1;;
            * ) read -p "Please enter 'y' or 'n': " choice;;
        esac
    done
fi

echo "The following commands must be executed to make the mount points effective:"
for i in $(seq 0 $(( ${#mount_array[@]}-1 ))); do
    echo "mount ${mount_array[i]}"
done

