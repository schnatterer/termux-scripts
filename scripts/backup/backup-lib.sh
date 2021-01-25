function backupApp() {
  local packageName="$1"
  local baseDestFolder="$2/$1"

  echo "Backing up app $packageName to $baseDestFolder"

  backupFolder "/data/data/$packageName"

  backupFolder "/sdcard/Android/data/$packageName"

  # Backup all APKs from path (can be multiple for split-apks!)
  apkPath=$(dirname "$(sudo pm path "$packageName" | head -n1 | sed 's/package://')")
  # Only sync APKs, libs, etc are extracted during install
  doRsync "$apkPath/" "$baseDestFolder/" -m --include='*/' --include='*.apk' --exclude='*'
}

function backupFolder() {
  srcFolder="$1"
  actualDestFolder="${baseDestFolder}/${srcFolder}"
  if [[ -d "${srcFolder}" ]]; then
    echo "Sycing ${srcFolder} to ${actualDestFolder}"
    doRsync "${srcFolder}/" "${actualDestFolder}"
  fi
}

function doRsync() {
  src="$1"
  dst="$2"
  additionalArgs=("$@")
  # Treat all args after src and dst as addition rsync args
  additionalArgs=${additionalArgs[@]:2}
  remoteShellArgs=''

  if [[ "${src}" == *:* ]] || [[ "${dst}" == *:* ]]; then
    remoteShellArgs=('ssh')
    set +o nounset
    [[ -n "$SSH_PORT" ]] && remoteShellArgs+=("-p $SSH_PORT")
    [[ -n "$SSH_PK" ]] && remoteShellArgs+=("-i $SSH_PK")
    [[ -n "$SSH_HOST_FILE" ]] && remoteShellArgs+=("-o UserKnownHostsFile=$SSH_HOST_FILE")
    set -o nounset

    # ssh user@host 'mkdir -p /a/b/c'
    eval "${remoteShellArgs[*]} $(removeDirFromSshExpression "${dst}") 'mkdir -p $(removeUserAndHostNameFromSshExpression "${dst}")'"
  else
    mkdir -p "${dst}"
  fi

  sudo time rsync \
    --human-readable --archive --stats \
    "--rsh=${remoteShellArgs[*]}" \
    $(rsyncShowOptionalProgress) \
    ${additionalArgs} \
    "${src}" "${dst}"
}

function rsyncShowOptionalProgress() {
  # Run Jenkins and Agent pods as the current user.
  # Avoids file permission problems when accessing files on the host that were written from the pods
  set +o nounset
  [[ "${RSYNC_PROGRESS}" == "true" ]] && echo "--progress"
  set -o nounset
}

# Example:
# user@host:/a/b/c
# to
# user@host
function removeDirFromSshExpression() {
  # shellcheck disable=SC2001
  # "Occasionally a more complex sed substitution is required."
  sed 's/\(.*\):.*/\1/' <<<"$1"
}

# Example:
# user@host:/a/b/c
# to
# /a/b/c
function removeUserAndHostNameFromSshExpression() {
  # shellcheck disable=SC2001
  # "Occasionally a more complex sed substitution is required."
  sed 's/.*:\(.*\)/\1/' <<<"$1"
}

function installMultiple() {
  # Note:
  # * A newer alternative to "pm" seems to be "pm"
  # * It prints a help dialog by just calling "pm" (--help does not work)
  apkFolder="$1"
  (
    cd "${apkFolder}"
    totalApkSize=0
    for apk in *.apk; do
      size=$(wc -c "${apk}" | awk '{print $1}')
      totalApkSize=$((totalApkSize + size))
    done

    echo "Creating install session for total APK size ${totalApkSize}"
    installCreateOutput=$(sudo pm install-create -S ${totalApkSize})
    sessionId=$(echo "${installCreateOutput}" | grep -E -o '[0-9]+')

    echo "Installing apks in session $sessionId"
    for apk in *.apk; do
      size=$(wc -c "${apk}" | awk '{print $1}')
      echo "Writing ${apk} (size ${size}) to session ${sessionId}"
      # install-write [-S BYTES] SESSION_ID SPLIT_NAME [PATH|-]
      #  Write an apk into the given install session.  If the path is '-', data will be read from stdin
      sudo pm install-write -S "${size}" "${sessionId}" "${apk}" "${apk}"
    done

    echo "Committing session ${sessionId}"
    sudo pm install-commit "${sessionId}"
  )
}
