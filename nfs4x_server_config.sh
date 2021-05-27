#!/bin/bash

# Script for server side NFSv4 configuration on RHEL 7

# Replace the following 
# - "mydomain.org" with yours
# - tweak sys,krb5,krb5i,krb5p as needed

package_query() {
    if rpm -q $1 >/dev/null; then
        echo "Package $1 is currently installed, proceeding."
    else
        read -p "Package $1 is not installed, would you like to install it? (y/n) " choice
        while :
        do
            case "$choice" in
                y|Y) yum -y install "$1"; break;;
                n|N) echo "Package $1 required to continue, exiting..."; exit 1;;
                * ) read -p "Please enter 'y' or 'n': " choice;;
            esac
        done
    fi
    if ! rpm -q $1 >/dev/null; then
        echo "Package $1 failed to install, exiting..."; exit 1
    fi
}

service_query() {
    read -p "WARN: You need start/restart $1 service for the changes to take effect, would you like to continue? (y/n) " choice
    while :
    do
        case "$choice" in
            y|Y ) systemctl restart $1; systemctl enable $1; break;;
            n|N ) echo "ERROR: Give up to start/restart $1 service. Exiting..."; exit 1;;
            * ) read -p "Please enter 'y' or 'n': " choice;;
    esac
    done
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

updateNfsconf(){
    local optname=$1
    local optvalue=$2
    if [[ $optname == "" || $optvalue == "" ]]; then
        return 1;
    fi

    local nfsConfFile="/etc/sysconfig/nfs"
    rowcount=0
    if [[ $(grep -e "^[[:space:]]*${optname}" $nfsConfFile) == "" ]]; then
        echo -e "RPCMOUNTDOPTS=\"-p ${optvalue}\"">>$nfsConfFile
    else
        cat $nfsConfFile | while read LINE
        do
            rowcount=$(($rowcount + 1))
            if [[ $(echo "${LINE}" | sed -n "/^[[:space:]]*${optname}/p") ]]; then
                sed -i "${rowcount}s/^\s*${optname}\s*=\s*\".*\".*$/${optname}=\"-p ${optvalue}\"/g" $nfsConfFile
                break
            fi
        done
    fi
}


export_array=('/export') # Array of local filesystems to be exported. ie - ('/export' '/export2' etc..)
remote_array=('*(sync,rw,fsid=myexport,sec=sys,krb5,krb5i,krb5p)') # Array of remote client/mount option groupings for a given export
port_array=('32803' '32769' '892' '662') # Array of custom port definitions for NFS/Firewall use
nfs_vers=nfs4
nfsv4_domain="mydomain.org"
new_exports=0
new_nfsconf=0

if [[ ! -f /etc/exports ]]; then
    touch /etc/exports;
    new_exports=1
else
    for mountpoint in "${export_array[@]}"; do
        if  grep -q "$mountpoint" /etc/exports ; then
            echo "ERROR: Export $mountpoint already configured in exports, exiting to ensure none of your configurations are altered"; exit 1
        fi
    done
fi

if [[ ! -f /etc/sysconfig/nfs ]]; then
    touch /etc/sysconfig/nfs;
    new_nfsconf=1
fi

if egrep -q '^[[:space:]]*fs.nfs.nlm_tcpport' /etc/sysctl.conf; then
    echo "ERROR: Custom lockd TCP port already configured in /etc/sysctl.conf, exiting to ensure your configuration is not altered"; exit 1
fi

if egrep -q '^[[:space:]]*fs.nfs.nlm_udpport' /etc/sysctl.conf; then
    echo "ERROR: Custom lockd UDP port already configured in /etc/sysctl.conf, exiting to ensure your configuration is not altered"; exit 1
fi

if [[ $(grep -e '^[[:space:]]*RPCMOUNTDOPTS' /etc/sysconfig/nfs) != "" && $(grep -e '^[[:space:]]*RPCMOUNTDOPTS=""' /etc/sysconfig/nfs) == "" ]]; then
    echo "ERROR: Custom mountd ports already configured in /etc/sysconfig/nfs, exiting to ensure your configuration is not altered"; exit 1
fi

if [[ $(grep -e '^[[:space:]]*STATDARG' /etc/sysconfig/nfs) != "" && $(grep -e '^[[:space:]]*STATDARG=""' /etc/sysconfig/nfs) == "" ]]; then
    echo "ERROR: Custom statd ports already configured in /etc/sysconfig/nfs, exiting to ensure your configuration is not altered"; exit 1
fi

package_query nfs-utils

if ! rpm -ql nfs-utils | grep -q "nfs-config.service"; then
    read -p "WARN: nfs-utils package update required to proceed, is this acceptable? (y/n)" choice
    while :
    do
        case "$choice" in
            y|Y ) yum -y update nfs-utils;;
            n|N ) echo "ERROR: nfs-utils update required to continue, exiting..."; exit 1;;
            * ) read -p "Please enter 'y' or 'n': " choice
        esac
    done
fi

if ! rpm -ql nfs-utils | grep -q "nfs-config.service"; then
    echo "ERROR: nfs-utils update failed, exiting..."; exit 1
fi

package_query libnfsidmap

if [[ $nfs_vers != "nfs3" ]]; then
    package_query nfs4-acl-tools
fi

for mountpoint in "${export_array[@]}"; do
    if [[ ! -d "$mountpoint" ]]; then
        read -p "ERROR: Local export $mountpoint not found. Would you like to create it? (y/n) " choice
        while :
        do
            case "$choice" in
                y|Y ) mkdir -p "$mountpoint" ; break;;
                n|N ) echo "ERROR: Local export $mountpoint required to continue, exiting..."; exit 1;;
                * ) read -p "Please enter 'y' or 'n': " choice;;
            esac
        done
    fi
done

# NFS server configuration
if [[ $new_exports -eq 0 ]]; then
    cp /etc/exports /etc/exports.orginal-"$(date +%Y%m%d%H%M%S)"
fi

for i in $(seq 0 $(( ${#export_array[@]}-1 ))); do
    cat <<- EOF >>/etc/exports
${export_array[i]}   ${remote_array[i]}
EOF
done

if [[ $nfs_vers != "nfs3" ]]; then
    updateDomainInIdmapdconf "$nfsv4_domain"
fi

cat <<- EOF >>/etc/sysctl.conf
#TCP port rpc.lockd should listen on.
fs.nfs.nlm_tcpport=${port_array[0]}
#UDP port rpc.lockd should listen on.
fs.nfs.nlm_udpport=${port_array[1]}
EOF

echo ${port_array[0]} > /proc/sys/fs/nfs/nlm_tcpport
echo ${port_array[1]} > /proc/sys/fs/nfs/nlm_udpport

if [[ $new_nfsconf -eq 0 ]]; then
    cp /etc/sysconfig/nfs /etc/sysconfig/nfs.orginal-"$(date +%Y%m%d%H%M%S)"
fi

updateNfsconf "RPCMOUNTDOPTS" ${port_array[2]}
updateNfsconf "STATDARG" ${port_array[3]}

service_query nfs-config
service_query rpcbind
service_query nfs-server

echo "The following ports must be opened in your firewall to allow NFS mounts, firewall-cmd syntax used as example:"
rpcinfo -p | awk '{if($1 ~ /[[:digit:]]+/){print "firewall-cmd --add-port=" $4 "/" $3}}' | sort | uniq

