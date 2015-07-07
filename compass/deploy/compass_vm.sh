compass_vm_dir=$WORK_DIR/vm/compass
rsa_file=$compass_vm_dir/boot.rsa
ssh_args="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i $rsa_file"
function tear_down_compass() {
    sudo virsh destroy compass > /dev/null 2>&1
    sudo virsh undefine compass > /dev/null 2>&1

    sudo umount $compass_vm_dir/old > /dev/null 2>&1
    sudo umount $compass_vm_dir/new > /dev/null 2>&1

    sudo rm -rf $compass_vm_dir
    
    log_info "tear_down_compass success!!!"
}

function install_compass_core() {
    local inventory_file=$compass_vm_dir/inventory.file
    log_info "install_compass_core enter"
    sed -i "s/mgmt_next_ip:.*/mgmt_next_ip: ${COMPASS_SERVER}/g" $WORK_DIR/installer/compass-install/install/group_vars/all
    echo "compass_nodocker ansible_ssh_host=192.168.200.2 ansible_ssh_port=22" > $inventory_file
    PYTHONUNBUFFERED=1 ANSIBLE_FORCE_COLOR=true ANSIBLE_HOST_KEY_CHECKING=false ANSIBLE_SSH_ARGS='-o UserKnownHostsFile=/dev/null -o ControlMaster=auto -o ControlPersist=60s' ansible-playbook -e pipeline=true --private-key=$rsa_file --user=root --connection=ssh --inventory-file=$inventory_file $WORK_DIR/installer/compass-install/install/compass_nodocker.yml
    exit_status=$?
    rm $inventory_file
    log_info "install_compass_core exit"
    if [[ $exit_status != 0 ]];then
        /bin/false
    fi
}

function wait_ok() {
    log_info "wait_compass_ok enter"
    retry=0
    until timeout 1s ssh $ssh_args root@192.168.200.2 "exit" 2>/dev/null
    do
        log_progress "os install time used: $((retry*100/$1))%"
        sleep 1
        let retry+=1
        if [[ $retry -ge $1 ]];then
            log_error "os install time out"
            tear_down_compass
            exit 1
        fi
    done

    log_warn "os install time used: 100%"
    log_info "wait_compass_ok exit"
}

function launch_compass() {
    local old_mnt=$compass_vm_dir/old
    local new_mnt=$compass_vm_dir/new
    local old_iso=$WORK_DIR/iso/centos.iso 
    local new_iso=$compass_vm_dir/centos.iso 

    log_info "launch_compass enter"
    tear_down_compass
    
    set -e
    mkdir -p $compass_vm_dir $old_mnt
    sudo mount -o loop $old_iso $old_mnt
    cp -rf $old_mnt $new_mnt
    chmod 755 -R $new_mnt
    sudo umount $old_mnt

    sed -i -e "s/REPLACE_MGMT_IP/192.168.200.2/g" -e "s/REPLACE_MGMT_NETMASK/255.255.252.0/g" -e "s/REPLACE_INSTALL_IP/$COMPASS_SERVER/g" -e "s/REPLACE_INSTALL_NETMASK/255.255.255.0/g" -e "s/REPLACE_GW/192.168.200.1/g" $new_mnt/isolinux/isolinux.cfg
   
    sudo ssh-keygen -f $new_mnt/bootstrap/boot.rsa -t rsa -N ''
    cp $new_mnt/bootstrap/boot.rsa $rsa_file

    rm -rf $new_mnt/.rr_moved $new_mnt/rr_moved
    sudo mkisofs -quiet -r -J -R -b isolinux/isolinux.bin  -no-emul-boot -boot-load-size 4 -boot-info-table -hide-rr-moved -x "lost+found:" -o $new_iso $new_mnt

    rm -rf $old_mnt $new_mnt
    
    qemu-img create -f qcow2 $compass_vm_dir/disk.img 100G
    
    # create vm xml
     sed -e "s/REPLACE_MEM/4096/g" \
        -e "s/REPLACE_CPU/4/g" \
        -e "s#REPLACE_IMAGE#$compass_vm_dir/disk.img#g" \
        -e "s#REPLACE_ISO#$compass_vm_dir/centos.iso#g" \
        -e "s/REPLACE_NET_MGMT/mgmt/g" \
        -e "s/REPLACE_BRIDGE_INSTALL/br_install/g" \
        $COMPASS_DIR/deploy/template/vm/compass.xml \
        > $WORK_DIR/vm/compass/libvirt.xml
    
    sudo virsh define $compass_vm_dir/libvirt.xml
    sudo virsh start compass
    
    if ! wait_ok 300;then
        log_error "install os timeout"
        exit 1
    fi

    if ! install_compass_core;then
        log_error "install compass core failed"
        exit 1
    fi
    
    set +e
    log_info "launch_compass exit"
}
