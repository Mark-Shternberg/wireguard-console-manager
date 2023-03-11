#!/bin/bash
colGreen="\033[32m"
colRed="\033[31m"
resetCol="\033[0m"

current_version=$(cat /etc/issue)
if ! [[ "$current_version" == *"Ubuntu 22.04"* ]] && ! [[ "$current_version" != *"Ubuntu 20.04"* ]]; then echo -e " $colRed Your version of OS doesn't supported by this script !$resetCol"; exit 0; fi

while true; do
    echo -n "Will be installed: wireguard, iptables-persistent, python3-qrcode. Ok? [Yy/Nn]: "
    read accept
    case $accept in
        [yY] ) break;;
        [nN] ) echo "Exiting..."; exit 0;;
        * ) echo -e " $colRed Type only Y or N !$resetCol";;
    esac
done

mkdir /etc/wireguard/script
mkdir /etc/wireguard/script/conf
mv $PWD/script /etc/wireguard/script

apt-get -qqq update
apt-get -qqq install wireguard iptables-persistent python3-qrcode -y

cd /etc/wireguard
umask 077; wg genkey | tee privatekey | wg pubkey > publickey
publicKey=$(cat /etc/wireguard/publickey)
privateKey=$(cat /etc/wireguard/privatekey)

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

k=0
while [ $k -lt 3 ]
do
echo -n "Enter network (e.g. 10.8.0.0): "
read network
if valid_ip $network; then
    network=$(echo $network | cut -d. --complement -f 4)
    k=0
    break
    else
    (( k++ ))
    echo -e "Network incorrect! $k/3"
    if [[ k -eq 3 ]]; then echo -e "$colGreen Exiting, network incorrect.$resetCol"; exit 0; fi
fi
done

while [ $k -lt 3 ]
do
echo -n "Enter port for wireguard (49152—65535): "
read port
if [[ $port -lt 49152 ]]; then
    (( k++ ))
    echo "Port is less than 49152! $k/3"
    elif [[ $port -gt 65535 ]]; then
        (( k++ ))
        echo "Port is over than 65535! $k/3"
        elif [[ $port =~ '^[0-9]+$' ]]; then
        (( k++ ))
        echo "Enter correct number! $k/3"
            else
                break
fi
    if [[ $k -eq 3 ]]; then echo -e "$colGreen Exiting, port incorrect.$resetCol"; exit 0; fi
done

echo -n "Writing interface..."
echo -e "[Interface]\nAddress = $network.0/24\nListenPort = $port\nPrivateKey = $privateKey" > /etc/wireguard/wg0.conf
if [ $? -eq 0 ]
then
  echo -e "$colGreen [Done] $resetCol"
else
  echo -e "$colRed Error! $resetCol"
fi

echo "Starting wireguard..."
systemctl start wg-quick@wg0
if [ $? -eq 0 ]
then
  echo -e "$colGreen [Done] $resetCol"
else
  echo -e "$colRed Error! Look for errors after install and restart wireguard! $resetCol"
fi
systemctl enable wg-quick@wg0

chmod +x /etc/wireguard/script/add_peer.sh
chmod +x /etc/wireguard/script/delete_peer.sh
chmod +x /etc/wireguard/script/look_conf.sh

echo -e "cd /etc/wireguard/script/\n./add_peer.sh" > /usr/local/bin/add-peer
chmod +x /usr/local/bin/add-peer
echo -e "cd /etc/wireguard/script/\n./delete_peer.sh" > /usr/local/bin/delete-peer
chmod +x /usr/local/bin/delete-peer
echo -e "cd /etc/wireguard/script/\n./look_conf.sh" > /usr/local/bin/look-conf
chmod +x /usr/local/bin/look-conf

echo "Adding firewall rule..."
iptables -t nat -A POSTROUTING -s $network.0/24 -o eth0 -j MASQUERADE

echo -e "net.ipv4.ip_forward = 1" > /etc/sysctl.d/70-wireguard-routing.conf
sysctl -p /etc/sysctl.d/70-wireguard-routing.conf -w
if [ $? -eq 0 ]
then
  echo -e "$colGreen [Done] $resetCol"
else
  echo -e "$colRed Error! $resetCol"
fi

service netfilter-persistent save

echo -e "$colGreen \tGreat! Wireguard installed! $resetCol"
echo -e "\033[33m \tNow you can type new commands:\033[0m\n\tAdd peer: \t\tadd-peer\n\tDelete peer: \t\tdelete-peer\n\tLook config of peer: \tlook-conf"
