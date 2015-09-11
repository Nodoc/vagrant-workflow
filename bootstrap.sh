#!/bin/bash

#Bombs out on any error
set +e

#Shows you each command and the result
set +x

# update and dist-upgrade to latest for all packages
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confnew" \
--force-yes -fuyq dist-upgrade

# install redis-server and start it
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' redis-server | grep "install ok installed")
echo Checking for redis-server: $PKG_OK
if [ "" == "$PKG_OK" ]; then
    echo "No redis-server. Installing redis-server."
    apt-get -y -q install redis-server
fi
unset PKG_OK
REDIS_RUN=$(service redis-server status)
echo Checking if redis-server is running: $REDIS_RUN
if [ "redis-server is running" != "$REDIS_RUN" ]; then
    service redis-server start
fi

# configure hostname to firstname.lastname
HOSTNAME=$(hostname)
echo Checking if hostname is set: $HOSTNAME
if [ "blake-klynsma" != "$HOSTNAME" ]; then
    echo Setting new hostname ...
    sed -i -e 's/127.0.0.1 localhost/127.0.0.1 blake-klynsma/g' /etc/hosts
    echo 'blake-klynsma' > /etc/hostname
    hostname blake-klynsma
    echo Hostname set.
fi

# set domain name to hack.local
DOM_NM=$(hostname -f | grep 'hack.local')
echo Check if domain name is set: $DOM_NM
if [ "" == "$DOM_NM" ]; then
    sed -i -e 's/127.0.0.1 blake-klynsma/127.0.0.1 hack.local blake-klynsma/g' /etc/hosts
    echo Hostname set: $(hostname -f)
fi

# add 3 users, larry, moe, and curly -- disabled passwords for interactive login
# larry is a system account, and should have a shell of /bin/false
declare -a new_users=("larry" "moe" "curly")
for i in "${new_users[@]}"
do
    if id -u $i > /dev/null 2>&1; then
        echo Checking if $i exists: $(id -u $i)
    else
        echo Checking if $i exists: no such user
        if [ "larry" == "$i" ]; then
            adduser --system --shell /bin/false --disabled-password --no-create-home "$i"
        else
            useradd -m -s /bin/bash $i
        fi
    fi
done
unset i

# moe is a sysadmin and should be able to sudo without a password
if [ ! -f /etc/sudoers.d/moe ]; then
    echo "moe ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/moe
    chmod 0440 /etc/sudoers.d/moe
fi    
echo Checking sudo config for moe: $(cat /etc/sudoers.d/moe)

# install nginx and make it serve up the default web site
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' nginx | grep "install ok installed")
echo Checking for nginx: $PKG_OK
if [ "" == "$PKG_OK" ]; then
    echo "No nginx found. Installing nginx."
    apt-get -y -q install nginx
fi
update-rc.d nginx defaults
echo Checking nginx: $(curl hack.local 2>&1| grep successfully)
unset PKG_OK

# set vim as the default editor for the system
if [ ! -f /etc/profile.d/editor.sh ]; then
    echo "export EDITOR=/usr/bin/vim" > /etc/profile.d/editor.sh
    chmod 744 /etc/profile.d/editor.sh
fi
echo Checking default editor: $EDITOR

# add the PPA for WebUpd8 team, and install the oracle version of java8
if [ ! -f /etc/apt/sources.list.d/webupd8team-java-trusty.list ]; then
    add-apt-repository -y ppa:webupd8team/java
    apt-get update
fi
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' oracle-java8-installer | grep "install ok installed")
echo Checking for oracle-java8-installer: $PKG_OK
if [ "" == "$PKG_OK" ]; then
    echo "No oracle-java8-installer found. Installing oracle-java8-installer."
    echo oracle-java8-installer shared/accepted-oracle-license-v1-1 boolean true | debconf-set-selections
    apt-get -y -q install oracle-java8-installer
fi
unset PKG_OK

#install ntpd in a client mode
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' ntp | grep "install ok installed")
echo Checking for ntp: $PKG_OK
if [ "" == "$PKG_OK" ]; then
    echo "No ntp found. Installing ntp." 
    apt-get -y -q install ntp
fi
unset PKG_OK

#install dnsmasq as a dns cache client, make sure it respects the hosts file
#configure the system to use the dns cache
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' dnsmasq | grep "install ok installed")
echo Checking for dnsmasq: $PKG_OK
if [ "" == "$PKG_OK" ]; then
    echo "No dnsmasq found. Installing dnsmasq." 
    apt-get -y -q install dnsmasq
    sed -i -e "s/#listen-address=/listen-address=127.0.0.1/g" /etc/dnsmasq.conf
    sed -i -e "s/#prepend domain-name-servers 127.0.0.1;/prepend domain-name-servers 127.0.0.1;/g" /etc/dhcp/dhclient.conf
    service dnsmasq restart
fi
unset PKG_OK

#add 3 entries to the hosts file
declare -a new_hosts=("127.0.1.1 ironman" "127.0.1.2 hawkeye" "127.0.1.3 hulk") 
for i in "${new_hosts[@]}"
do
    HOST_FND=$(cat /etc/hosts | grep "$i")
    if [ "" == "$HOST_FND" ]; then
        echo $i >> /etc/hosts
    fi
    unset HOST_FND
done
unset i

