#!/bin/bash

#felipesi
#script para criar uma rede virtual entre duas VMs em um mesmo host, permitindo a comunicação entre elas.
#testado utilizando a imagem ubuntu server 18.04 do amazon ec2

sudo apt update
sudo apt install sshpass qemu -y

wget http://download.cirros-cloud.net/0.5.1/cirros-0.5.1-x86_64-disk.img -O cirros.img
cp cirros.img vm1.img
cp cirros.img vm2.img

#cria uma bridge uma br0
sudo ip link add br0 type bridge

#cria duas interfaces TAP (tap1 e tap2)
sudo ip tuntap add tap1 mode tap user ubuntu
sudo ip tuntap add tap2 mode tap user ubuntu

#coloca a bridge como master das interfaces TAP
sudo ip link set tap1 master br0
sudo ip link set tap2 master br0

#instancia as duas VMs
qemu-system-x86_64 -device e1000,netdev=user0 -netdev user,id=user0,hostfwd=tcp::2221-:22 -device e1000,netdev=net0,mac=00:00:00:00:00:01 -netdev tap,id=net0,ifname=tap1,script=no,downscript=no -m 256 -drive file=vm1.img,media=disk,cache=writeback -vnc :1 -daemonize
qemu-system-x86_64 -device e1000,netdev=user0 -netdev user,id=user0,hostfwd=tcp::2222-:22 -device e1000,netdev=net0,mac=00:00:00:00:00:02 -netdev tap,id=net0,ifname=tap2,script=no,downscript=no -m 256 -drive file=vm2.img,media=disk,cache=writeback -vnc :2 -daemonize

#aguarda ssh das VMs ser liberado
while true;do
    sshpass -p 'gocubsgo' ssh -oStrictHostKeyChecking=no cirros@localhost -p 2222 "echo" && break
    sleep 1
done

#atribui o ip 192.168.0.1 a VM1 e 192.168.0.2 a VM2, na interface eth1
sshpass -p 'gocubsgo' ssh -oStrictHostKeyChecking=no cirros@localhost -p 2221 "sudo ip addr add 192.168.0.1/24 dev eth1"
sshpass -p 'gocubsgo' ssh -oStrictHostKeyChecking=no cirros@localhost -p 2222 "sudo ip addr add 192.168.0.2/24 dev eth1"

#Habilita a interface eth1 nas duas VMs
sshpass -p 'gocubsgo' ssh -oStrictHostKeyChecking=no cirros@localhost -p 2221 "sudo ip link set eth1 up"
sshpass -p 'gocubsgo' ssh -oStrictHostKeyChecking=no cirros@localhost -p 2222 "sudo ip link set eth1 up"

#Habilita as interfaces TAP e bridge
sudo ip link set tap1 up
sudo ip link set tap2 up
sudo ip link set br0 up

#testa a comunicação entre as VMs
clear
sshpass -p 'gocubsgo' ssh -oStrictHostKeyChecking=no cirros@localhost -p 2221 "ip addr ls eth1 | grep global | awk '{print \"VM 1: \"\$2}' && ping -c5 192.168.0.2 | grep from"
echo
sshpass -p 'gocubsgo' ssh -oStrictHostKeyChecking=no cirros@localhost -p 2222 "ip addr ls eth1 | grep global | awk '{print \"VM 2: \"\$2}' && ping -c5 192.168.0.1 | grep from"
