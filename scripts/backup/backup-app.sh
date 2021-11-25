#!/data/data/com.termux/files/usr/bin/bash

packageName="$1"
baseDestFolder="$2"

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$(cd $BASEDIR && pwd)"
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"
init "$@"

info "Backing up app ${packageName} to ${baseDestFolder}"
backupApp "${packageName}" "${baseDestFolder}"

termux-notification --id backupApps --title "Finished backing up app" --content "$packageName to $baseDestFolder"
