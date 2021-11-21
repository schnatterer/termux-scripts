#!/data/data/com.termux/files/usr/bin/bash

rootSrcFolder="$1"

BASEDIR=$(dirname $0)
ABSOLUTE_BASEDIR="$(cd $BASEDIR && pwd)"
source "${ABSOLUTE_BASEDIR}/backup-lib.sh"
init "$@"

info "Restoring app ${rootSrcFolder##*/} from ${rootSrcFolder}"
restoreApp "${rootSrcFolder}"

termux-notification --id restoreApps --title "Finished restoring  app" --content "From ${rootSrcFolder}"
