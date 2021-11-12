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
* **Note that these scripts only backup user apps and data**.  
  I recommend backing up at least the following in addition:
  * `/sdcard`
  * `/data/system_ce/0/accounts_ce.db` Accounts
  * `/data/data/com.android.providers.telephony/databases` SMS/MMS
  * `/data/data/com.android.providers.contacts/databases/` call logs
  * `/data/misc/keystore` - see #7
  * Wifi Connections and Bluetooth pairings. How?

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
* for now, **restore will likely fail for apps that use an android keystore**. If you backed up `/data/misc/keystore`, 
 you can restore it manually, though. See #7.
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
# Dont forget to backup /sdcard, /data/misc/keystore, etc. in addition (see above)
./backup-all-user.sh user@host:/my/folder/backup/backup
# Restores all apps from a folder (except termux, because this would cancel restore process!)
# It the app does not work as expected after restore, consider restoring the keystore (see above)
./restore-all.sh user@host:/my/folder/backup/

# Restore termux separately, if necessary
pkg install rsync
# Uncomment if not needed
#RSYNC_ARGS=-e "ssh -p 22222 -i $HOME/.ssh/mykey"
rsync --stats --progress --human-readable -r --times $RSYNC_ARGS user@host:/my/folder/backup/com.termux/data/data/com.termux/files/home/ ~
rsync --stats --progress --human-readable -r --times $RSYNC_ARGS user@host:/my/folder/backup/com.termux/data/data/com.termux/files/usr/ ../usr
# Packages are there but don't seem to work, so install them again
for pkg in `dpkg --get-selections | awk '{print $1}' | egrep -v '(dpkg|apt|mysql|mythtv)'` ; do apt-get -y --force-yes install --reinstall $pkg ; done
# If you have been using a different shell, re-enable it, for example:
#chsh -s zsh
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
* Exclude folders (e.g. code_cache)
* Backup/restore multiple (but not all) packages
* logfile off
* Log errors in color