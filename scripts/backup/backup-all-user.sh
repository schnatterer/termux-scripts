#!/data/data/com.termux/files/usr/bin/bash

baseDestFolder="$1"

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$(cd $BASEDIR && pwd)"
SCRIPT_NAME=$(basename "$0")

# shellcheck source=./backup-lib.sh
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"
init "$@"

function main() {
  nAppsBackedUp=0
  nAppsIgnored=0


  trap '[[ $? > 0 ]] && (set +o nounset; termux-notification --id backupAllUserApps --title "Failed backing up apps" --content "Failed after backing up $nAppsBackedUp / $nUserApps apps in $(printSeconds). Tap to see log" --action "xdg-open ${LOG_FILE}")' EXIT

  # subshell turns line break to space -> array
  # array allows for using for loop, which does not rely on stdin
  # (other than "while read -r", which leads to end of loop after first iteration)
  packageNames=( $(sudo pm list packages -3) )

  nUserApps=${#packageNames[@]}
  info "Backing up all ${nUserApps} user-installed apps to ${baseDestFolder}$([[ -n "${EXCLUDE_PACKAGES}" ]] && echo ". Excluding ${EXCLUDE_PACKAGES}")"

  # Sort for deterministic order
  readarray -t sortedPackageNames < <(printf '%s\n' "${packageNames[@]}" | sort)
  
  start='true'
  if [[ -n "${START_AT_PACKAGE}" ]]; then
    start='false'
  fi
  
  for index in "${!sortedPackageNames[@]}"; do
    packageName="${sortedPackageNames[index]}"
    
    rawPackageName="${packageNames[index]}"
    packageName="${rawPackageName/package:/}"
    
    if [[ "${packageName}" == "${START_AT_PACKAGE}" ]]; then
        start='true'
        echo "Found start-at package, starting backup: ${START_AT_PACKAGE}"
    fi
    
    if ! isExcludedPackage "${packageName}" && [[ "${start}" == 'true' ]]; then
      info "Backing up app $(( index+1 ))/${nUserApps}: ${packageName} to ${baseDestFolder}"
      
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
  termux-notification --id backupAllUserApps --title "Finished backing up apps" \
    --content "$(echo -e "${nAppsBackedUp} / ${nUserApps} (skipped ${nAppsIgnored}) user apps\nbacked up successfully\nin $(printSeconds)")" \
    --action "xdg-open ${LOG_FILE}"
}

main "$@"
