#!/data/data/com.termux/files/usr/bin/bash
if [[ -n "${DEBUG}" ]]; then set -x; fi
set -o errexit -o nounset -o pipefail

packageName="$1"
destFolder="$2/$1"
RSYNC_EXTRA_ARG=${RSYNC_EXTRA_ARG:-''}

function main() {
  echo "Backing up app $packageName to $destFolder"

  mkdir  -p "$destFolder/data/data/$packageName"
  doRsync "/data/data/$packageName" "$destFolder/data/data/"

  if [[ -f "/sdcard/Android/data/$packageName" ]]; then
    mkdir  -p "$destFolder/sdcard/Android/data/$packageName"
    doRsync "/sdcard/Android/data/$packageName" "$destFolder/sdcard/Android/data/"
  fi

  # TODO split APKs return multiple APKs.
  # Realize backup and restore for them
  # How to restore? Reinstalling base.apk alone leads to app crashing with 
  # AndroidRuntime: Caused by: java.lang.NullPointerException: Attempt to invoke interface method &apos;boolean com.google.android.play.core.missingsplits.a.a()&apos; on a null object reference 
  apkPath=$(sudo pm path "$packageName" | head -n1 | sed 's/package://')
  doRsync "$apkPath" "$destFolder/"

  termux-notification --id backupApps --title  "Finished backing up app" --content "$packageName to $destFolder"
}

function doRsync() {
  src="$1"
  dst="$2"
  sudo rsync --human-readable --archive --stats ${RSYNC_EXTRA_ARG} "$src" "$dst"
}

main "$@"
