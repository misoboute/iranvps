#!/usr/bin/bash

set -ex

script_dir=$(realpath $(dirname $BASH_SOURCE[0]))
htuser=${1:-$USER}

# Update sofware and install new ones
sudo -S apt update
sudo -S apt upgrade --assume-yes
sudo -S apt install squid apache2-utils --assume-yes

# Stop the proxy service until all configuration is done
sudo -S systemctl stop squid.service

# Create the new user using htpasswd if it doesn't exist
htuser_file=/etc/squid/passwords
htuser_exists=$(grep "^$htuser" /etc/passwd | cut -d: -f1)
if [[ -z "$htuser_exists" ]]; then
    sudo -S htpasswd -c $htuser_file $htuser
fi

# Create squid custom config file to allow only Irish IP addresses and only connections authenticated using basic authentication:
squid_cfg_file=${TMPDIR:-/tmp}/squid-irish-ips-proxy-auth-access.conf
awk '{ print "acl", "irish_ips", "src", $1 }' $script_dir/irish-ip-range.txt > $squid_cfg_file
cat >> $squid_cfg_file << EOF

http_access allow irish_ips

auth_param basic program /usr/lib/squid/basic_ncsa_auth $htuser_file
auth_param basic realm proxy

acl authenticated proxy_auth REQUIRED

http_access allow authenticated
EOF

# Copy the custom config file where it will be picked up and read by squid during configuration
sudo -S cp $squid_cfg_file /etc/squid/conf.d/

# Disable SSH logon using password -- SSH public keys must be already added to ~/.ssh/authorized_keys e.g. using ssh-copy-id
sudo -S cp $script_dir/sshd-no-pw.conf /etc/ssh/sshd_config.d/

# TODO: Directly use iptables instead of ufw
# Only allow Irish and Iranian IP addresses to connect to ssh
for ip_range in $(cat --squeeze-blank ${script_dir}/irish-ip-range-cidr.txt ${script_dir}/iran-ip-range-cidr.txt)
do
    sudo -S ufw allow from ${ip_range} app OpenSSH
done

# Only allow Irish IP addresses to connect to Squid
for ip_range in $(cat --squeeze-blank ${script_dir}/irish-ip-range-cidr.txt)
do
    sudo -S ufw allow from ${ip_range} app Squid
done

# Show time!
sudo -S ufw enable
sudo -S systemctl start squid.service
sudo reboot
