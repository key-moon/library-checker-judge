#!/usr/bin/env bash

set -e

NAME=lib-judge-test-$(cat /dev/urandom | tr -d -c '[:lower:]' | fold -w 10 | head -n 1)
ZONE=asia-northeast1-c

echo "Create ${NAME}"

gcloud compute instances create $NAME --zone=$ZONE \
--machine-type=c2-standard-4 \
--boot-disk-size=200GB \
--metadata-from-file user-data=../deploy/cloudinit.yml \
--image-family=ubuntu-1804-lts --image-project=ubuntu-os-cloud \
--preemptible

trap "echo 'Release' && gcloud compute instances delete ${NAME} --zone=${ZONE} --quiet" 0

function gcpexec() {
    echo "Start: ${1}"
    gcloud compute ssh root@${NAME} --zone ${ZONE} -- $1
    RET=$?
    echo "Finish: ${1}"
    return $RET
}

until gcpexec "ls /root/can_start > /dev/null"; do
    echo 'waiting...'
    sleep 10
done

echo "Make Secret"
gcpexec "cd /root/library-checker-judge/judge && ./make_secret.sh"

echo "Checkout Judge ${TEST_COMMIT}"
gcpexec "cd /root/library-checker-judge && git checkout ${TEST_COMMIT}"

echo 'Start generate.py test'
gcpexec "ulimit -s unlimited && cd /root/library-checker-problems && ./generate.py problems.toml"

echo 'Start executor.py test'
gcpexec "cd /root/library-checker-judge/judge && ./executor_test.py"

echo 'Start docker test'
gcpexec "cd /root/library-checker-judge/local && ./launch.sh"

echo 'Start judge test'
gcpexec "cd /root/library-checker-judge/judge && go test . -v"

