#!/data/data/com.termux/files/usr/bin/bash

rootSrcFolder="$1"

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$(cd $BASEDIR && pwd)"
SCRIPT_NAME=$(basename "$0")

NOTIFICATION=termux-scripts-restoreAllUserApps
# shellcheck source=./backup-lib.sh
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"

function handleFailure() {
  exit_code=$?
  content="Failed after restoring $(( index+1 ))/${nApps} apps in $(printSeconds).
  At ${packageName}.
  Tap to see log"
  termux-notification --id "${NOTIFICATION}" \
    --title "Failed restoring apps" \
    --content "${content}" \
    --action "xdg-open ${LOG_FILE}"
  exit $exit_code
}

init "$@"

function main() {
  nAppsRestored=0
  nAppsIgnored=0
  
trap handleFailure ERR SIGINT SIGTERM

  if [[ "${rootSrcFolder}" == *:* ]] && [[ "${RCLONE}" != 'true' ]]; then
    # e.g. ssh user@host ls /a/b/c
    # subshell turns line break to space -> array
    packageNames=( $(sshFromEnv "$(removeDirFromSshExpression "${rootSrcFolder}")" "ls $(removeUserAndHostNameFromSshExpression "${rootSrcFolder}")" ) )
  elif [[ "${RCLONE}" == 'true' ]]; then
    # remove trailing slashes
    packageNames=( $(rclone lsf "${rootSrcFolder}" | sed 's:/*$::') )
  else
    packageNames=( $(ls "${rootSrcFolder}") )
  fi

  nApps=${#packageNames[@]}
  info "Restoring all ${nApps} apps from folder ${rootSrcFolder}$([[ -n "${EXCLUDE_PACKAGES}" ]] && echo ". Excluding ${EXCLUDE_PACKAGES}")"

  # Sort for deterministic order
  readarray -t sortedPackageNames < <(printf '%s\n' "${packageNames[@]}" | sort)
  
  start='true'
  if [[ -n "${START_AT_PACKAGE}" ]]; then
    start='false'
  fi
  
  for index in "${!sortedPackageNames[@]}"; do
    packageName="${sortedPackageNames[index]}"
    
    if [[ "${packageName}" == "${START_AT_PACKAGE}" ]]; then
        start='true'
        echo "Found start-at package, starting restore: ${START_AT_PACKAGE}"
    fi
    
    if [[ "${packageName}" != 'com.termux' ]]; then 
      if [[ "$start" == 'true' ]]; then 
        
        srcFolder="${rootSrcFolder}/${packageName}"
        local amount="$(( index+1 ))/${nApps}"
        info "Restoring app ${amount}: ${packageName} from ${srcFolder}"
        termux-notification --id "${NOTIFICATION}" --title "Restoring apps" \
            --content "${amount}: ${packageName}" --priority low
        # priority low avoids vibration/sound on each app

        restoreApp "${srcFolder}"
        nAppsRestored=$(( nAppsRestored + 1))
      else
        nAppsIgnored=$(( nAppsIgnored + 1))
        if [[ -n "${START_AT_PACKAGE}" ]]; then
          echo "Skipped app ${packageName} because start-at package not reached: ${START_AT_PACKAGE}"
        fi
      fi
    else
      nAppsIgnored=$(( nAppsIgnored + 1))
      echo "WARNING: Skipping restore of termux app, as this would break this restore all loop."
    fi
  done

  info "Finished restoring apps"
  content="${nAppsRestored} / ${nApps} (skipped ${nAppsIgnored}) apps
  restored successfully in $(printSeconds).
  Tap to see log"
  termux-notification --id "${NOTIFICATION}" --title "Finished restoring apps" \
    --content "${content}" \
    --action "xdg-open ${LOG_FILE}"
}

main "$@"
