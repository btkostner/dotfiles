#!/bin/bash

sudo apt remove -fy docker docker-engine docker.io containerd runc

sudo apt install -fy \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   bionic \
   stable"

sudo apt update

sudo apt install -fy docker-ce docker-ce-cli containerd.io

sudo groupadd docker
sudo usermod -aG docker $USER

sudo systemctl enable docker
