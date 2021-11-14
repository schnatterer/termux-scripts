function backupApp() {
  local packageName="$1"
  local baseDestFolder="$2/$1"

  info "Backing up app $packageName to $baseDestFolder"

  if [[ "${APK}" != 'true' ]]; then
    backupFolder "/data/data/$packageName"

    backupFolder "/sdcard/Android/data/$packageName"
  fi

  if [[ "${DATA}" != 'true' ]]; then
    # Backup all APKs from path (can be multiple for split-apks!)
    apkPath=$(dirname "$(sudo pm path "$packageName" | head -n1 | sed 's/package://')")
    # Only sync APKs, libs, etc are extracted during install
    # shellcheck disable=SC2046 
    # This might return multiple parameters that we don't want quoted here
    doSync "$apkPath/" "$baseDestFolder/" $(includeOnlyApk)
  fi
}

function backupFolder() {
  srcFolder="$1"
  actualDestFolder="${baseDestFolder}/${srcFolder}"
  additionalArgs=("$@")
  # Treat all args after src and dst as addition rsync args
  additionalArgs=${additionalArgs[@]:1}
  if [[ -d "${srcFolder}" ]]; then
    trace "Syncing ${srcFolder} to ${actualDestFolder}"
    doSync "${srcFolder}/" "${actualDestFolder}" $(excludeCache) ${additionalArgs}
  fi
}

function restoreApp() {
  local rootSrcFolder="$1"
  # For now just assume folder name = package name. Reading from apk would be more defensive... and effort.
  local packageName=${rootSrcFolder##*/}

  info "Restoring app $packageName from $rootSrcFolder"

  if [[ "${DATA}" != 'true' ]]; then
    installMultiple "$rootSrcFolder/"
  fi

  if [[ "${APK}" != 'true' ]]; then
    user=$(stat -c '%U' "/data/data/$packageName")
    group=$(stat -c '%G' "/data/data/$packageName")
  
    restoreFolder "${rootSrcFolder}" "/data/data/${packageName}"
  
    restoreFolder "${rootSrcFolder}" "/sdcard/Android/data/${packageName}"
  fi
}

function restoreFolder() {
  local rootSrcFolder="$1"
  local destFolder="$2"
  local actualSrcFolder="${rootSrcFolder}/${destFolder}"

  actualSourceFolderExists=false
  if [[ "${actualSrcFolder}" == *:* ]]; then
    # ssh '[ -d /a/b/c ]'
    local sshCommand="$(removeDirFromSshExpression "${actualSrcFolder}")"
    local localFolder="$(removeUserAndHostNameFromSshExpression "${actualSrcFolder}")"

    if sshFromEnv "${sshCommand}" "[ -d ${localFolder} ]"; then
      actualSourceFolderExists=true
    fi
  else
    [[ -d "${actualSrcFolder}" ]] && actualSourceFolderExists=true
  fi

  if [[ "${actualSourceFolderExists}" != 'false' ]]; then
    trace "Restoring data to ${destFolder}"
    doSync "${actualSrcFolder}/" "${destFolder}"
    trace "Fixing owner/group ${user}:${group} in ${destFolder}"
    sudo chown -R "${user}:${group}" "${destFolder}"
  else
    info "Backup does not contain folder '${actualSrcFolder}'. Skipping"
  fi
  
}

function excludeCache() {
  if [[ "${RCLONE}" == 'true' ]]; then
    echo "--exclude='/cache/**'"
  else 
    echo "--exclude='cache'"
  fi
}

function includeOnlyApk() {
  if [[ "${RCLONE}" == 'true' ]]; then
    echo "--include='/*.apk"
  else 
    echo "-m --include='*/' --include='*.apk' --exclude='*'"
  fi
}

function doSync() {

  if [[ "${RCLONE}" == 'true' ]]; then
    doRclone "$@"
  else
    doRsync "$@"
  fi

}

function doRclone() {
  src="$1"
  dst="$2"
  additionalArgs=("$@")
  # Treat all args after src and dst as addition rsync args
  additionalArgs=${additionalArgs[@]:2}
  RSYNC_ARGS=${RSYNC_ARGS:-''}

  sudo rclone sync \
    --progress \
    $(rsyncExternalArgs) \
    ${additionalArgs} \
    "${src}" "${dst}"
}

function doRsync() {
  src="$1"
  dst="$2"
  additionalArgs=("$@")
  # Treat all args after src and dst as addition rsync args
  additionalArgs=${additionalArgs[@]:2}
  remoteShellArgs=''
  RSYNC_ARGS=${RSYNC_ARGS:-''}

  if [[ "${dst}" == *:* ]]; then
    # e.g. execViaSsh user@host 'mkdir -p /a/b/c'
    sshFromEnv "$(removeDirFromSshExpression "${dst}")" "mkdir -p $(removeUserAndHostNameFromSshExpression "${dst}")"
  else
    mkdir -p "${dst}"
  fi

  if [[ "${src}" == *:* ]] || [[ "${dst}" == *:* ]]; then
    setRemoteShellArgs
  fi

  sudo rsync \
    --human-readable --archive --times \
    "--rsh=${remoteShellArgs[*]}" \
    $(rsyncExternalArgs) \
    ${additionalArgs} \
    "${src}" "${dst}"
}

function sshFromEnv() {
  userAtHost="$1"
  sshCommand="$2"

  setRemoteShellArgs

  eval "${remoteShellArgs[*]} ${userAtHost} '${sshCommand}'"
}

function setRemoteShellArgs() {
  remoteShellArgs=('ssh')

  set +o nounset
  [[ -n "$SSH_PORT" ]] && remoteShellArgs+=("-p $SSH_PORT")
  [[ -n "$SSH_PK" ]] && remoteShellArgs+=("-i $SSH_PK")
  [[ -n "$SSH_HOST_FILE" ]] && remoteShellArgs+=("-o UserKnownHostsFile=$SSH_HOST_FILE")
  set -o nounset
}

function rsyncExternalArgs() {
  set +o nounset
  echo "${RSYNC_ARGS}"
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
  local apkFolder="$1"

  if [[ "${apkFolder}" == *:* ]]; then
    apkTmp=$(mktemp -d)
    # shellcheck disable=SC2046 
    # This might return multiple parameters that we don't want quoted here
    doSync "$apkFolder/" "$apkTmp/" $(includeOnlyApk)
    apkFolder=$apkTmp
  fi

  (
    cd "${apkFolder}"
    totalApkSize=0
    for apk in *.apk; do
      size=$(wc -c "${apk}" | awk '{print $1}')
      totalApkSize=$((totalApkSize + size))
    done

    trace "Creating install session for total APK size ${totalApkSize}"
    installCreateOutput=$(sudo pm install-create -S ${totalApkSize})
    sessionId=$(echo "${installCreateOutput}" | grep -E -o '[0-9]+')

    trace "Installing apks in session $sessionId"
    for apk in *.apk; do
      size=$(wc -c "${apk}" | awk '{print $1}')
      trace "Writing ${apk} (size ${size}) to session ${sessionId}"
      # install-write [-S BYTES] SESSION_ID SPLIT_NAME [PATH|-]
      #  Write an apk into the given install session.  If the path is '-', data will be read from stdin
      sudo pm install-write -S "${size}" "${sessionId}" "${apk}" "${apk}"
    done

    trace "Committing session ${sessionId}"
    sudo pm install-commit "${sessionId}"
  )
}

function trace() {
  if [[ "${LOG_LEVEL}" == 'TRACE' ]]; then
    __log "$*"
  fi
}

function info() {
  if [[ "${LOG_LEVEL}" =~ ^(TRACE|INFO)$ ]]; then
    __log "$*"
  fi
}

function warn() {
  if [[ "${LOG_LEVEL}" =~ ^(TRACE|INFO|WARN)$ ]]; then
    __log "$*"
  fi  
}

function __log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $*"
}

