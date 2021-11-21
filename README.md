termux-scripts
====

Automate everything on your android phone using [termux app](https://github.com/termux/termux-app).

## Changelog

Note that starting with [commit 3586230](https://github.com/schnatterer/termux-scripts/commit/3586230) the folder 
structure is simplified (see [#9](https://github.com/schnatterer/termux-scripts/issues/9)).
Starting from there, backups made with older versions can no longer be restored. BUT:
 * Your backup will be migrated to the new structure automatically on the first backup
 * If you still need to restore an old backup, you can either
   * use an older version of this repo or
   * easily adapt to the new folder structure manually, move e.g.  
     `org.kde.kdeconnect_tp/data/data/org.kde.kdeconnect_tp` to `org.kde.kdeconnect_tp/data/`  
     and  
     `org.kde.kdeconnect_tp/sdcard/Android/data/org.kde.kdeconnect_tp` to `org.kde.kdeconnect_tp/sdcard/`

## Backup and Restore

* Incremental back up and restore 
  * APK (also works with split APKs), 
  * `/data/data/...` folder,
  * and `/sdcard/Android/...` folder
* either locally on your phone or remotely via SSH (via `rsync`) or to the cloud (via [`rclone`](https://rclone.org/#providers)) 
* Requires 
  * *root* access (`su`),
  * [termux:API app](https://github.com/termux/termux-api)
* **Note that these scripts only backup user apps and data**.  
  I recommend backing up at least the following in addition:
  * `/sdcard`
  * `/data/system_ce/0/accounts_ce.db` Accounts
  * `/data/data/com.android.providers.telephony/databases` SMS/MMS
  * `/data/data/com.android.providers.contacts/databases/` call logs
  * `/data/misc/keystore` - see [#7](https://github.com/schnatterer/termux-scripts/issues/7)
  * Wifi Connections and Bluetooth pairings. Please [tell me how](https://github.com/schnatterer/termux-scripts/issues/new).

### Preparation

* For local backup only, the packages mentioned bellow are needed
* For backing up to via SSH, yo need a key in your termux and the appropriate public key added 
  to `authorized_keys` on the target device
* For backing up to the cloud, you need to configure an `rclone` remote. See [`--rclone` option](#options)

```shell
# Install packages
apt install termux-api tsu
# Either install
apt install rsync
# or
apt install rclone

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
* `rsync` is used by default for local backup or via SSH. You can opt in to use `rclone` (see [options](#options)).
* restore will not uninstall an app if it exists. Downgrade or signature mismatch might lead to failure.
* for now, **restore will likely fail for apps that use an android keystore**. If you backed up `/data/misc/keystore`, 
 you can restore it manually, though. See [#7](https://github.com/schnatterer/termux-scripts/issues/7).
* restoring locally might only work from "tmux'" folders or `/data/local/tmp/`, not from `/sdcard`.  
  There are reports of errors such as this:
  ```
  System server has no access to read file context u:object_r:sdcardfs:s0 (from path /storage/emulated/0...base.apk, context u:r:system_server:s0)
  Error: Unable to open file: base.apk
  ```

#### Usage examples

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
# Restores all apps from a folder (except termux, because this would cancel restore process! See bellow)
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
* `--exclude-packages` (for `backup-all-user`, `restore-all`) semicolon separated wildcards (globbing expressions) of  
  app package names to exclude. e.g. 
  ```shell
  # Note that --exclude-packages=... won't work
  --exclude-packages 'net.oneplus.*;com.oneplus.*;com.android.vending.*'
  ```
* `--rclone` - use `rclone` instead of `rsync`  
  * `rclone` supports [dozens of cloud providers](https://rclone.org/#providers), local, ssh, etc. Each can be combined with deduplication, encryption, etc. 
  * Set up your remote with `sudo rclone config`. Why `sudo`? Because the backup is also executed with `sudo` to be able to access folders like `/data/data`, etc. 
  * When backing up to the cloud I recommend to add an encrypted remote and use it for backing up
  * Backups can then be triggered like so, for example
  ```shell
  ./backup-all-user.sh --rclone encrypted-remote:/my/folder/backup/backup
  ```
  * Note: `--rclone` ignores `SSH_*` env vars, but passes on `RSYNC_ARGS`. Maybe this will be renamed to `SYNC_ARGS` one day.

### Limitations

* restoring APKs from a phone that has a different CPU architecture might not work (e.g. armv7 vs armv8/aarch64)
* rsync is run with `--delete` by default. So it deletes files that have been deleted in the source *per app* but
  does not delete apps that have been deleted. This is defensive but might clutter your backup over time.
  If you want a list of apps that are in backup but not installed ont the phone, try the following in termux:

```shell
REMOTE_APPS=$(mktemp)
ssh user@backup-host ls /app/backup/folder | sort > $REMOTE_APPS

sudo bash -c  "comm -13  <(ls /data/data | sort) $REMOTE_APPS"
```

## Default excludes

By default a number of folders (caching, temp, trackers, etc.) are excluded to speed up backup and restore. 
See [rclone-data-filter.txt](scripts/backup/rclone-data-filter.txt) for details.