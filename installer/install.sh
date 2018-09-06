#!/usr/bin/env bash

#####################################################################
# Global definitions                                                #
#####################################################################
readonly SCRIPT_PATH=$(dirname $0)
readonly SCRIPT_ABSOLUTE_PATH=$(cd $SCRIPT_PATH && pwd)

readonly RED=$(tput setaf 1)
readonly RESET=$(tput sgr0)
readonly GREEN=$(tput setaf 2)
readonly CYAN=$(tput setaf 6)
readonly MAGENTA=$(tput setaf 5)

readonly VER_EQ=0
readonly VER_GT=1
readonly VER_LT=2

oc_install_dir="/usr/local/bin"
oc_version_comparison=${VER_LT}

#####################################################################
# Default values definitions                                                #
#####################################################################
readonly DEFAULT_WILDCARD_DNS_HOST="nip.io"
readonly DEFAULT_DOCKERHUB_TAG="latest"
readonly DEFAULT_DOCKERHUB_ORG="aerogearcatalog"
DEFAULT_CLUSTER_IP=""

# Docker values came from env variables ( export ENV=VALUE )
## Default hidden pwd
## Show the last 2 digits only

if [ $DOCKERHUB_PASSWORD ]; then
  last_digits_pwd=$(echo $DOCKERHUB_PASSWORD | tail -c 3)
  hidden_pwd="**************"$last_digits_pwd
  readonly DEFAULT_DOCKERHUB_PASSWORD=$hidden_pwd
fi
readonly DEFAULT_DOCKERHUB_USERNAME=$DOCKERHUB_USERNAME


#####################################################################
# Minimal version requirements                                      #
#####################################################################
readonly MIN_PYTHON_VERSION=2.7
readonly MIN_ANSIBLE_VERSION=2.6
readonly MIN_OCP_CLIENT_TOOL=3.9

#####################################################################
# Script arguments
#####################################################################
if [[ ${1} == "--debug" || ${1} == "--d" ]]; then
  IS_DEBUG=1
fi

#####################################################################
# Utils functions                                                   #
#####################################################################
# Returns:
# 0 - =
# 1 - >
# 2 - <

function spinner() {
  case $1 in
    start)
      let column=$(tput cols)-${#2}-8
      echo -ne ${2}
      printf "%${column}s"
      local i sp n
      sp='/-\|'
      n=${#sp}
      while sleep 0.1; do
        printf "%s\b" "${sp:i++%n:1}"
      done
      ;;
    stop)
      if [[ -z ${3} ]]; then
        exit 1
      fi
      echo -e "\n"
      kill $3 > /dev/null 2>&1
    esac
}

function spinnerStart {
  spinner "start" "${1}" &
  pid=$!
  disown
}

function spinnerStop {
  spinner "stop" $1 $pid
  unset pid
}

