#!/data/data/com.termux/files/usr/bin/bash

baseDestFolder="$1"

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$(cd $BASEDIR && pwd)"
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"
# TODO move the following to lib and init method?
if [[ -n "${DEBUG}" ]]; then set -x; fi

# Almost no android app seems to register for opening ".log" files. So use a more common ending.
LOG_FILE=${LOG_FILE:-"$(mktemp --suffix=.txt)"}
echo "Writing output to logfile: ${LOG_FILE}"
exec > >(tee -a ${LOG_FILE})
exec 2> >(tee -a ${LOG_FILE} >&2)

set -o errexit -o nounset -o pipefail

SCRIPT_NAME=$(basename "$0")

function main() {
  trap '[[ $? > 0 ]] && termux-notification --id backupAllUserApps --title "Failed backing up apps" --content "Tap to see log" --action "xdg-open ${LOG_FILE}"' EXIT

  # subshell turns line break to space -> array
  # array allows for using for loop
  # for loop does not rely on stdin
  # other than "while read -r"
  # leading to end of loop after first iteration
  packageNames=($(sudo pm list packages -3))
  nUserApps=$(echo "${packageNames}" | wc -l)
  echo "Backing up all ${nUserApps} user-installed apps to ${baseDestFolder}"
echo "${packageNames[@]}"
  for rawPackageName in "${packageNames[@]}"; do
  #echo "$packageNames" | while IFS= read -r rawPackageName ; do
    packageName="${rawPackageName/package:/}"
    backupApp "${packageName}" "${baseDestFolder}" 
  done
# TODO count and print here!
  termux-notification --id backupAllUserApps --title "Finished backing up apps" --content "All ${nUserApps} user apps" --action "xdg-open ${LOG_FILE}"
}

main "$@"
