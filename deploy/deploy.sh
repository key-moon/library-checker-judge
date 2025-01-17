#!/usr/bin/env bash

set -e

NAME=lib-judge-executor-$(cat /dev/urandom | tr -d -c '[:lower:]' | fold -w 10 | head -n 1)
ZONE=asia-northeast1-c

gcloud compute instances create $NAME --zone=$ZONE \
--machine-type=c2-standard-4 \
--metadata-from-file user-data=cloudinit.yml \
--image-family=ubuntu-1804-lts --image-project=ubuntu-os-cloud ${CREATE_OPTION}

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

echo "Build judge"
gcpexec "cd /root/library-checker-judge/judge && go build ."

echo "Make Secret HOST=${PG_HOST} / PASS=${PG_PASS}"
gcpexec "cd /root/library-checker-judge/judge && PG_HOST=${PG_HOST} PG_PASS=${PG_PASS} ./make_secret.sh"

echo "Launch Judge"
gcpexec "supervisorctl start judge"
