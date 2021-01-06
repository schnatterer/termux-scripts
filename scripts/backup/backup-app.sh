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

  # TODO split APKs return multiple APKs.
  # Realize backup and restore for them
  # How to restore? Reinstalling base.apk alone leads to app crashing with
  # AndroidRuntime: Caused by: java.lang.NullPointerException: Attempt to invoke interface method &apos;boolean com.google.android.play.core.missingsplits.a.a()&apos; on a null object reference
  apkPath=$(sudo pm path "$packageName" | head -n1 | sed 's/package://')
  doRsync "$apkPath" "$baseDestFolder/"

  termux-notification --id backupApps --title "Finished backing up app" --content "$packageName to $baseDestFolder"
}

function backup() {
  srcFolder="$1"
  actualDestFolder="${baseDestFolder}/${srcFolder}"
  if [[ -f "${srcFolder}" ]]; then
    echo "Sycing ${srcFolder} to ${actualDestFolder}"
    mkdir -p "${actualDestFolder}"
    doRsync "${srcFolder}" "${actualDestFolder}"
  fi
}

main "$@"
