#!/usr/bin/bash

set -ex

script_dir=$(realpath $(dirname $BASH_SOURCE[0]))
host=$1 # Remote host (server IP address)
user=${2:-$USER} # New user to create on the server
install_prefix=${3:-/home/$user/srvsetup} # Path on the server to install the config script and resources

# Enable logging on as root to the host using public key authentication (we'll disable p/w authentication later)
ssh-copy-id root@$host

# Add the new user (if not there already) and add it to sudo group
ssh root@$host "
user_exists=\$(grep ^$user /etc/passwd | cut -d: -f1)
if [[ -z \"\$user_exists\" ]]; then
    adduser $user --add_extra_groups;
    adduser $user sudo;
fi"

# Enable logging on to the as the new user using public key authentication
ssh-copy-id $user@$host

# Generate CIDR addresses files from the IP range source files for Iran and Ireland IP ranges
if [[ ! -f $script_dir/iran-ip-range-cidr.txt ]]
then
    for ip_range in $(cat --squeeze-blank ${script_dir}/iran-ip-range.txt)
    do
        ipcalc -r $ip_range | tail -n +2 >> iran-ip-range-cidr.txt
    done    
fi

if [[ ! -f $script_dir/irish-ip-range-cidr.txt ]]
then
    for ip_range in $(cat --squeeze-blank ${script_dir}/irish-ip-range.txt)
    do
        ipcalc -r $ip_range | tail -n +2 >> irish-ip-range-cidr.txt
    done    
fi

# Copy config script and resources to the server
ssh $user@$host mkdir -p /home/$user/srvsetup
files_to_copy=(
    $script_dir/iran-ip-range.txt
    $script_dir/iran-ip-range-cidr.txt
    $script_dir/irish-ip-range.txt
    $script_dir/irish-ip-range-cidr.txt
    $script_dir/server-setup.sh
    $script_dir/sshd-no-pw.conf
)
scp ${files_to_copy[@]} scp://$user@$host/$install_prefix/

# Execute the config script on the server
ssh $user@$host bash $install_prefix/server-setup.sh $user
