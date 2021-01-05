#!/data/data/com.termux/files/usr/bin/bash
if [[ -n "${DEBUG}" ]]; then set -x; fi
set -o errexit -o nounset -o pipefail

srcFolder="$1"
# For now just assume folder name = package name. Reading from apk would be more defensive... and effort.
packageName=${srcFolder##*/}
RSYNC_EXTRA_ARG=${RSYNC_EXTRA_ARG:-''}

function main() {
  echo "Restoring app $packageName from $srcFolder"

  echo "installing APK $srcFolder/base.apk"
  sudo pm install "$srcFolder/base.apk"

  user=$(stat -c '%U' "/data/data/$packageName")
  group=$(stat -c '%G' "/data/data/$packageName")

  echo "restoring data to /data/data/$packageName"
  doRsync "$srcFolder/data/data/$packageName" /data/data/
  echo "fixing owner/group $user:$group in /data/data/$packageName"
  sudo chown -R "$user:$group" "/data/data/$packageName"
  
  if [[ -f "$srcFolder/sdcard/Android/data/$packageName" ]]; then
    echo "restoring data to /sdcard/Android/data/$packageName"
    doRsync "$srcFolder/sdcard/Android/$packageName" "/sdcard/Android/"
    echo "fixing owner/group $user:$group in /sdcard/Android/data/$packageName"
    sudo chown -R "$user:$group" "/sdcard/Android/data/$packageName"
  fi
  
  termux-notification --id restoreApps --title  "Finished restoring  app" --content "$packageName from $srcFolder"
}

function doRsync() {
  src="$1"
  dst="$2"
  sudo rsync --human-readable --archive --stats  ${RSYNC_EXTRA_ARG} "$src" "$dst"
}

main "$@"