function compare_version () {
  if [[ $1 == $2 ]]; then
    return 0
  fi
  local IFS=.
  local i ver1=(${1}) ver2=(${2})
  for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
    ver1[i]=0
  done
  for ((i=0; i<${#ver1[@]}; i++)); do
    if [[ -z ${ver2[i]} ]]; then
      ver2[i]=0
    fi
    if ((10#${ver1[i]} > 10#${ver2[i]})); then
      return 1
    fi
    if ((10#${ver1[i]} < 10#${ver2[i]})); then
      return 2
    fi
  done
  return 0
}

function does_not_exist_msg() {
  echo -e "${RED} ${1} does not exist on host machine. ${RESET}"
  echo -e "${RED} It can be installed using ${2}. ${RESET}"
}

function check_exists_msg() {
  echo -e "\nChecking ${1} exists"
}

function check_msg() {
  echo -e "\nChecking ${1}"
}

function check_version_msg() {
  echo "Checking ${1} version. Should be ${2}"
}

function check_passed_msg() {
  echo "✓ ${GREEN} ${1} check passed. ${RESET}"
}

function info_msg() {
  echo -e "${CYAN} INFO: ${1} ${RESET}"
}

function warn_msg() {
  echo -e "${MAGENTA} WARNING: ${1} ${RESET}"
}

## Read inputs and show default values
## ${1} : Desc input
## ${2} : Default value
## ${3} : read var
function read_with_default_values() {
  read -p "${1}: ${CYAN} (${2}) ${RESET}" ${3}
}

function install_with_success_msg() {
  echo "✓ ${GREEN} ${1} installed with success. ${RESET}"
}

## Read inputs and show default values
## ${1} : Desc input
## ${2} : Default value
## ${3} : read var
function read_with_default_values() {
  read -p "${1}: ${CYAN} (${2}) ${RESET}" ${3}
}

#####################################################################
# Functions called in the installation process                       #
#####################################################################

# To check if docker is installed and its min version
function check_docker() {
  check_exists_msg "Docker"
  command -v docker &>/dev/null
  docker_exists=${?}; if [[ ${docker_exists} -ne 0 ]]; then
    does_not_exist_msg "Docker" "https://www.docker.com/get-docker"
    exit 1
  fi
  check_passed_msg "Docker"

  echo -e "Checking Docker is running"
  command docker ps &>/dev/null
  docker_running=${?}; if [[ ${docker_running} -ne 0 ]]; then
    echo -e "${RED}Docker is not running.${RESET}"
    exit 1
  fi
  check_passed_msg "Docker running"

  check_version_msg "Docker" "using Stable channel"
  docker_version=$(docker version --format '{{json .Client.Version}}')
  if [[ ${docker_version} == *"-rc"* ]]; then
    echo "${RED}Docker versions from the Edge channel are currently not supported. Switch to a release from the Stable channel${RESET}"
    exit 1
  fi
  check_passed_msg "Docker version"
}

# To check if python is installed and its min version
function check_python() {
  check_exists_msg "Python"

  command -v python &>/dev/null
  python_exists=${?}; if [[ ${python_exists} -ne 0 ]]; then
    does_not_exist_msg "Python" "https://docs.python.org/3/using/unix.html#getting-and-installing-the-latest-version-of-python"
  fi
  check_passed_msg "Python"

  readonly python_version=$(python -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')

  check_version_msg "Python" ">= ${MIN_PYTHON_VERSION}"
  compare_version ${python_version} ${MIN_PYTHON_VERSION}
  python_version_comparison=${?}; if [[ ${python_version_comparison} -eq ${VER_LT} ]]; then
    echo -e "${RED}Python is < ${MIN_PYTHON_VERSION}. Update the python version to >= ${MIN_PYTHON_VERSION}.${RESET}"
    exit 1
  fi
  check_passed_msg "Python version"
}

# To check if ansible tool is installed and its min version
function check_ansible() {
  check_exists_msg "Ansible"

  command -v ansible &>/dev/null
  ansible_exists=${?}; if [[ ${ansible_exists} -ne 0 ]]; then
    does_not_exist_msg "Ansible" "pip install ansible"
    exit 1
  fi
  check_passed_msg "Ansible"

  readonly ansible_version=$(ansible --version | sed -n '1p' | cut -d " " -f2)

  check_version_msg "Ansible" ">= ${MIN_ANSIBLE_VERSION}"
  compare_version ${ansible_version} ${MIN_ANSIBLE_VERSION}
  ansible_version_comparison=${?}; if [[ ${ansible_version_comparison} -eq ${VER_LT} ]]; then
   echo -e "${RED}Ansible version installed is < ${MIN_ANSIBLE_VERSION}. To fix it install an ansible version >= ${MIN_ANSIBLE_VERSION} using 'pip install ansible --upgrade' or 'pip install ansible --upgrade --user' ${RESET}"
   exit 1
  fi
  check_passed_msg "Ansible version"
}

# To check if OpenShift client tool (oc) is installed and its min version
function check_oc() {
  # OPENSHIFT CLIENT TOOLS
  check_exists_msg "OpenShift client tools"

  command -v oc &>/dev/null
  oc_exists=${?}; if [[ ${oc_exists} -ne 0 ]]; then
    echo "? OpenShift Client tools do not exist on host. They will be installed by the MCP installer."
  else
    check_passed_msg "OpenShift Client Tools"
    check_version_msg "OpenShift client tools" ">= ${MIN_OCP_CLIENT_TOOL}"

    readonly oc_version=$(oc version | sed -n "1p" | cut -d " " -f2 | cut -d "-" -f1 | cut -d "v" -f2 | cut -f1 -d'+')
    compare_version ${oc_version} ${MIN_OCP_CLIENT_TOOL}

    oc_version_comparison=${?}; if [[ ${oc_version_comparison} -eq ${VER_LT} ]]; then
      echo -e "\n? OpenShift Client tools are less than ${MIN_OCP_CLIENT_TOOL}"
      read -p "Allow the installer to delete and reinstall the OpenShift client tools? (y/n): " uninstall_client_tools
      if [[ ${uninstall_client_tools} == "y" ]]; then
        echo "Removing oc tool"
        oc_install_dir=$(dirname $(command -v oc))
        rm $(command -v oc)
      else
        echo -e "${RED}Mobile requires oc >= ${MIN_OCP_CLIENT_TOOL}${RESET}"
        exit 1
      fi
    fi
    check_passed_msg "OpenShift Client Tools version"
  fi
  check_to_install_oc
}

# To check if the current version requires another oc tool version
function check_to_install_oc() {
  if [[ ${oc_version_comparison} -eq ${VER_LT} ]]; then
    read_oc_install_dir
  fi
}

# To read the dir to install the correct version of OpenShift client tool
function read_oc_install_dir() {
  read_with_default_values "Where do you want to install oc?" ${oc_install_dir} user_oc_install_dir
  oc_install_dir=${user_oc_install_dir:-${oc_install_dir}}
  echo "Updating PATH to include specified directory"
  export PATH="${oc_install_dir}:${PATH}"
}

# To read Wildcard DNS Host Input
function read_wildcard_dns_host() {
  while :
    do
      read_with_default_values "Wildcard DNS Host" ${DEFAULT_WILDCARD_DNS_HOST} wildcard_dns_host
      wildcard_dns_host=${wildcard_dns_host:-${DEFAULT_WILDCARD_DNS_HOST}}
      if [[ $wildcard_dns_host == *.* ]]; then
        check_passed_msg "Wildcard DNS Host"
        break
      else
        echo -e  "${RED} The value ${wildcard_dns_host} is an invalid Wildcard DNS Host. ${RESET}"
        echo -e  "${RED} Please try again. ${RESET}"
        continue
      fi
  done
}

# To avoid known issues when the cluster need to started
function check_oc_cluster_up() {
  check_msg "Openshift cluster"
  command -v oc &>/dev/null
  oc_exists=${?}; if [[ ${oc_exists} -ne 0 ]]; then
    warn_msg "Unable to check the cluster since oc tool is not installed."
    warn_msg "This tool will be installed in the next steps. Please, try again if an error be faced."
  else
    spinnerStart 'Running oc cluster up ...'
    command oc cluster up &>/dev/null
    cluster_running=${?};
    spinnerStop $?
    if [[ ${cluster_running} -ne 0 ]]; then
      (command oc cluster up 2>&1 | grep 'Error: OpenShift is already running') &>/dev/null
      if [[ ${?} -ne 0 ]];  then # if it is already running the check passed
        command oc cluster up # to show output
        echo -e "${RED}Error to run 'oc cluster up'. ${RESET}"
        echo -e "${RED}See https://github.com/openshift/origin/blob/master/docs/cluster_up_down.md#getting-started. ${RESET}"
        exit 1
      fi
    fi
    check_passed_msg "Openshift cluster"
  fi
}

# To read and check docker credentials
function read_docker_hub_credentials() {
  info_msg "The Mobile installer requires valid DockerHub credentials to communicate with the DockerHub API."
  info_msg "If you enter with an invalid credentials then Mobile Services will not be available in the Service Catalog."

  docker_credentials=0
  while [ $docker_credentials -eq 0 ];
  do
    docker_credentials=1
    read_with_default_values "DockerHub Username" ${DEFAULT_DOCKERHUB_USERNAME:-""} dockerhub_username
    stty -echo
    read_with_default_values "DockerHub Password" ${DEFAULT_DOCKERHUB_PASSWORD:-""} dockerhub_password
    stty echo

    ## If empty use global system variables
    dockerhub_username=${dockerhub_username:-$DOCKERHUB_USERNAME}
    dockerhub_password=${dockerhub_password:-$DOCKERHUB_PASSWORD}

    echo -e "\nChecking DockerHub credentials are valid...\n"

    curl --fail -u ${dockerhub_username}:${dockerhub_password} https://cloud.docker.com/api/app/v1/service/ &> /dev/null

    if [[ ${?} -ne 0 ]]; then
      echo -e "${RED}Invalid Docker credentials. Please re-enter${RESET}"
      docker_credentials=0
    fi
  done
  check_passed_msg "Docker Credentials"
}

# Function to read docker hub tag
function read_docker_hub_tag() {
  read_with_default_values "DockerHub Tag" ${DEFAULT_DOCKERHUB_TAG} dockerhub_tag
  dockerhub_tag=${dockerhub_tag:-${DEFAULT_DOCKERHUB_TAG}}
}

# To read docker hub tag
function read_docker_hub_organization() {
  read_with_default_values "DockerHub Organisation" ${DEFAULT_DOCKERHUB_ORG} dockerhub_org
  dockerhub_org=${dockerhub_org:-${DEFAULT_DOCKERHUB_ORG}}
}

# To get the default Cluster IP
# Pull the network interface from the default route, and get the IP of that interface for the default IP
function get_defult_cluster_ip() {
  DEFAULT_CLUSTER_IP=$(ifconfig $(netstat -nr | awk '{if (($1 == "0.0.0.0" || $1 == "default") && $2 != "0.0.0.0" && $2 ~ /[0-9\.]+{4}/){print $NF;} }' | head -n1) | grep 'inet ' | awk '{print $2}')
}

# To read Cluster IP
function read_cluster_ip() {
  get_defult_cluster_ip
  read_with_default_values "Cluster IP" ${DEFAULT_CLUSTER_IP} cluster_ip
  cluster_ip=${cluster_ip:-${DEFAULT_CLUSTER_IP}}
  DEFAULT_CLUSTER_IP=${cluster_ip}
}

# To execute ansible task
function run_ansible_tasks() {
  echo -e "Performing clean and running the installer ..."
  info_msg "May you will be asked for your System Admin Password(root/sudo)."

  cd ${SCRIPT_ABSOLUTE_PATH}
  cd .. && make clean &>/dev/null

  set -e

  roles_path=${SCRIPT_ABSOLUTE_PATH}/roles
  echo -e "Installing roles from ${roles_path}"
  ansible-galaxy install -r ./installer/requirements.yml --roles-path="${SCRIPT_ABSOLUTE_PATH}/roles" --force
  roles_running=${?}; if [[ ${roles_running} -ne 0 ]]; then
    echo -e  "${RED} ERROR: Unable to install the roles from ${roles_path}.${RESET}"
    exit 1
  fi
  install_with_success_msg "Roles"

  set +e
  echo -e "Installing Mobile Services ..."
  if [[ $IS_DEBUG ]]; then
    if [[ ${oc_version_comparison} -ne ${VER_LT} ]]; then
      install_with_success_msg "OpenShift client tool"
      ansible-playbook installer/playbook.yml --skip-tags "install-oc" \
      -e "dockerhub_username=${dockerhub_username}" \
      -e "dockerhub_password=${dockerhub_password}" \
      -e "dockerhub_tag=${dockerhub_tag}" \
      -e "dockerhub_org=${dockerhub_org}" \
      -e "cluster_public_ip=${cluster_ip}" \
      -e "wildcard_dns_host=${wildcard_dns_host}"
    else
      ansible-playbook installer/playbook.yml \
      -e "dockerhub_username=${dockerhub_username}" \
      -e "dockerhub_password=${dockerhub_password}" \
      -e "dockerhub_tag=${dockerhub_tag}" \
      -e "dockerhub_org=${dockerhub_org}" \
      -e "cluster_public_ip=${cluster_ip}" \
      -e "wildcard_dns_host=${wildcard_dns_host}" \
      -e "oc_install_parent_dir=${oc_install_dir}"
    fi
  else
    spinnerStart 'It may take few minutes ...'
    if [[ ${oc_version_comparison} -ne ${VER_LT} ]]; then
      install_with_success_msg "OpenShift client tool"
      (ansible-playbook installer/playbook.yml --skip-tags "install-oc" \
      -e "dockerhub_username=${dockerhub_username}" \
      -e "dockerhub_password=${dockerhub_password}" \
      -e "dockerhub_tag=${dockerhub_tag}" \
      -e "dockerhub_org=${dockerhub_org}" \
      -e "cluster_public_ip=${cluster_ip}" \
      -e "wildcard_dns_host=${wildcard_dns_host}" 2>&1 | grep 'failed=0') &>/dev/null
    else
      (ansible-playbook installer/playbook.yml \'
      -e "dockerhub_username=${dockerhub_username}" \
      -e "dockerhub_password=${dockerhub_password}" \
      -e "dockerhub_tag=${dockerhub_tag}" \
      -e "dockerhub_org=${dockerhub_org}" \
      -e "cluster_public_ip=${cluster_ip}" \
      -e "wildcard_dns_host=${wildcard_dns_host}" \
      -e "oc_install_parent_dir=${oc_install_dir}"  2>&1 | grep 'failed=0') &>/dev/null
    fi
    if [[ ${?} -ne 0 ]]; then
      spinnerStop $?
      echo -e  "${RED} ERROR: Unable to install the Mobile Services. ${RESET}"
      echo -e  "${RED} ERROR: For further information use the --debug option to execute this installation. ${RESET}"
      exit 1
    fi
    spinnerStop $?
    install_with_success_msg "Mobile Services"
    info_msg "See the Mobile Services in your OpenShift Console. URL: https://${DEFAULT_CLUSTER_IP}:8443/console/"
    info_msg "For information on how to enable TLS communication on your device to this cluster see https://docs.aerogear.org/external/installer/self-signed-cert.html"
  fi
}

# Run all scripts to install after the checks
function run_installer() {
  read_docker_hub_credentials
  read_docker_hub_tag
  read_docker_hub_organization
  read_cluster_ip
  read_wildcard_dns_host
  run_ansible_tasks
}

#####################################################################
# Execution/Installation process                                    #
#####################################################################

check_docker
check_python
check_ansible
check_oc
check_oc_cluster_up
run_installer
