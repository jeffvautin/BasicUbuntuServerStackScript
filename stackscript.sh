#!/bin/bash 
##
# <UDF name="HOSTNAME" Label="Hostname" example="examplehost" />
# <UDF name="ssuser" Label="New user" example="username" />
# <UDF name="sspassword" Label="New user password" example="pencil69" />
# <UDF name="sskey" Label="New User SSH Key" example="ssh-rsa AAA…" />
# <UDF name="ssip" Label="IP to whitelist for SSH" />
# <UDF name="tz" label="Time Zone" default="America/New_York" example="Example: America/New_York (see: http://bit.ly/TZlisting)" />

#source <ssinclude StackScriptID=1>

# Update OS
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y

# Enable automatic security updates (https://help.ubuntu.com/lts/serverguide/automatic-updates.html)
apt-get install unattended-upgrades
echo "APT::Periodic::Update-Package-Lists \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades
echo "APT::Periodic::Download-Upgradeable-Packages \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades
echo "APT::Periodic::AutocleanInterval \"7\";" >> /etc/apt/apt.conf.d/20auto-upgrades
echo "APT::Periodic::Unattended-Upgrade \"1\";" >> /etc/apt/apt.conf.d/20auto-upgrades

# Set the Hostname
hostnamectl set-hostname $HOSTNAME
# while not using a fully-qualified domain name, need to update hosts as well (https://www.linode.com/docs/networking/dns/using-your-systems-hosts-file/):
sed -z -i "s/127.0.1.1	ubuntu.members.linode.com	ubuntu\|$/127.0.1.1	$HOSTNAME/" /etc/hosts


# Set timezone
if [ -n $TZ ]
then
    timedatectl set-timezone $TZ
fi

# add sudo user
adduser $SSUSER --disabled-password --gecos "" && \
echo "$SSUSER:$SSPASSWORD" | chpasswd
adduser $SSUSER sudo

# add ssh key
mkdir -p /home/$SSUSER/.ssh
echo "$SSKEY" >> /home/$SSUSER/.ssh/authorized_keys
chmod -R 700 /home/$SSUSER/.ssh/
chown -R $SSUSER:$SSUSER /home/$SSUSER/.ssh/

# disable root login & password auth
sed -z -i 's/PermitRootLogin yes\|$/PermitRootLogin no/' /etc/ssh/sshd_config
sed -z -i 's/PasswordAuthentication yes\|$/PasswordAuthentication no/' /etc/ssh/sshd_config
echo 'AddressFamily inet' | sudo tee -a /etc/ssh/sshd_config # listen only on IP4
systemctl restart sshd

# enable fail2ban for ssh https://www.linode.com/docs/security/using-fail2ban-for-security/
apt-get install fail2ban -y
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
if [ -n $SSIP ]
then
    sed -z -i "s/ignoreip = 127.0.0.1\/8\|$/ignoreip = 127.0.0.1\/8 $SSIP/" /etc/fail2ban/jail.local
fi

# turn on the firewall
ufw allow ssh
ufw enable