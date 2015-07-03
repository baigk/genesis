#set -x
WORK_DIR=$COMPASS_DIR/ci/work

reset=`tput sgr0`
blue=`tput setaf 4`
red=`tput setaf 1`
green=`tput setaf 2`

if [[ $# -ge 1 ]];then
    CONF_NAME=$1
else
    CONF_NAME=cluster
fi

source ${COMPASS_DIR}/deploy/conf/${CONF_NAME}.conf
source ${COMPASS_DIR}/deploy/prepare.sh
source ${COMPASS_DIR}/deploy/network.sh

if [[ ! -z $VIRT_NUMBER ]];then
    source ${COMPASS_DIR}/deploy/host_vm.sh
else
    source ${COMPASS_DIR}/deploy/host_baremetal.sh
fi

source ${COMPASS_DIR}/deploy/compass_vm.sh
source ${COMPASS_DIR}/deploy/deploy_host.sh

######################### main process

if ! prepare_env;then
    echo "prepare_env failed"
    exit 1
fi

echo -e "$green########## get host mac begin ############# $reset"
machines=`get_host_macs`
if [[ -z $machines ]];then
    echo -e "$red get_host_macs failed $reset"
    exit 1
fi
export machines

echo -e "$green host macs: $machines $reset"

echo -e "$green########## set up network begin ############# $reset"
if ! create_nets;then
    echo -e "$red create_nets failed $reset"
    exit 1
fi

if ! launch_compass;then
    echo "launch_compass failed"
    exit 1
fi

if [[ ! -z $VIRT_NUMBER ]];then
    if ! launch_host_vms;then
        echo "launch_host_vms failed"
        exit 1
    fi
fi
if ! deploy_host;then
    #tear_down_machines
    #tear_down_compass
    exit 1
else
    #tear_down_machines
    #tear_down_compass
    exit 0
fi


