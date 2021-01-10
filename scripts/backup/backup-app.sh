#!/data/data/com.termux/files/usr/bin/bash
if [[ -n "${DEBUG}" ]]; then set -x; fi
set -o errexit -o nounset -o pipefail

packageName="$1"
baseDestFolder="$2"

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$(cd $BASEDIR && pwd)"
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"

backupApp "${packageName}" "${baseDestFolder}"

termux-notification --id backupApps --title "Finished backing up app" --content "$packageName to $baseDestFolder"
