#!/bin/bash
###------------------------------------------------------------------------------------------------
# application: Infrastructure - NAT
# script:      prepare.sh
# class:       BeforeInstall
# version:     1.0.0
###------------------------------------------------------------------------------------------------

###------------------------------------------------------------------------------------------------
## Config
declare SELF_IDENTITY="codedeploy_prepare"
declare SELF_IDENTITY_H="CodeDeploy (Prepare)"

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
)

###------------------------------------------------------------------------------------------------
## Variables

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

## END Initialize
##-----------------------------------------------------------------------------------------------------------------------------------------

##-----------------------------------------------------------------------------------------------------------------------------------------
## START Execution
line_break
log_highlight "Execution"

# Sanity check to ensure we dont accidentally nuke everything
DIRECTORY_BUNDLE="$(echo "${DIRECTORY_BUNDLE}" | sed 's:/*$::')"
if(is_empty "${DIRECTORY_BUNDLE}"); then
    TMP_ERROR_MSG="Attempted to nuke root filesystem, aborting."
    log_error "${SELF_IDENTITY_H}: ${TMP_ERROR_MSG}"
    exit_logic $E_RESONANCE_CASCADE "${TMP_ERROR_MSG}"
fi
if [ -d "${DIRECTORY_BUNDLE}" ]; then rm -rf ${DIRECTORY_BUNDLE} >/dev/null 2>&1; fi

yum_update_all
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then log_warning "- Failed to perform yum update"; fi

yum_install_packages "YUM_PACKAGES_DEFAULT[@]"
RETURNVAL="$?"; if [ ${RETURNVAL} -ne 0 ]; then exit_logic $RETURNVAL; fi

## END Execution
##-----------------------------------------------------------------------------------------------------------------------------------------

log_success "${SELF_IDENTITY_H}: Finished"
exit_logic 0
