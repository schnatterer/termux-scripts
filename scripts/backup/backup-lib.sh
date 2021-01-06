function doRsync() {
  src="$1"
  dst="$2"
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
  
  sudo rsync \
    --human-readable --archive --stats \
    $([[ ${#remoteShellArgs[@]} -ne 0 ]] && echo --rsh=\"${remoteShellArgs[*]}\") "${src}" "${dst}"
}

# Example:
# user@host:/a/b/c
# to
# user@host
function removeDirFromSshExpression() {
  # shellcheck disable=SC2001 
  # "Occasionally a more complex sed substitution is required." 
  sed 's/\(.*\):.*/\1/' <<< "$1"
}

# Example:
# user@host:/a/b/c
# to
# /a/b/c
removeUserAndHostNameFromSshExpression() {
  # shellcheck disable=SC2001 
  # "Occasionally a more complex sed substitution is required." 
  sed 's/.*:\(.*\)/\1/' <<< "$1"
}