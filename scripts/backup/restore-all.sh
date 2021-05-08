#!/data/data/com.termux/files/usr/bin/bash

rootSrcFolder="$1"

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$(cd $BASEDIR && pwd)"
SCRIPT_NAME=$(basename "$0")

# shellcheck source=./backup-lib.sh
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"
init "$@"

function main() {
  nAppsRestored=0

  trap '[[ $? > 0 ]] && (set +o nounset; termux-notification --id restoreAllApps --title "Failed restoring apps" --content "Failed after restoring $nAppsRestored / $nApps apps in $(printSeconds). Tap to see log" --action "xdg-open ${LOG_FILE}")' EXIT

  if [[ "${rootSrcFolder}" == *:* ]]; then
    # e.g. ssh user@host ls /a/b/c
    # subshell turns line break to space -> array
    packageNames=( $(sshFromEnv "$(removeDirFromSshExpression "${rootSrcFolder}")" "ls $(removeUserAndHostNameFromSshExpression "${rootSrcFolder}")" ) )
  else
    packageNames=( $(ls "${rootSrcFolder}") )
  fi

  nApps=${#packageNames[@]}
  info "Restoring all ${nApps} apps from folder ${rootSrcFolder}"

  for packageName in "${packageNames[@]}"; do
    if [[ "${packageName}" != 'com.termux' ]]; then 
      srcFolder="${rootSrcFolder}/${packageName}"
      restoreApp "${srcFolder}"
    else
      echo "WARNING: Skipping restore of termux app, as this would break this restore all loop."
    fi
    nAppsRestored=$(( nAppsRestored + 1))
  done

  info "Finished restoring apps"
  termux-notification --id restoreAllApps --title "Finished restoring apps" \
    --content "Restored ${nAppsRestored} / ${nApps} user apps successfully in $(printSeconds)" --action "xdg-open ${LOG_FILE}"
}

main "$@"
