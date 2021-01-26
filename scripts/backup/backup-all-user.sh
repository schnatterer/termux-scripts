#!/data/data/com.termux/files/usr/bin/bash

baseDestFolder="$1"

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$(cd $BASEDIR && pwd)"
SCRIPT_NAME=$(basename "$0")

# shellcheck source=./backup-lib.sh
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"
init

function main() {
  nAppsBackedUp=0

  trap '[[ $? > 0 ]] && (set +o nounset; termux-notification --id backupAllUserApps --title "Failed backing up apps" --content "Failed after backing up $nAppsBackedUp / $nUserApps apps in $(printSeconds).\n Tap to see log" --action "xdg-open ${LOG_FILE}")' EXIT

  # subshell turns line break to space -> array
  # array allows for using for loop, which does not rely on stdin
  # (other than "while read -r", which leads to end of loop after first iteration)
  packageNames=( $(sudo pm list packages -3) )

  nUserApps=$(sudo pm list packages -3 | wc -l)
  log "Backing up all ${nUserApps} user-installed apps to ${baseDestFolder}"

  for rawPackageName in "${packageNames[@]}"; do
    nAppsBackedUp=$(( ${nAppsBackedUp} + 1 ))
    packageName="${rawPackageName/package:/}"
    backupApp "${packageName}" "${baseDestFolder}" 
  done

  log "Finished backing up apps"
  termux-notification --id backupAllUserApps --title "Finished backing up apps" \
    --content "Backed up ${nAppsBackedUp} / ${nUserApps} user apps successfully in $(printSeconds)" --action "xdg-open ${LOG_FILE}"
}

main "$@"
