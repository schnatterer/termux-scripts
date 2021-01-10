#!/data/data/com.termux/files/usr/bin/bash
if [[ -n "${DEBUG}" ]]; then set -x; fi
set -o errexit -o nounset -o pipefail

rootSrcFolder="$1"
# For now just assume folder name = package name. Reading from apk would be more defensive... and effort.
packageName=${rootSrcFolder##*/}

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$(cd $BASEDIR && pwd)"
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"

function main() {
  echo "Restoring app $packageName from $rootSrcFolder"

  echo "installing APK $rootSrcFolder/base.apk"
  installMultiple "$rootSrcFolder/"

  user=$(stat -c '%U' "/data/data/$packageName")
  group=$(stat -c '%G' "/data/data/$packageName")

  restore "/data/data/$packageName"

  restore "/sdcard/Android/data/$packageName"

  termux-notification --id restoreApps --title "Finished restoring  app" --content "$packageName from $rootSrcFolder"
}

function restore() {
  destFolder="$1"
  actualSrcFolder="${rootSrcFolder}/${destFolder}"

  if [[ -d "${actualSrcFolder}" ]]; then
    echo "restoring data to ${destFolder}"
    doRsync "${actualSrcFolder}/" "${destFolder}"
    echo "fixing owner/group ${user}:${group} in ${destFolder}"
    sudo chown -R "${user}:${group}" "${destFolder}"
  fi
}

main "$@"
