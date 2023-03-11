#!/bin/bash
colGreen="\033[32m"
colRed="\033[31m"
colYellow="\033[43m"
resetCol="\033[0m"

echo -e "Exsisting peers: \n"

echo "$(cat /etc/wireguard/wg0.conf)" | grep -Fn '#' | tr '#' ' '

k=0
while [ $k -lt 3 ]
do
        echo -n "Type NUMBER of peer to look: "
        read line
        if cat /etc/wireguard/wg0.conf | head -n $line | tail -n 1 | grep '[#]'; then
                break
        else 
                (( k++ ))
                echo -e "$colRed Number is incorrect! $k/3 $resetCol"
        fi
        if [[ $k -eq 3 ]]; then echo "$colRed Exiting... $resetCol"; exit 0; fi   
done
comment=$(head -n $line /etc/wireguard/wg0.conf | tail -n 1 | tr -d '#')

while true; do
        echo -e "You need config with comment $comment? [Yes/No]: "
        read accept

        case $accept in
        [yY] ) echo -e "$colYellow -------------------------Here $comment config-------------------------\n $resetCol"
                echo "$(cat /etc/wireguard/script/conf/conf_$comment)"
                echo "\n--------------------------------------------------------------------\n"
                echo "$(cat /etc/wireguard/script/conf/conf_$comment)" | qr
                ;;
        [nN] ) echo "Exiting..."; exit 0;;
        * ) echo -e " $colRed Type only Y or N !$resetCol";;
        esac
done
