function destroy_nets() {
    virsh net-destroy mgmt > /dev/null 2>&1
    virsh net-undefine mgmt > /dev/null 2>&1
    
    virsh net-destroy install > /dev/null 2>&1
    virsh net-undefine install > /dev/null 2>&1
    rm -rf $COMPASS_DIR/deploy/work/network/*.xml
}

function setup_om_bridge() {
    local device=$1
    local gw=$2
    ip link set br_install down
    ip addr flush $device
    brctl delbr br_install

    brctl addbr br_install
    brctl addif br_install $device
    ip link set br_install up

    shift;shift
    for ip in $*;do
        ip addr add $ip dev br_install
    done

    route add default gw $gw
}

function setup_om_nat() {
    # create install network
    sed -e "s/REPLACE_BRIDGE/br_install/g" \
        -e "s/REPLACE_NAME/install/g" \
        -e "s/REPLACE_GATEWAY/10.1.0.1/g" \
        -e "s/REPLACE_MASK/255.255.255.0/g" \
        -e "s/REPLACE_START/10.1.0.1/g" \
        -e "s/REPLACE_END/10.1.0.254/g" \
        $COMPASS_DIR/deploy/template/network/nat.xml \
        > $WORK_DIR/network/install.xml
    
    virsh net-define $WORK_DIR/network/install.xml
    virsh net-start install
}

function create_nets() {
    destroy_nets
    
    # create mgmt network
    sed -e "s/REPLACE_BRIDGE/br_mgmt/g" \
        -e "s/REPLACE_NAME/mgmt/g" \
        -e "s/REPLACE_GATEWAY/192.168.200.1/g" \
        -e "s/REPLACE_MASK/255.255.255.0/g" \
        -e "s/REPLACE_START/192.168.200.2/g" \
        -e "s/REPLACE_END/192.168.200.254/g" \
        $COMPASS_DIR/deploy/template/network/nat.xml \
        > $WORK_DIR/network/mgmt.xml
    
    virsh net-define $WORK_DIR/network/mgmt.xml
    virsh net-start mgmt
    
    # create install network
    if [[ ! -z $VIRT_NUMBER ]];then
        setup_om_nat
    else
        setup_om_bridge $OM_NIC $OM_GW $INSTALL_GW/24 $OM_IP
    fi

}