function enableFileLogging() {
  # Almost no android app seems to register for opening ".log" files. So use a more common ending.
  LOG_FILE=${LOG_FILE:-"$(mktemp --suffix=.txt)"}
  info "Writing output to logfile: ${LOG_FILE}"
  exec > >(tee -a ${LOG_FILE})
  exec 2> >(tee -a ${LOG_FILE} >&2)
}

function printSeconds() {
  echo "$((SECONDS / 3600))h $(((SECONDS / 60) % 60))m $((SECONDS % 60))s"
}

function init() {
  if [[ -n "${DEBUG}" ]]; then set -x; fi
  
  SECONDS=0 # Variable SECONDS will track execution time of the command
  
  LOG_LEVEL=${LOG_LEVEL:-'INFO'}
  if [[ ! "${LOG_LEVEL}" =~ ^(TRACE|INFO|WARN|OFF)$ ]]; then
    echo "WARNING: Unknown Log level '${LOG_LEVEL}'. Defaulting to INFO"
    LOG_LEVEL='INFO'
  fi

  enableFileLogging

  readArgs "$@"

  set -o errexit -o nounset -o pipefail
}

# Read know param and writes them into vars
function readArgs() {
  POSITIONAL_ARGS=()
  DATA=''
  APK=''
  RCLONE=''
  while [[ $# -gt 0 ]]; do
    ARG="$1"
    echo arg=$1

    case ${ARG} in
    -d | --data)
      DATA=true
      shift
      ;;
    -a | --apk)
      APK=true
      shift
      ;;
    --rclone)
      RCLONE=true
      shift
      ;;
    *) # Unknown or positional arg
      POSITIONAL_ARGS+=("$1")
      shift
      ;;
    esac
  done
}
