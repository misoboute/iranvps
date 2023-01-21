#!/usr/bin/bash

set -ex

script_dir=$(realpath $(dirname $BASH_SOURCE[0]))
htuser=${1:-$USER}

sudo apt update
sudo apt upgrade
sudo apt install squid apache2-utils --assume-yes

systemctl status squid.service

mkdir -p ~/backup
cp /etc/squid/squid.conf ~/backup/

sudo htpasswd -c /etc/squid/passwords $htuser

squid_cfg_file=${TMPDIR:-/tmp}/squid-irish-ips-proxy-auth-access.conf

awk '{ print "acl", "irish_ips", "src", $1 }' irish-ip-range.txt > $squid_cfg_file
cat << EOF

http_access allow irish_ips

auth_param basic program /usr/lib/squid3/basic_ncsa_auth /etc/squid/passwords
auth_param basic realm proxy

acl authenticated proxy_auth REQUIRED

http_access allow authenticated
EOF >> $squid_cfg_file

sudo cp $squid_cfg_file /etc/squid/conf.d/

sudo systemctl restart squid.service

sudo cp ~/sshd-no-pw-no-root.conf /etc/ssh/sshd_config.d/

for ip_range in $(cat --squeeze-blank ${script_dir}/irish-ip-range.txt ${script_dir}/iran-ip-range.txt)
do
    sudo ufw allow from ${ip_range} app OpenSSH
done

for ip_range in $(cat --squeeze-blank ${script_dir}/irish-ip-range.txt)
do
    sudo ufw allow from ${ip_range} app Squid
done

sudo ufw enable
