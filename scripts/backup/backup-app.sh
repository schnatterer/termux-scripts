#!/data/data/com.termux/files/usr/bin/bash
if [[ -n "${DEBUG}" ]]; then set -x; fi
set -o errexit -o nounset -o pipefail

packageName="$1"
baseDestFolder="$2/$1"
RSYNC_EXTRA_ARG=${RSYNC_EXTRA_ARG:-''}

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$( cd $BASEDIR && pwd )"
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"

function main() {
  echo "Backing up app $packageName to $baseDestFolder"

  backup "/data/data/$packageName"

  backup "/sdcard/Android/data/$packageName"

  # Backup all APKs from path (can be multiple for split-apks!)
  apkPath=$(dirname "$(sudo pm path "$packageName" | head -n1 | sed 's/package://')")
  # Only sync APKs, libs, etc are extracted during install
  doRsync "$apkPath/" "$baseDestFolder/" -m --include='*/' --include='*.apk' --exclude='*'

  termux-notification --id backupApps --title "Finished backing up app" --content "$packageName to $baseDestFolder"
}

function backup() {
  srcFolder="$1"
  actualDestFolder="${baseDestFolder}/${srcFolder}"
  if [[ -d "${srcFolder}" ]]; then
    echo "Sycing ${srcFolder} to ${actualDestFolder}"
    doRsync "${srcFolder}/" "${actualDestFolder}"
  fi
}

main "$@"
