host_vm_dir=$WORK_DIR/vm
function tear_down_machines() {
    for i in host{0..4}
    do
        virsh destroy $i 1>/dev/null 2>/dev/null
        virsh undefine $i 1>/dev/null 2>/dev/null
        rm -rf $host_vm_dir/$i
    done
}

function launch_host_vms() {
    tear_down_machines
    #function_bod
    mac_array=`echo $machines|sed 's/,/ /g'`
    echo "bringing up pxe boot vms"
    i=0
    for mac in $mac_array; do
        echo "creating vm disk for instance host${i}"
        vm_dir=$host_vm_dir/$i
        mkdir -p $vm_dir
        sudo qemu-img create -f raw $vm_dir/disk.img ${VIRT_DISK}
        sudo virt-install --accelerate --hvm --connect qemu:///system \
             --name host$i --ram=$VIRT_MEM --pxe --disk $vm_dir/disk.img,format=raw \
             --vcpus=$VIRT_CPUS --graphics vnc,listen=0.0.0.0 --boot=hd,network \
             --network=bridge:br_install,mac=$mac \
             --network=bridge:br_install \
             --network=bridge:br_install \
             --network=bridge:br_install \
             --noautoconsole --autostart --os-type=linux --os-variant=rhel6
        let i=i+1
    done
}

function get_host_macs() {
    local config_file=$WORK_DIR/installer/compass-install/install/group_vars/all
    local mac_generator=${COMPASS_DIR}/deploy/mac_generator.sh
    local machines=

    chmod +x $mac_generator
    mac_array=`$mac_generator $VIRT_NUMBER`
    machines=`echo $mac_array|sed 's/ /,/g'`

    echo "test: true" >> $config_file
    echo "pxe_boot_macs: [${machines}]" >> $config_file
    
    echo $machines
}

