#!/bin/bash
set -ex
SCRIPT_DIR=`cd ${BASH_SOURCE[0]%/*};pwd`
WORK_DIR=$SCRIPT_DIR/work
sudo rm -rf $WORK_DIR
mkdir -p $WORK_DIR
PACKAGE_URL=http://192.168.127.11:9999/xh/work/package

cd $WORK_DIR

# get base iso
wget -O centos_base.iso $PACKAGE_URL/centos_base.iso

# get ubuntu ppa package
wget -O ubuntu_ppa.tar.gz $PACKAGE_URL/ubuntu_ppa.tar.gz

# get ubuntu iso
wget -O Ubuntu-14.04-x86_64.iso $PACKAGE_URL/Ubuntu-14.04-x86_64.iso

# mount base iso
mkdir -p base
sudo mount -o loop centos_base.iso base
cd base;find .|cpio -pd ../new;cd -
sudo umount base
chmod 755 ./new -R

# main process
mkdir -p new/repos new/compass new/bootstrap new/pip new/guestimg
cp ubuntu_ppa.tar.gz new/repos
cp Ubuntu-14.04-x86_64.iso new/repos
wget -O new/guestimg/cirros-0.3.3-x86_64-disk.img $PACKAGE_URL/cirros-0.3.3-x86_64-disk.img
wget -O new/pip/pexpect-3.3.tar.gz https://pypi.python.org/packages/source/p/pexpect/pexpect-3.3.tar.gz#md5=0de72541d3f1374b795472fed841dce8

cd new/compass
git clone http://192.168.127.11/compass-core.git
git clone http://192.168.127.11/compass-install.git
git clone http://192.168.127.11/compass-adapters.git
git clone http://192.168.127.11/compass-web.git
find . -name ".git" |xargs rm -rf

cd $WORK_DIR
cp -rf $SCRIPT_DIR/ks.cfg new/isolinux/ks.cfg
rm -rf new/.rr_moved
sudo mkisofs -quiet -r -J -R -b isolinux/isolinux.bin  -no-emul-boot -boot-load-size 4 -boot-info-table -hide-rr-moved -x "lost+found:" -o compass.iso new/

# delete tmp file
sudo rm -rf new base ubuntu_ppa.tar.gz centos_base.iso Ubuntu-14.04-x86_64.iso
