function doRsync() {
  src="$1"
  dst="$2"

  mkdir -p "$dst"
  sudo rsync --human-readable --archive --stats ${RSYNC_EXTRA_ARG} "$src" "$dst"
}
