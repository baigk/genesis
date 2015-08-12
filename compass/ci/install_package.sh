#!/bin/bash
set -ex

sudo apt-get update
sudo apt-get install reprepro -y

#download packages
sudo apt-get -d install git -y

#make repo
mkdir repo repo/conf
cat <<EOF > repo/conf/distributions
Codename: trusty
Components: main
Architectures: i386 amd64
EOF

reprepro -b repo includedeb trusty /var/cache/apt/archives/*.deb

tar -zcvf /trusty-juno-ppa.tar.gz ./repo