#make sure dns is configured with a default search domain of hack.local
DEF_DOM=$(cat /etc/resolvconf/resolv.conf.d/base | grep "hack.local")
if [ "" == "$DEF_DOM" ]; then
    echo "search hack.local" >> /etc/resolvconf/resolv.conf.d/base
    resolvconf -u
fi

#install mysql server with a root password of "qqq111"
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' mysql-server | grep "install ok installed")
if [ "" == "$PKG_OK" ]; then
    echo "No mysql-server found. Installing mysql-server."
    echo mysql-server-5.5 mysql-server/root_password password qqq111 | debconf-set-selections
    echo mysql-server-5.5 mysql-server/root_password_again password qqq111 | debconf-set-selections
    apt-get -y -q install mysql-server
fi
unset PKG_OK

#install ufw with a default deny policy, allowing port 22/TCP from anywhere
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' ufw | grep "install ok installed")
if [ "" == "$PKG_OK" ]; then
    echo "No ufw found. Installing ufw."
    apt-get install -y -q install ufw
fi
unset PKG_OK
yes | ufw reset
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
yes | ufw enable

#set the system timezone to UTC
ln -sf /usr/share/zoneinfo/UTC /etc/localtime

#write a list of the installed packages on the system to /root/inventory file permissions 644
apt --installed list > /root/inventory
chmod 644 /root/inventory

#create a cron job for the root user that runs the command "touch /root/hi" every minute
CRON_UP=$(cat /etc/crontab | grep "/root/hi")
if [ "" == "$CRON_UP" ]; then
    echo "* * * * * root touch /root/hi" >> /etc/crontab
fi

#install the following packages
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' unison | grep "install ok installed")
if [ "" == "$PKG_OK" ]; then
    apt-get -y -q install unison curl git git-core unzip tmux htop libsensors4 sysstat
fi
unset PKG_OK

#Create a 1GB sparse ext3 formatted block file and mount it via fstab to /mnt/VOL1, should mount on boot
MNT_OK=$(mount | grep /root/vol1.img)
if [ "" == "$MNT_OK" ]; then
    truncate -s 1G /root/vol1.img
    yes | mkfs.ext3 -q /root/vol1.img
    mkdir /mnt/VOL1
    echo "/root/vol1.img    /mnt/VOL1   ext3    loop,defaults   0 0" >> /etc/fstab
    mount -a
fi
unset MNT_OK

#Create 3 1GB sparse block files, format them as physical volumes, add all to volume group named "vg-awesome"
#and create a logical valume using all space in group named "lv-awesomer", format as ext4, mounted on /mnt/VOL2 via fstab
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' lvm2 | grep "install ok installed")
if [ "" == "$PKG_OK" ]; then
    apt-get -y -q install lvm2
fi
unset PKG_OK
if [ ! -f /root/pv1.img ] || [ ! -f /root/pv2.img ] || [ ! -f /root/pv3.img ]; then
    for f in {1..3}; do
        truncate -s 1G /root/pv$f.img
        LOOP=$(losetup --find --show /root/pv$f.img)
        pvcreate $LOOP
    done
    vgcreate vg-awesome $(losetup -a | grep pv | awk '{ print $1 }' | sed 's/://g' | paste -s -d ' ')
    lvcreate -l 100%FREE vg-awesome -n lv-awesomer
    mkfs.ext4 /dev/mapper/vg--awesome-lv--awesomer
    if [ ! -d /mnt/VOL2 ]; then
        mkdir /mnt/VOL2
    fi
    echo "/dev/mapper/vg--awesome-lv--awesomer  /mnt/VOL2    ext4    loop,defaults   0 0" >> /etc/fstab
    mount -a
fi

#Create 2 1GB sparse block files, create a Linux software raid device, mirrored over the files at md0.
#Raid device should be mounted automatically at /mnt/VOL3
PKG_OK=$(dpkg-query -W --showformat='${Status}\n' mdadm | grep "install ok installed")
if [ "" == "$PKG_OK" ]; then
    echo "mdadm mdadm/mail_to string root" | debconf-set-selections
    echo "mdadm mdadm/start_daemon boolean true" | debconf-set-selections
    echo "mdadm mdadm/autocheck boolean true" | debconf-set-selections
    apt-get -y -q install mdadm
fi
unset PKG_OK
if [ ! -f /root/raid1.img ] || [ ! -f /root/raid2.img ]; then
    for f in {1..2}; do
        truncate -s 1G /root/raid$f.img
        losetup --find --show /root/raid$f.img
    done
    RAID_LOOPS=$(losetup -a | grep raid | awk '{ print $1 }' | sed 's/://g' | paste -s -d ' ')
    mdadm --create /dev/md0 --level=1 --metadata=1.2 --chunk=64 --raid-devices=2 $RAID_LOOPS
    mdadm --detail --scan --verbose > /etc/mdadm/mdadm.conf
    mkfs.ext4 /dev/md0
    mkdir /mnt/VOL3
    echo "/dev/md0  /mnt/VOL3   ext4    defaults    1 2" >> /etc/fstab
    mount -a
fi

#set "nofile" system limit (ulimit) to unlimited for the root user
NOFILE=$(cat /etc/security/limits.conf | grep "nofile -1")
if [ "" == "$NOFILE" ]; then
    echo "root soft nofile -1" >> /etc/security/limits.conf
    echo "root hard nofile -1" >> /etc/security/limits.conf
fi

touch /root/test
