#!/usr/bin/bash

set -ex

script_dir=$(realpath $(dirname $BASH_SOURCE[0]))
host=$1
user=${2:-$USER}

ssh-copy-id root@$host

ssh root@$host adduser $user --add_extra_groups
ssh root@$host adduser $user sudo

ssh-copy-id $user@$host

ssh $user@$host mkdir -p /home/$user/srvsetup
files_to_copy=(
    $script_dir/iran-ip-range.txt
    $script_dir/irish-ip-range.txt
    $script_dir/server-setup.sh
    $script_dir/squid-allow-irish-ips.conf
    $script_dir/squid-irish-ips-proxy-auth-access.conf
)
scp ${files_to_copy[@]} scp://$user@$host//home/$user/srvsetup/

ssh $user@$host bash /home/$user/server-setup.sh $user
