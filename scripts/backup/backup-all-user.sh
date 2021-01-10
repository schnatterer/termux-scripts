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
  trap '[[ $? > 0 ]] && termux-notification --id backupAllUserApps --title "Failed backing up apps" --content "See log" --action "xdg-open ${LOG_FILE}"' EXIT

  packageNames=$(sudo pm list packages -3)
  nUserApps=$(echo "${packageNames}" | wc -l)
  echo "Backing up all ${nUserApps} user-installed apps to ${baseDestFolder}"

  while IFS= read -r rawPackageName; do
    packageName="${rawPackageName/package:/}"
    backupApp "${packageName}" "${baseDestFolder}"
  done <<< "${packageNames}"
  # TODO why is this ending after the first app?!

  termux-notification --id backupAllUserApps --title "Finished backing up apps" --content "All ${nUserApps} user apps" --action "xdg-open ${LOG_FILE}"
}

main "$@"
