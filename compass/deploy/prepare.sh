function prepare_env() {
    export PYTHONPATH=/usr/lib/python2.7/dist-packages:/usr/local/lib/python2.7/dist-packages
    sudo apt-get update -y
    sudo apt-get install mkisofs
    sudo apt-get install git python-pip python-dev -y
    sudo apt-get install libxslt-dev libxml2-dev libvirt-dev build-essential qemu-utils qemu-kvm libvirt-bin virtinst libmysqld-dev -y
    sudo pip install --upgrade ansible virtualenv
    sudo service libvirt-bin restart
   
    # prepare work dir
    rm -rf $WORK_DIR
    mkdir -p $WORK_DIR
    mkdir -p $WORK_DIR/installer
    mkdir -p $WORK_DIR/vm
    mkdir -p $WORK_DIR/network
    mkdir -p $WORK_DIR/iso

    # clone compass
    git clone https://github.com/baigk/compass-core.git $WORK_DIR/installer/compass-core
    git clone https://github.com/baigk/compass-install.git $WORK_DIR/installer/compass-install
    virtualenv $WORK_DIR/installer/compass-core/venv
    
    if [[ ! -f centos.iso ]];then
        wget -O $WORK_DIR/iso/centos.iso http://192.168.123.11:9999/xh/work/build/work/compass.iso
    fi
}
