#!/bin/bash
###------------------------------------------------------------------------------------------------
# application: Infrastructure - NAT
# script:      configure.sh
# class:       ApplicationStart
# version:     1.0.0
###------------------------------------------------------------------------------------------------

###------------------------------------------------------------------------------------------------
## Config
declare SELF_IDENTITY="codedeploy_configure"
declare SELF_IDENTITY_H="CodeDeploy (Configure)"

###------------------------------------------------------------------------------------------------
## Load Defaults
declare -r GLOBAL_CONFIG_FILE="${DIRECTORY_AWS_DEPLOY:-/opt/aws_deploy}/config/global.config"
source "${GLOBAL_CONFIG_FILE}" || exit 3
declare -r DIRECTORY_CODEDEPLOY_SCRIPTS="$(cd "$($(which dirname) "${BASH_SOURCE[0]}")" && $(which pwd))"
source "${DIRECTORY_CODEDEPLOY_SCRIPTS}/codedeploy.config" || exit 3

###------------------------------------------------------------------------------------------------
## Declare dependencies
REQUIRED_SOURCE_FILES+=(
    "${LIB_FUNCTIONS_CORE_PACKAGE_MANAGEMENT}"
    "${LIB_FUNCTIONS_BOOTSTRAP_SECRETS}"
    "${LIB_FUNCTIONS_AWS_METADATA}"
    "${LIB_FUNCTIONS_AWS_CLOUDFORMATION}"
    "${LIB_FUNCTIONS_AWS_SSM}"
    "${LIB_FUNCTIONS_AWS_EC2}"
)

###------------------------------------------------------------------------------------------------
## Variables
TMP_KEY=""
TMP_VAR=""

FILE_SECRETS_VARS=""
FILE_SECRETS_VARS_GLOBAL=""
FILE_STACK_VARS=""

###------------------------------------------------------------------------------------------------
## Main
# Process Arguments
start_logic
log "${SELF_IDENTITY_H}: Started"

##-----------------------------------------------------------------------------------------------------------------------------------------
## START Initialize
line_break
log_highlight "Initialize"

line_break
log "- Application Name:      [${APPLICATION_NAME}]"
log "- Application Abbr:      [${APPLICATION_ABBR}]"
log "- Application Directory: [${DIRECTORY_BUNDLE}]"

generate_temp_file FILE_SECRETS_VARS "secrets vars file"
generate_temp_file FILE_STACK_VARS "stack vars file"

retrieve_application_secrets "${FILE_SECRETS_VARS}"
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $RETURNVAL; fi

log_notice "${SELF_IDENTITY_H}: Loading Variables [AWS]"
load_array_properties_from_file "AWS_INFO_VARIABLES_REQUIRED[@]" "${FILE_DEPLOY_INFO_AWS}" AWS_INFO
aws_metadata_instance_id AWS_INFO_INSTANCE_ID
verify_array_key_values "AWS_INFO_VARIABLES_REQUIRED[@]" AWS_INFO
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $RETURNVAL; fi

log_notice "${SELF_IDENTITY_H}: Loading Variables [Secrets]"
load_array_properties_from_file "SECRETS_VARS_REQUIRED[@]" "${FILE_SECRETS_VARS}" "SECRETS_VAR"
load_array_properties_from_file "SECRETS_VARS_OPTIONAL[@]" "${FILE_SECRETS_VARS}" "SECRETS_VAR"
load_property_from_file SECRETS_VAR_VERSION "version" "${FILE_VERSION_INFO}"
verify_array_key_values "SECRETS_VARS_REQUIRED[@]" "SECRETS_VAR"
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $RETURNVAL; fi

log_notice "${SELF_IDENTITY_H}: Retrieving Stack Variables"
cloudformation_get_outputs_silent "${FILE_STACK_VARS}" "${AWS_INFO_VPC_STACK_NAME}" "${AWS_INFO_REGION}"
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $RETURNVAL; fi

log_notice "${SELF_IDENTITY_H}: Loading Variables [Stack]"
load_array_properties_from_file "STACK_VARIABLES_REQUIRED[@]" "${FILE_STACK_VARS}" "STACK_VAR"
verify_array_key_values "STACK_VARIABLES_REQUIRED[@]" "STACK_VAR"
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $RETURNVAL; fi

retrieve_secrets_files "SECRETS_FILES[@]"
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $RETURNVAL; fi

retrieve_secrets_files_global "SECRETS_FILES_GLOBAL[@]"
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $RETURNVAL; fi

line_break
log ">> Instance ID:            [${AWS_INFO_INSTANCE_ID}]"
log ">> VPC Stack Name:         [${AWS_INFO_VPC_STACK_NAME}]"
log ">> VPC CIDR:               [${STACK_VAR_VPCCIDR}]"
log ">> Route Table Private ID: [${STACK_VAR_ROUTETABLEPRIVATEID}]"
log ">> AWS Region:             [${AWS_INFO_REGION}]"

## END Initialize
##-----------------------------------------------------------------------------------------------------------------------------------------

##-----------------------------------------------------------------------------------------------------------------------------------------
## START Execution
line_break
log_highlight "Execution"

ec2_source_destination_check_disable "${AWS_INFO_INSTANCE_ID}" "${AWS_INFO_REGION}"
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $RETURNVAL; fi

log_notice "${SELF_IDENTITY_H}: Configuring Iptables"
$(which iptables) -t nat -C POSTROUTING -o eth0 -s ${STACK_VAR_VPCCIDR} -j MASQUERADE 2> /dev/null
RETURNVAL="$?"
if [ ${RETURNVAL} -ne 0 ]; then
    log ">> Iptables rule for Masquerade does not exist, attempting to create"
    $(which iptables) -t nat -A POSTROUTING -o eth0 -s ${STACK_VAR_VPCCIDR} -j MASQUERADE
    RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $E_OBJECT_FAILED_TO_CREATE; fi
else
    log ">> Iptables rule for Masquerade already exists, skipping"
fi
$(which iptables-save) > /etc/sysconfig/iptables

log_notice "${SELF_IDENTITY_H}: Setting Kernel Parameters"
cat << EOF > /etc/sysctl.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.eth0.send_redirects = 0
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.default.accept_source_route = 0
kernel.sysrq = 0
kernel.core_uses_pid = 1
net.ipv4.tcp_syncookies = 1
net.bridge.bridge-nf-call-ip6tables = 0
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-arptables = 0
kernel.msgmnb = 65536
kernel.msgmax = 65536
kernel.shmmax = 68719476736
kernel.shmall = 4294967296
EOF
$(which sysctl) -p >/dev/null 2>/dev/null
call_sleep 3
$(which sysctl) -p >/dev/null 2>/dev/null


ec2_vpc_route_update "${STACK_VAR_ROUTETABLEPRIVATEID}" "${AWS_INFO_INSTANCE_ID}" "${AWS_INFO_REGION}"
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $RETURNVAL; fi

call_sleep 10
sync_disks

## END Execution
##-----------------------------------------------------------------------------------------------------------------------------------------

log_success "${SELF_IDENTITY_H}: Finished"
exit_logic 0
