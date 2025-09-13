#!/data/data/com.termux/files/usr/bin/bash

baseDestFolder="$1"

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$(cd $BASEDIR && pwd)"
SCRIPT_NAME=$(basename "$0")

NOTIFICATION=termux-scripts-backupAllUserApps
# shellcheck source=./backup-lib.sh
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"

function handleFailure() {
  exit_code=$?
  content="Failed after backing up $(( index+1 ))/${nUserApps} apps in $(printSeconds).
  At ${packageName}.
  Tap to see log"
  termux-notification --id "${NOTIFICATION}" \
    --title "Failed backing up apps" \
    --content "${content}" \
    --action "xdg-open ${LOG_FILE}"
  exit $exit_code
}

init "$@"
  
function main() {

  nAppsBackedUp=0
  nAppsIgnored=0

  trap handleFailure ERR SIGINT SIGTERM

  # subshell turns line break to space -> array
  # array allows for using for loop, which does not rely on stdin
  # (other than "while read -r", which leads to end of loop after first iteration)
  packageNames=( $(sudo pm list packages -3) )

  nUserApps=${#packageNames[@]}
  info "Backing up all ${nUserApps} user-installed apps to ${baseDestFolder}$([[ -n "${EXCLUDE_PACKAGES}" ]] && echo ". Excluding ${EXCLUDE_PACKAGES}")"

  # Sort for deterministic order
  readarray -t sortedPackageNames < <(printf '%s\n' "${packageNames[@]}" | sort)
  info "Backing the following packages in order of appearance: ${sortedPackageNames[*]}"
  
  start='true'
  if [[ -n "${START_AT_PACKAGE}" ]]; then
    start='false'
  fi
  
  for index in "${!sortedPackageNames[@]}"; do
    packageName="${sortedPackageNames[index]}"
    
    rawPackageName="${sortedPackageNames[index]}"
    packageName="${rawPackageName/package:/}"
    
    if [[ "${packageName}" == "${START_AT_PACKAGE}" ]]; then
        start='true'
        echo "Found start-at package, starting backup: ${START_AT_PACKAGE}"
    fi
    
    if ! isExcludedPackage "${packageName}" && [[ "${start}" == 'true' ]]; then
      local amount=$(( index+1 ))/${nUserApps}
      info "Backing up app ${amount}: ${packageName} to ${baseDestFolder}"
      termux-notification --id "${NOTIFICATION}" --title "Backing up apps" \
                --content "${amount}: ${packageName}" --priority low
            # priority low avoids vibration/sound on each app
            
      backupApp "${packageName}" "${baseDestFolder}" 
      nAppsBackedUp=$(( nAppsBackedUp + 1 ))
    else
      nAppsIgnored=$(( nAppsIgnored + 1))
      if [[ -n "${START_AT_PACKAGE}" ]]; then
        echo "Skipped app ${packageName} because start-at package not reached: ${START_AT_PACKAGE}"
      fi
    fi
  done

  info "Finished backing up apps"
  content="${nAppsBackedUp} / ${nUserApps} (skipped ${nAppsIgnored})
  user apps backed up successfully in $(printSeconds).
  Tap to see log"
  termux-notification --id "${NOTIFICATION}" --title "Finished backing up apps" \
    --content "${content}" \
    --action "xdg-open ${LOG_FILE}"
}


main "$@"
