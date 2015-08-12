#!/bin/bash
set -ex

WORK_PATH=$(cd "$(dirname "$0")"; pwd)
REPO_PATH=${WORK_PATH}/repo
UBUNTU_TAG="trusty"
OPENSTACK_TAG="juno"
DOCKER_TAG="${UBUNTU_TAG}/openstack-${OPENSTACK_TAG}"
DOCKER_FILE=${WORK_PATH}/${UBUNTU_TAG}/${OPENSTACK_TAG}/Dockerfile

if [[ $UID != 0 ]]; then
    echo "You are not root user!"
    exit 1
fi

if [ ! -d ${REPO_PATH} ]; then
    mkdir -p ${REPO_PATH}
fi

docker info
if [[ $? != 0 ]]; then
    wget -qO- https://get.docker.com/ | sh
else
    echo "docker is already installed!"
fi

if [ -e ${WORK_PATH}/cp_repo.sh ]; then
    rm -f ${WORK_PATH}/cp_repo.sh
fi

cat <<EOF >${WORK_PATH}/cp_repo.sh
#!/bin/bash
set -ex
cp /*ppa.tar.gz /result
EOF

#docker build
docker build -t ${DOCKER_TAG} -f ${DOCKER_FILE} .

#docker run
mkdir -p ${REPO_PATH}
docker run -t -v ${REPO_PATH}:/result ${DOCKER_TAG}

IMAGE_ID=$(docker images|grep ${DOCKER_TAG}|awk '{print $3}')
docker rmi -f ${IMAGE_ID}

if [ -e ${WORK_PATH}/cp_repo.sh ]; then
    rm -f ${WORK_PATH}/cp_repo.sh
fi

