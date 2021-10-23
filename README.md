termux-scripts
====

Automate everything on your android phone using [termux app](https://github.com/termux/termux-app).

## Backup and Restore

* Incremental back up and restore 
  * APK (also works with split APKs), 
  * `/data/data/...` folder,
  * and `/sdcard/Android/...` folder
* either locally on your phone or remotely via SSH 
* Requires 
  * *root* access (`su`),
  * [termux:API app](https://github.com/termux/termux-api)

### Preparation

* For local backup only, the packages mentioned bellow are needed
* For backing up to a remote target you need to have private SSH key in your termux and the appropriate public key added 
  to `authorized_keys` on the target device

```shell
# Install packages
apt install rsync termux-api tsu

# Fore remote backups, set up key
ssh-keygen -t ecdsa -b 521
# Copy key to the remote machine. Password authentication has to be enabled in order to install pubkey on remote machine.
ssh-copy-id -p 22223 -i id_rsa user@host
```

### Usage

Start the script.
On finish an android notification displays the result.
Tapping the notification will open the log file.

Note that
* restore will not uninstall an app if it exists. Downgrade or signature mismatch might lead to failure.
* restoring locally might only work from "tmux'" folders or `/data/local/tmp/`, not from `/sdcard`.  
  There are reports of errors such as this:
```
System server has no access to read file context u:object_r:sdcardfs:s0 (from path /storage/emulated/0...base.apk, context u:r:system_server:s0)
Error: Unable to open file: base.apk
```

```shell
# Find out package name
sudo pm list packages | grep tag

# Local roundtrip
./backup-app.sh com.nxp.taginfolite . # Backup to ./com.nxp.taginfolite
./restore-app.sh com.nxp.taginfolite  # Restore from ./com.nxp.taginfolite

# Remote roundtrip
# If not set the default port (22) is used
export SSH_PORT=22223
# If not set the default key is used
export SSH_PK="$HOME/.ssh/my-non-default-key"
# If not set, the default is used
export SSH_HOST_FILE="$HOME/somewhere/known_hosts"
# optional
export RSYNC_ARGS='--progress --stats'
export LOG_LEVEL='INFO' # Options: TRACE, INFO WARN, OFF. Default: INFO 

# Backup and restore individual apps
./backup-app.sh com.nxp.taginfolite user@host:/my/folder/backup # Backup to /my/folder/backup/com.nxp.taginfolite
./restore-app.sh user@host:/my/folder/backup/com.nxp.taginfolite

# Batch backup
# Backup all user apps (might be several hundreds!)
./backup-all-user.sh user@host:/my/folder/backup/backup
# Restores all apps from a folder (except termux, because this would cancel restore process!)
./restore-all.sh user@host:/my/folder/backup/
# Restore termux separately, if necessary
./restore-app.sh com.nxp.taginfolite user@host:/backup/my/folder/backup
```

### Options

* `-a / --apk` - backup/restore APK only
* `-d / --data` - backup/restore data only

Note that `RSYNC_ARGS='--delete' backup-all-user.sh` deletes files that have been deleted in the source *per app* but 
does not delete apps that have been deleted. This is defensive but might clutter your backup over time.
If you want a list of apps that are in backup but not installed ont the phone, try the following in termux:

```shell
REMOTE_APPS=$(mktemp)
ssh user@backup-host ls /app/backup/folder | sort > $REMOTE_APPS

sudo bash -c  "comm -13  <(ls /data/data | sort) $REMOTE_APPS"
```

### Limitations

Note that restoring APKs from a phone that has a different CPU architecture might not work (e.g. armv7 vs armv8/aarch64)

### TODO
* Exclude folders
* Backup/restore multiple packages
* logfile off
* Log errors in color