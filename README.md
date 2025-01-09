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
  * system apps if needed (browser, e.g. chromium, vanadium, `com.android.launcher3`)
  * `/data/data/com.android.providers.telephony/databases` SMS/MMS (alternatively, you could use [SMS Import / Export](https://github.com/tmo1/sms-ie) to write SMS+call logs and contacts to the filesystem and back them up from there)
  * `/data/data/com.android.providers.contacts/databases/` call logs (maybe also `/data/data/com.android.calllogbackup`)
  * Maybe `/data/data/com.android.providers.settings`
  * Maybe `/data/data/com.android.providers.contacts` (if you're system includes Seedvault, [`org.calyxos.backup.contacts`](https://github.com/seedvault-app/seedvault/tree/9557dfd4e763b8738086f0c39a2d3014e6be8315/contactsbackup) might work as well)
  * Maybe `/data/data/com.android.providers.calenders` (alternatively you could sync them calenders and contacts using [davx5](https://github.com/bitfireAT/davx5-ose) or [MyPhoneExplorer](https://www.fjsoft.at/en/))
  * Wifi Connections and Bluetooth pairings. Please [tell me how](https://github.com/schnatterer/termux-scripts/issues/new).  
    Wifi connections are stored here: `/data/misc/apexdata/com.android.wifi/WifiConfigStore.xml`. Not sure if restoring works from there, though.
  * Note that restoring files to `/data/` might not be possible. I have my doubts, especially about `keystore`, accounts and contacts. 
  * (`/data/misc/keystore` - see [#7](https://github.com/schnatterer/termux-scripts/issues/7))

### Preparation

* For local backup only, the packages mentioned bellow are needed
* For backing up to via SSH, yo need a key in your termux and the appropriate public key added 
  to `authorized_keys` on the target device
* For backing up to the cloud, you need to configure an `rclone` remote. See [rclone](#rclone)

```shell
# Install packages
pkg install -y git termux-api tsu rsync # or rclone 

# Fore remote backups via rsync, set up key. For rclone see bellow.
ssh-keygen
# Copy key to the remote machine. Password authentication has to be enabled in order to install pubkey on remote machine.
ssh-copy-id -i id_ecdsa.pub user@host # Specify port, if necessary: -p 22222 
```

### Usage

Start the script.
On finish an android notification displays the result.
Tapping the notification will open the log file.

Note that
* `rsync` is used by default for local backup or via SSH. You can opt in to use `rclone` (see [rclone](#rclone)).
* restore will not uninstall an app if it exists. Downgrade or signature mismatch might lead to failure.
* for now, **restore will likely fail for apps that use an android keystore**. If you backed up `/data/misc/keystore`, 
 you might be able to restore it manually, though. See [#7](https://github.com/schnatterer/termux-scripts/issues/7).
* Restoring a backup into a higher/lower Android version (e.g. when migrating to a new phone) is risky!  
  Known issues:
  * Android 11 -> 12: Some apps (e.g. whatsapp, locus map) moved their public storage from 
   `/sdcard` to `/sdcard/Android/data/${packageId}`. Solution: Restore, before starting the app manually move folder.
* restoring locally might only work from "tmux'" folders or `/data/local/tmp/`, not from `/sdcard`.  
  There are reports of errors such as this:
  ```
  System server has no access to read file context u:object_r:sdcardfs:s0 (from path /storage/emulated/0...base.apk, context u:r:system_server:s0)
  Error: Unable to open file: base.apk
  ```

### Usage examples

```shell
# Find out package name
sudo pm list packages | grep tag

# Local roundtrip
./backup-app.sh com.nxp.taginfolite . # Backup to ./com.nxp.taginfolite
./restore-app.sh com.nxp.taginfolite  # Restore from ./com.nxp.taginfolite

# Remote roundtrip
# If not set the default port (22) is used
export SSH_PORT=22222
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
```

### Restore termux

* Install termux app either
  * manually from backup,
  * directly via apk from [fdroid](https://f-droid.org/de/packages/com.termux/) or [github](https://github.com/termux/termux-app/releases/) or
  * via an app store app
* [Install packages](#preparation)
* `git clone` this repo.  
  💡 To make sure no to interfere with the version that is restored from the backup clone it to a different directory

```shell
termux-setup-storage
# Restore .ssh and or `.suroot/.config/rclone/rclone.conf` if necessary
# e.g. mkdir -p .suroot/.config/rclone && cp storage/downloads/rclone.conf
# or cp -r storage/downloads/.ssh . 

cd storage/downloads
git clone https://github.com/schnatterer/termux-scripts/
cd termux-scripts/backup
./restore-app.sh com.termux
# or 
./restore-app.sh user@host:/my/folder/backup/com.termux --data
# or 
./restore-app.sh --rclone remote-encrypted:/my/folder/backup/com.termux --data 

# chsh if necessary and restart app
```

### Rclone

* `--rclone` - use `rclone` instead of `rsync`
* `rclone` supports [dozens of cloud providers](https://rclone.org/#providers), local, ssh, etc.
  Each can be combined with deduplication, encryption, etc.  
  Note: For local or SSH copy `rsync` has some advantages, e.g. keeping timestamps, user rights, symlinks, etc.
* Getting started:
  * Set up your remote with `sudo rclone config`, or copy an existing `rclone.config` to `.suroot/.config/rclone/` 
   Why `sudo`? Because the backup is also executed with `sudo` to be able to access folders like `/data/data`, etc.
  * When backing up to the cloud I **recommend to add an encrypted remote and use it for backing up**
  * Backups can then be triggered like so, for example
    ```shell
    ./backup-all-user.sh --rclone remote-encrypted:/my/folder/backup/
    ```
* Note:
  * `--rclone` ignores `SSH_*` env vars, but passes on `RSYNC_ARGS`. Maybe this will be renamed to `SYNC_ARGS` one day.
  * If you want to exclude files use `RSYNC_ARGS` in conjunction with [`--filter-from`](https://rclone.org/filtering/#filter-from-read-filtering-patterns-from-a-file).  
    That way you escape bash quoting hell another time.
    ```shell
    export RSYNC_ARGS=--filter-from=$HOME/.shortcuts/.rclone-app-excludes.txt 
    ```
  * I ended up excluding wide parts of my termux installation to save time and space
    ```text
    + /files/usr/var/lib/dpkg/status
    - /files/usr/**
    - /files/home/storage/**
    - /*/.npm/**
    - */node_modules/**
    ```
  * The first backup to the cloud will take hours! Rough approximation: 100 apps/10GB (encrypted): 6 hours. Subsequent (differential) backups will be much faster. Rough approximation with only few changes: 100 apps/10GB: 20-60 minutes. 
  * A local rsync via SSH (unencrypted) takes about 2 hours initially, 15 minutes subsequently.
  * You can optimize your backup times by identifying and excluding large folders.
    * locally, e.g.
      ```shell
      cd /data/data && sudo ncdu
      ```
    * or remotely after first backup
      ```shell
      rclone ncdu remote-encrypted:/my/folder/backup/
      ```
  * Common warnings:
    * `Failed to copy: invalidRequest: pathIsTooLong:` - well, the path is longer than your cloud provider supports.  
       Possible Solutions:
      * Exclude files (if not essential)
      * Try to use a path as short as possible. As close to your root path in the cloud as possible.  
        termux-scripts already optimized its internal folder structure ([#9](https://github.com/schnatterer/termux-scripts/issues/9)).
        Not much room for optimization left.
    * `Can't follow symlink without -L/--copy-links` - rclone can't handle symlinks. You could use `RSYNC_ARGS` and `-L`
      but this would copy the file or folder behind the symlink which in my experience isn't want you want usually.  
    * `Can't transfer non file/directory` - the file is empty. Even including doesn't seem to help
  
### Options

* `-a / --apk` - backup/restore APK only
* `-d / --data` - backup/restore data only
* `--exclude-packages` (for `backup-all-user`, `restore-all`) semicolon separated wildcards (globbing expressions) of  
  app package names to exclude. e.g. 
  ```shell
  # Note that --exclude-packages=... won't work
  --exclude-packages 'net.oneplus.*;com.oneplus.*;com.android.vending.*'
  ```
* `--exclude-existing` (for `restore-all`, `restore-app`) don't restore apps that already exist
* `--start-at $PACKAGE` - skips all packages before, useful for continuing after an error in backup-all-user.sh or restore-all.sh
* `--bypass-low-target-sdk-block` - avoid error `INSTALL_FAILED_DEPRECATED_SDK_VERSION: App package must target at least SDK version 23, but found 21` for legacy apps, starting [with Android 14](https://developer.android.com/about/versions/14/behavior-changes-all#minimum-target-api-level). See [PackageManager](https://android.googlesource.com/platform/frameworks/base/+/master/services/core/java/com/android/server/pm/PackageManagerShellCommand.java) for more details.
* `--rclone` - use `rclone` instead of `rsync`. See [rclone](#rclone).

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

# Alternatives

* [Neo-Backup](https://github.com/NeoApplications/Neo-Backup) Looks promising and much more convenient to use an app. But needs to create a local backup that then can be uploaded: Takes longer and requires twice the space :/
* Similar scripts, but remote via adb (still require root, last commit 2013): ART https://xdaforums.com/t/tools-zips-scripts-android-backup-and-restore-tools-multiple-devices-platforms.4016617/, https://community.e.foundation/t/how-to-do-a-restore-back-up-from-seedvault/39603/2, remote backup
