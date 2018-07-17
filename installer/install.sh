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

readonly VER_EQ=0
readonly VER_GT=1
readonly VER_LT=2

oc_install_dir="/usr/local/bin"
oc_version_comparison=${VER_LT}

#####################################################################
# Minimal version requirements                                      #
#####################################################################
readonly MIN_PYTHON_VERSION=2.7
readonly MIN_ANSIBLE_VERSION=2.6
readonly MIN_OCP_CLIENT_TOOL=3.9

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
  read -p "Where do you want to install oc? (Defaults to ${oc_install_dir}): " user_oc_install_dir
  oc_install_dir=${user_oc_install_dir:-${oc_install_dir}}
  echo "Updating PATH to include specified directory"
  export PATH="${oc_install_dir}:${PATH}"
}

# To read Wildcard DNS Host Input
function read_wildcard_dns_host() {
  while :
    do
      read -p "Wildcard DNS Host (Defaults to nip.io): " wildcard_dns_host
      wildcard_dns_host=${wildcard_dns_host:-"nip.io"}
      if [[ $wildcard_dns_host == *.* ]]; then
        echo "Your Wildcard DNS Host is: ${wildcard_dns_host}."
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
}

# To read and check docker credentials
function read_docker_hub_credentials() {
  info_msg "The Mobile installer requires valid DockerHub credentials to communicate with the DockerHub API."
  info_msg "If you enter with an invalid credentials then Mobile Services will not be available in the Service Catalog."

  docker_credentials=0
  while [ $docker_credentials -eq 0 ];
  do
    docker_credentials=1
    read -p "DockerHub Username (Defaults to DOCKERHUB_USERNAME env var): " dockerhub_username
    stty -echo
    read -p "DockerHub Password (Defaults to DOCKERHUB_PASSWORD env var): " dockerhub_password
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
  read -p "DockerHub Tag (Defaults to latest): " dockerhub_tag
  dockerhub_tag=${dockerhub_tag:-"latest"}
}

# To read docker hub tag
function read_docker_hub_organization() {
  read -p "DockerHub Organisation (Defaults to aerogearcatalog): " dockerhub_org
  dockerhub_org=${dockerhub_org:-"aerogearcatalog"}
}

# To get the default Cluster IP
# Pull the network interface from the default route, and get the IP of that interface for the default IP
function get_defult_cluster_ip() {
  ipDefault=$(ifconfig $(netstat -nr | awk '{if (($1 == "0.0.0.0" || $1 == "default") && $2 != "0.0.0.0" && $2 ~ /[0-9\.]+{4}/){print $NF;} }' | head -n1) | grep 'inet ' | awk '{print $2}')
}

# To read Cluster IP
function read_cluster_ip() {
  get_defult_cluster_ip
  read -p "Cluster IP (Defaults to ${ipDefault}): " cluster_ip
  cluster_ip=${cluster_ip:-${ipDefault}}
}

# To execute ansible task
function run_ansible_tasks() {
  echo "Performing clean and running the installer. You will be asked for your password."

  cd ${SCRIPT_ABSOLUTE_PATH}
  cd .. && make clean &>/dev/null

  set -e
  echo "Installing roles from ${SCRIPT_ABSOLUTE_PATH}/roles"
  ansible-galaxy install -r ./installer/requirements.yml --roles-path="${SCRIPT_ABSOLUTE_PATH}/roles" --force
  set +e

  if [[ ${oc_version_comparison} -ne ${VER_LT} ]]; then
    echo "Skipping OpenShift client tools installation..."
    ansible-playbook installer/playbook.yml --ask-become-pass --skip-tags "install-oc" \
    -e "dockerhub_username=${dockerhub_username}" \
    -e "dockerhub_password=${dockerhub_password}" \
    -e "dockerhub_tag=${dockerhub_tag}" \
    -e "dockerhub_org=${dockerhub_org}" \
    -e "cluster_public_ip=${cluster_ip}" \
    -e "wildcard_dns_host=${wildcard_dns_host}"
  else
    ansible-playbook installer/playbook.yml --ask-become-pass \
    -e "dockerhub_username=${dockerhub_username}" \
    -e "dockerhub_password=${dockerhub_password}" \
    -e "dockerhub_tag=${dockerhub_tag}" \
    -e "dockerhub_org=${dockerhub_org}" \
    -e "cluster_public_ip=${cluster_ip}" \
    -e "wildcard_dns_host=${wildcard_dns_host}" \
    -e "oc_install_parent_dir=${oc_install_dir}"
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
