#!/bin/bash
. /utils.sh

# Use for debugging only!
# print_log "$(env)"

cmd=$1
serviceStatus=""

if [ -n "${gitTag}" ]; then
    tag="${gitTag}"
else
    tag="kube"
fi

error () {
    print_log "${1}"
    exit 1
}

# Input env variables used by this service.
dep_name="${parentJobName}"
image="${kube_image}"
public_port="${kube_public_port}"
config="${kube_config}"
reps="${kube_reps}"

# Copied from https://kubernetes.io/docs/tasks/kubectl/install/
print_log "Installing kubectl"
msg=$(curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl) || \
            error "Failed to install kubectl: ${msg}"
chmod +x kubectl
print_log "kubectl installed"

mkdir -p ~/.kube
echo "${config}" > ~/.kube/config

case ${cmd} in
    start)

        msg=$(./kubectl run ${dep_name} --image ${image} --replicas=${reps}) || \
            error "Failed to create the deployment: ${msg}"
        print_log "Deployment created"
        msg=$(./kubectl expose deployments ${dep_name} --port=${public_port} --type=LoadBalancer) || \
            error "Failed to expose the deployment: ${msg}"
        print_log "Deployment exposed on port "

        print_log "Waiting for service to start."
        COUNT=0
        MAX=50
        SLEEP_TIME=5
        ERR=0

        pub_ip=`./kubectl get service ${dep_name} | sed -n 2p | awk {'print $3'}`

        while [ ${pub_ip} == "<pending>" ]; do
          sleep ${SLEEP_TIME}
          let "COUNT++"
          echo ${COUNT}
          if [ ${COUNT} -gt 50 ]; then
            error "Never got IP address for service."
            break
          fi
          pub_ip=`./kubectl get service ${dep_name} | sed -n 2p | awk {'print $3'}`
        done

        print_log "URL: http://${pub_ip}:${public_port}"
        print_log "Service Started."

        ;;
    stop)

        msg=$(./kubectl delete service ${dep_name}) || \
            error "Failed to delete the service: ${msg}"
        msg=$(./kubectl delete deployment ${dep_name}) || \
            error "Failed to delete the deployment: ${msg}"
        print_log "Service Stopped."
        ;;
    update)
        ;;
    *)
        exit 127
        ;;
esac
