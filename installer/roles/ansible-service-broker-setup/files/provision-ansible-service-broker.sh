#!/bin/bash
set -e

readonly DOCKERHUB_USER="${1}"
readonly DOCKERHUB_PASS="${2}"
readonly DOCKERHUB_ORG="${3}"
readonly LAUNCH_APB_ON_BIND="${4}"
readonly TAG="${5}"
readonly WILDCARD_DNS="${6}"

echo "starting install of OpenShift Ansible Broker (OAB)"

function finish {
  echo "unexpected exit of OpenShift Ansible Broker (OAB) installation script"
}

trap 'finish' EXIT

readonly TEMPLATE_VERSION="89f05ffdd7c525329ea9a17780e996702cac1619"
readonly TEMPLATE_URL="https://raw.githubusercontent.com/openshift/ansible-service-broker/${TEMPLATE_VERSION}/templates/deploy-ansible-service-broker.template.yaml"
readonly TEMPLATE_LOCAL="/tmp/deploy-ansible-service-broker.template.yaml"
readonly TEMPLATE_VARS="-p BROKER_CA_CERT=$(oc get secret -n kube-service-catalog -o go-template='{{ range .items }}{{ if eq .type "kubernetes.io/service-account-token" }}{{ index .data "service-ca.crt" }}{{end}}{{"\n"}}{{end}}' | tail -n 1)"

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
-n {{ ansible_service_broker }} \
-p DOCKERHUB_USER="$( echo ${DOCKERHUB_USER} | base64 )" \
-p DOCKERHUB_PASS="$( echo ${DOCKERHUB_PASS} | base64 )" \
-p DOCKERHUB_ORG="${DOCKERHUB_ORG}" \
-p BROKER_IMAGE="ansibleplaybookbundle/origin-ansible-service-broker:sprint142" \
-p ENABLE_BASIC_AUTH="false" \
-p SANDBOX_ROLE="admin" \
-p ROUTING_SUFFIX="192.168.37.1.${WILDCARD_DNS}" \
-p TAG="${TAG:-latest}" \
-p ETCD_TRUSTED_CA_FILE=/var/run/etcd-auth-secret/ca.crt \
-p BROKER_CLIENT_CERT_PATH=/var/run/asb-etcd-auth/client.crt \
-p BROKER_CLIENT_KEY_PATH=/var/run/asb-etcd-auth/client.key \
-p ETCD_TRUSTED_CA="$ETCD_CA_CERT" \
-p BROKER_CLIENT_CERT="$BROKER_CLIENT_CERT" \
-p BROKER_CLIENT_KEY="$BROKER_CLIENT_KEY" \
-p NAMESPACE=ansible-service-broker \
-p AUTO_ESCALATE="true" \
-p LAUNCH_APB_ON_BIND="${LAUNCH_APB_ON_BIND}" \
${TEMPLATE_VARS} | oc create -f -

if [ "${?}" -ne 0 ]; then
	echo "Error processing template and creating deployment"
	exit
fi
