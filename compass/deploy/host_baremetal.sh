function reboot_hosts() {
#   cmd='for i in {14..18}; do /dev/shm/smm/usr/bin/smmset -l blade$i -d bootoption -v 1 0; echo Y | /dev/shm/smm/usr/bin/smmset -l blade$i -d frucontrol -v 0; done'
#   /usr/bin/expect ${COMPASS_DIR}/deploy/remote_excute.exp ${SWITCH_IPS} 'root' 'Admin@7*24' "$cmd"
    cat ${HOSTS_CFG} | grep -v "^#" | while read line; do
       read _ _ host user pass _ <<< $line
       ipmitool -I lan -U $user -P $pass -H $host chassis bootdev pxe;
       echo "set pxe  $host" $?
       ipmitool -I lan -U $user -P $pass -H $host power reset;
       echo "reset  $host" $?
    done
}

function get_host_macs() {
    local host_macs=${HOST_MACS:-`cat ${HOSTS_CFG} | awk '$0 !~ /^#/{printf "'\''" $4 "'\'' "}' | sed 's/ $//g'`}
    local config_file=$WORK_DIR/installer/compass-install/install/group_vars/all
    local machines=`echo $host_macs|sed 's/ /,/g'`

    echo "test: true" >> $config_file
    echo "pxe_boot_macs: [${machines}]" >> $config_file
    
    echo $machines
}
