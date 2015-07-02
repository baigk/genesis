compass_vm_dir=$WORK_DIR/vm/compass
rsa_file=$compass_vm_dir/boot.rsa

function tear_down_compass() {
    virsh destroy compass > /dev/null 2>&1
    virsh undefine compass > /dev/null 2>&1

    umount $compass_vm_dir/old > /dev/null 2>&1
    umount $compass_vm_dir/new > /dev/null 2>&1

    rm -rf $compass_vm_dir
    
    echo "tear_down_compass success!!!"
}

function install_compass_core() {
    local inventory_file=$compass_vm_dir/inventory.file
    echo -e "$green install_compass_core enter $reset"
    sed -i "s/mgmt_next_ip:.*/mgmt_next_ip: ${COMPASS_SERVER}/g" $WORK_DIR/installer/compass-install/install/group_vars/all
    echo "compass_nodocker ansible_ssh_host=192.168.200.2 ansible_ssh_port=22" > $inventory_file
    PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ANSIBLE_HOST_KEY_CHECKING=false ANSIBLE_SSH_ARGS='-o UserKnownHostsFile=/dev/null -o ControlMaster=auto -o ControlPersist=60s' ansible-playbook --private-key=$rsa_file --user=root --connection=ssh --inventory-file=$inventory_file $WORK_DIR/installer/compass-install/install/compass_nodocker.yml
    rm $inventory_file
    echo -e "$green install_compass_core exit $reset"
}

function wait_ok() {
    echo -e "$green wait_compass_ok enter $reset"
    retry=0
    until timeout 1s ssh -o "StrictHostKeyChecking no" -i $rsa_file root@192.168.200.2 "exit" 2>/dev/null
    do
        echo -ne "$greeos os install time used: $((retry*100/$1))%\r$reset"
        sleep 1
        let retry+=1
        if [[ $retry -gt $1 ]];then
            echo "os install time out"
            tear_down_compass
            exit 1
        fi
    done

    echo -e "$green wait_compass_ok exit $reset"
}

function launch_compass() {
    local old_mnt=$compass_vm_dir/old
    local new_mnt=$compass_vm_dir/new
    local old_iso=$WORK_DIR/iso/centos.iso 
    local new_iso=$compass_vm_dir/centos.iso 

    echo -e "$green launch_compass enter $reset"
    tear_down_compass

    mkdir -p $compass_vm_dir $old_mnt
    mount -o loop $old_iso $old_mnt
    cp -rf $old_mnt $new_mnt
    umount $old_mnt

    sed -i -e "s/REPLACE_MGMT_IP/192.168.200.2/g" -e "s/REPLACE_MGMT_NETMASK/255.255.252.0/g" -e "s/REPLACE_INSTALL_IP/$COMPASS_SERVER/g" -e "s/REPLACE_INSTALL_NETMASK/255.255.255.0/g" -e "s/REPLACE_GW/192.168.200.1/g" $new_mnt/isolinux/isolinux.cfg
   
    ssh-keygen -f $new_mnt/bootstrap/boot.rsa -t rsa -N ''
    cp $new_mnt/bootstrap/boot.rsa $rsa_file

    mkisofs -o $new_iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -R -J -v -T $new_mnt

    rm -rf $old_mnt $new_mnt
    
    qemu-img create -f qcow2 $compass_vm_dir/disk.img 100G
    
    # create vm xml
     sed -e "s/REPLACE_MEM/4096/g" \
        -e "s/REPLACE_CPU/4/g" \
        -e "s#REPLACE_IMAGE#$compass_vm_dir/disk.img#g" \
        -e "s#REPLACE_ISO#$compass_vm_dir/centos.iso#g" \
        -e "s/REPLACE_NET_MGMT/mgmt/g" \
        -e "s/REPLACE_BRIDGE/br_install/g" \
        $COMPASS_DIR/deploy/template/vm/compass.xml \
        > $WORK_DIR/vm/compass/libvirt.xml
    
    virsh define $compass_vm_dir/libvirt.xml
    virsh start compass
    
    wait_ok 300
    install_compass_core

    echo -e "$green launch_compass enter $reset"
}
