#!/bin/bash
set -e

readonly DOCKERHUB_USER="${1:?"[ERROR]You must provide a dockerhub username."}"
readonly DOCKERHUB_PASS="${2:?"[ERROR]You must provide a dockerhub password."}"
readonly DOCKERHUB_ORG="${3:?"[ERROR]You must provide a dockerhub organization."}"
readonly LAUNCH_APB_ON_BIND="${4:?"[ERROR]You must provide if lunch apb on bind."}"
readonly TAG="${5:?"[ERROR]You must provide a tag of service broker to be used."}"
readonly PUBLIC_IP="${6:?"[ERROR]You must provide public ip address where service should be binded."}"
readonly WILDCARD_DNS="${7:?"[ERROR]You must provide wildcard dns to route requests."}"
readonly ANSIBLE_SERVICE_BROKER_NAMESPACE="${8:?"[ERROR]You must provide namespace where service broker will run."}"
readonly IMAGE_PULL_POLICY="${9:?"[ERROR]You must provide an image pull policy."}"

echo "starting install of OpenShift Ansible Broker (OAB)"

function finish {
  echo "unexpected exit of OpenShift Ansible Broker (OAB) installation script"
}

trap 'finish' EXIT

readonly TEMPLATE_VERSION="release-1.1"
readonly TEMPLATE_URL="https://raw.githubusercontent.com/openshift/ansible-service-broker/${TEMPLATE_VERSION}/templates/deploy-ansible-service-broker.template.yaml"
readonly TEMPLATE_LOCAL="/tmp/deploy-ansible-service-broker.template.yaml"
readonly TEMPLATE_VARS="-p IMAGE_PULL_POLICY=${IMAGE_PULL_POLICY} -p BROKER_CA_CERT=$(oc get secret -n kube-service-catalog -o go-template='{{ range .items }}{{ if eq .type "kubernetes.io/service-account-token" }}{{ index .data "service-ca.crt" }}{{end}}{{"\n"}}{{end}}' | tail -n 1)"

oc login -u system:admin
oc new-project ansible-service-broker

# Creating openssl certs to use.
mkdir -p /tmp/etcd-cert
openssl req -nodes -x509 -newkey rsa:4096 -keyout /tmp/etcd-cert/key.pem -out /tmp/etcd-cert/cert.pem -days 365 -subj "/CN=asb-etcd.ansible-service-broker.svc"
openssl genrsa -out /tmp/etcd-cert/MyClient1.key 2048 \
&& openssl req -new -key /tmp/etcd-cert/MyClient1.key -out /tmp/etcd-cert/MyClient1.csr -subj "/CN=client" \
&& openssl x509 -req -in /tmp/etcd-cert/MyClient1.csr -CA /tmp/etcd-cert/cert.pem -CAkey /tmp/etcd-cert/key.pem -CAcreateserial -out /tmp/etcd-cert/MyClient1.pem -days 1024

ETCD_CA_CERT=$(cat /tmp/etcd-cert/cert.pem | base64)
BROKER_CLIENT_CERT=$(cat /tmp/etcd-cert/MyClient1.pem | base64)
BROKER_CLIENT_KEY=$(cat /tmp/etcd-cert/MyClient1.key | base64)

curl -s ${TEMPLATE_URL} > "${TEMPLATE_LOCAL}"

oc process -f "${TEMPLATE_LOCAL}" \
-n ${ANSIBLE_SERVICE_BROKER_NAMESPACE} \
-p DOCKERHUB_USER="$( echo ${DOCKERHUB_USER} | base64 )" \
-p DOCKERHUB_PASS="$( echo ${DOCKERHUB_PASS} | base64 )" \
-p DOCKERHUB_ORG="${DOCKERHUB_ORG}" \
-p BROKER_IMAGE="ansibleplaybookbundle/origin-ansible-service-broker:sprint147.2" \
-p ENABLE_BASIC_AUTH="false" \
-p SANDBOX_ROLE="admin" \
-p ROUTING_SUFFIX="${PUBLIC_IP}.${WILDCARD_DNS}" \
-p TAG="${TAG:-latest}" \
-p ETCD_TRUSTED_CA_FILE=/var/run/etcd-auth-secret/ca.crt \
-p BROKER_CLIENT_CERT_PATH=/var/run/asb-etcd-auth/client.crt \
-p BROKER_CLIENT_KEY_PATH=/var/run/asb-etcd-auth/client.key \
-p ETCD_TRUSTED_CA="$ETCD_CA_CERT" \
-p BROKER_CLIENT_CERT="$BROKER_CLIENT_CERT" \
-p BROKER_CLIENT_KEY="$BROKER_CLIENT_KEY" \
-p NAMESPACE=${ANSIBLE_SERVICE_BROKER_NAMESPACE} \
-p AUTO_ESCALATE="true" \
-p LAUNCH_APB_ON_BIND="${LAUNCH_APB_ON_BIND}" \
${TEMPLATE_VARS} | oc create -f -

if [ "${?}" -ne 0 ]; then
	echo "Error processing template and creating deployment"
	exit
fi
