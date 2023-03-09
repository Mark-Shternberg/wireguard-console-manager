#!/bin/bash
colGreen="\033[32m"
colRed="\033[31m"
colYellow="\033[43m"
resetCol="\033[0m"
server_port=$(grep -w 'ListenPort =' /etc/wireguard/wg0.conf | tr -d 'ListenPort = ')
network=$(cat /etc/wireguard/wg0.conf | grep -oE '\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b' | cut -d. --complement -f 4 | tail -n 1)

#adding tmp for find free ip in wireguard network
echo -e "$(cat /etc/wireguard/wg0.conf | grep -oE '\b[0-9]{1,3}(\.[0-9]{1,3}){3}\b')" \
> /etc/wireguard/script/tmp
net_lines_count=$(wc -l /etc/wireguard/script/tmp | tr -d '/etc/wireguard/script/tmp')

echo -n "Type comment for peer: "
read comment
echo -e "Generating keys...\n" 
umask 077; wg genkey | tee privatekey | wg pubkey > publickey
if [ $? -eq 0 ]
then
  echo -e "$colGreen [Done] $resetCol"
  publicKey=$(cat /etc/wireguard/script/publickey)
  privateKey=$(cat /etc/wireguard/script/privatekey)
  serverpublicKey=$(cat /etc/wireguard/publickey)
else
  echo -e "$colRed Error! $resetCol"
  exit 0
fi

if [[ -f "/etc/wireguard/script/server_ip" ]]; then 
        server_IP=$(cat /etc/wireguard/script/server_ip)
else
        server_IP=$(hostname  -I | cut -f1 -d' ')
fi

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

echo -e "Adding peer...\n" 
#finding free ip
IP=0
for ((i=2;i<=254;++i))
do
        k=0
        for ((j=1;j<=$net_lines_count;++j))
        do
                string=$(cat /etc/wireguard/script/tmp | head -n$j | tail -n1)
                if [[ $network.$i == $string ]]; then
                        break
                elif [[ $network.$i != $string ]]; then
                        (( k++ ))
                fi
        done
        if [[ $k -eq $net_lines_count ]]; then
                IP=$i
                break 2
        fi
done
if [[ $IP -eq 0 ]]; then 
        echo -e "$colRed There is no free IP in wireguard network! Exiting ..$resetCol"
        exit 0 
fi
echo -e "\n#$comment\n[Peer]\nAllowedIPs = $network.$IP/32\nPublicKey = $publicKey" >> /etc/wireguard/wg0.conf

while true; do
        echo -ne "Use this IP for client config? - $server_IP [Y/N]: "
        read accept

        case $accept in
                [yY] ) break;;
                [nN] ) echo -n "Enter valid server IP: "
                        k=0
                        while [ $k -lt 3 ]; do
                                read server_IP
                                if valid_ip $server_IP; then
                                        echo -e "$server_IP" > /etc/wireguard/script/server_ip
                                        echo -e "$colGreen \t[Saved] $resetCol"
                                        break
                                else
                                        (( k++ ))
                                        echo -e "Address incorrect! $k/3"
                                        if [[ $k -eq 3 ]]; then echo "Exiting, address incorrect."; exit 0; fi
                                fi
                        done
                        ;;
                * ) echo -e " $colRed Type only Y or N !$resetCol";;
        esac
done

echo -en "Creating config...\n" 
if [[ -d /etc/wireguard/script/conf ]]; then
        touch /etc/wireguard/script/conf/conf_$comment
else
        mkdir /etc/wireguard/script/conf
        touch /etc/wireguard/script/conf/conf_$comment
fi
echo -e "[Interface]\nPrivateKey = $privateKey \nAddress = $network.$IP/32\nDNS = 1.1.1.1 \n\n\
[Peer] \nPublicKey = $serverpublicKey \nAllowedIPs = 0.0.0.0/0 \nEndpoint = $server_IP:$server_port \nPersistentKeepalive = 25"\
> /etc/wireguard/script/conf/conf_$comment
if [ $? -eq 0 ]
then
  echo -e "$colGreen [Done] $resetCol"
else
  echo -e "$colRed Error! $resetCol"
  exit 0 
fi

echo -e "$colYellow -------------------------Here client config-------------------------\n $resetCol"
echo -e "[Interface]\nPrivateKey = $privateKey \nAddress = $network.$IP/32\nDNS = 1.1.1.1 \n\n\
[Peer] \nPublicKey = $serverpublicKey \nAllowedIPs = 0.0.0.0/0 \nEndpoint = $server_IP:$server_port \nPersistentKeepalive = 25"
echo "\n--------------------------------------------------------------------"
echo "$(cat /etc/wireguard/script/conf/conf_$comment)" | qr

sleep 2s

echo -n "Restarting wireguard ..."

systemctl restart wg-quick@wg0
if [ $? -eq 0 ]
then
  echo -e "$colGreen [Done] $resetCol"
else
  echo -e "$colRed Error! $resetCol"
fi
